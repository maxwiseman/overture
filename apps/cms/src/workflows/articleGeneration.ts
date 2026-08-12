import { createHash } from "node:crypto";
import { lookup } from "node:dns/promises";
import { isIP } from "node:net";
import { Readability } from "@mozilla/readability";
import config from "@payload-config";
import { generateText, Output } from "ai";
import { parseHTML } from "linkedom";
import { getPayload } from "payload";
import { FatalError } from "workflow";
import { z } from "zod";

const model = process.env.ARTICLE_GENERATION_MODEL ?? "openai/gpt-5.4-mini";

const generatedArticleSchema = z.object({
	title: z.string().min(1),
	dek: z.string().min(1),
	byline: z.string().nullable(),
	category: z.string().min(1),
	sections: z
		.array(
			z.object({
				heading: z.string().nullable(),
				full: z.string().min(1),
				glance: z.string().min(1),
				brief: z.string().min(1),
				standard: z.string().min(1),
			}),
		)
		.min(1)
		.max(10),
});

const generatedVariantsSchema = z.object({
	sections: z
		.array(
			z.object({
				sourceSectionID: z.string().min(1),
				heading: z.string().nullable(),
				glance: z.string().min(1),
				brief: z.string().min(1),
				standard: z.string().min(1),
			}),
		)
		.min(1),
});

type ExtractedArticle = {
	sourceURL: string;
	title: string;
	byline: string | null;
	excerpt: string | null;
	text: string;
};

type CanonicalSection = { id: string; heading: string | null; body: string };

export type ArticleImportInput = { sourceURL: string; requestedBy: string };
export type VariantGenerationInput = {
	articleID: number | string;
	requestedBy: string;
};

function isPrivateAddress(address: string) {
	if (
		address === "::1" ||
		address.startsWith("fe80:") ||
		address.startsWith("fc") ||
		address.startsWith("fd")
	)
		return true;
	if (isIP(address) !== 4) return false;
	const [a, b] = address.split(".").map(Number);
	return (
		a === 10 ||
		a === 127 ||
		(a === 169 && b === 254) ||
		(a === 172 && b >= 16 && b <= 31) ||
		(a === 192 && b === 168)
	);
}

async function assertSafeURL(value: string) {
	const url = new URL(value);
	if (url.protocol !== "https:" && url.protocol !== "http:")
		throw new FatalError("Only HTTP article URLs are supported.");
	const hostname = url.hostname.toLowerCase();
	if (hostname === "localhost" || hostname.endsWith(".local"))
		throw new FatalError("Local article URLs are not supported.");
	const addresses = await lookup(hostname, { all: true });
	if (
		!addresses.length ||
		addresses.some(({ address }) => isPrivateAddress(address))
	) {
		throw new FatalError("Private-network article URLs are not supported.");
	}
	return url;
}

async function extractArticle(sourceURL: string): Promise<ExtractedArticle> {
	"use step";

	let currentURL = await assertSafeURL(sourceURL);
	let response: Response | undefined;
	for (let redirects = 0; redirects <= 4; redirects += 1) {
		response = await fetch(currentURL, {
			headers: { "User-Agent": "Overture Editorial Importer/1.0" },
			redirect: "manual",
			signal: AbortSignal.timeout(20_000),
		});
		if (response.status < 300 || response.status >= 400) break;
		const location = response.headers.get("location");
		if (!location)
			throw new FatalError(
				"The article redirect did not include a destination.",
			);
		currentURL = await assertSafeURL(new URL(location, currentURL).toString());
	}

	if (!response?.ok)
		throw new Error(
			`Article source returned ${response?.status ?? "no response"}.`,
		);
	const contentType = response.headers.get("content-type") ?? "";
	if (!contentType.includes("text/html"))
		throw new FatalError("The shared URL is not an HTML article.");
	const declaredLength = Number(response.headers.get("content-length") ?? 0);
	if (declaredLength > 2_000_000)
		throw new FatalError("The shared article is too large to import.");

	const html = (await response.text()).slice(0, 2_000_000);
	const { document } = parseHTML(html);
	const article = new Readability(document as unknown as Document, {
		charThreshold: 200,
	}).parse();
	if (!article?.textContent || article.textContent.trim().length < 200) {
		throw new FatalError(
			"Overture could not find enough article text at that URL.",
		);
	}

	return {
		sourceURL: currentURL.toString(),
		title: article.title ?? currentURL.hostname,
		byline: article.byline ?? null,
		excerpt: article.excerpt ?? null,
		text: article.textContent.replace(/\s+/g, " ").trim().slice(0, 120_000),
	};
}

async function findImportedArticle(sourceURL: string) {
	"use step";
	const payload = await getPayload({ config });
	const existing = await payload.find({
		collection: "articles",
		limit: 1,
		overrideAccess: true,
		where: { sourceURL: { equals: sourceURL } },
	});
	return existing.docs[0]
		? { id: existing.docs[0].id, title: existing.docs[0].title }
		: null;
}

async function generateImportedDraft(article: ExtractedArticle) {
	"use step";
	const result = await generateText({
		model,
		output: Output.object({ schema: generatedArticleSchema }),
		prompt: `Create an Overture editorial draft from the source below.

Rules:
- Preserve the source's facts, uncertainty, numbers, names, caveats, and attribution. Do not add facts.
- The full version should be a clean, original synthesis, split into 2-8 coherent sections.
- Glance is one concise paragraph per section. Brief is longer. Standard retains most important detail. Full is most complete.
- Keep direct quotes out unless absolutely necessary; never fabricate quotations.
- Use the source byline exactly when it is present. Return null when it is absent.
- This is a draft for human review, never finished or published copy.

Source URL: ${article.sourceURL}
Source title: ${article.title}
Source byline: ${article.byline ?? "Not provided"}
Source excerpt: ${article.excerpt ?? "Not provided"}
Source text:
${article.text}`,
	});
	return result.output;
}

function lexicalBlock(
	text: string,
	heading: string | null,
	index: number,
	id: string,
) {
	return {
		id,
		blockName: `Section ${index + 1}`,
		blockType: "richText" as const,
		heading,
		content: {
			root: {
				type: "root",
				format: "" as const,
				indent: 0,
				version: 1,
				direction: "ltr" as const,
				children: [
					{
						type: "paragraph",
						format: "" as const,
						indent: 0,
						version: 1,
						direction: "ltr" as const,
						textFormat: 0,
						textStyle: "",
						children: [
							{
								type: "text",
								format: 0,
								style: "",
								mode: "normal",
								detail: 0,
								version: 1,
								text,
							},
						],
					},
				],
			},
		},
	};
}

function slugify(value: string) {
	return (
		value
			.toLowerCase()
			.normalize("NFKD")
			.replace(/[^a-z0-9]+/g, "-")
			.replace(/^-|-$/g, "")
			.slice(0, 72) || "imported-article"
	);
}

function variantGroup(
	sections: Array<{
		id: string;
		heading: string | null;
		glance: string;
		brief: string;
		standard: string;
	}>,
	depth: "glance" | "brief" | "standard",
) {
	return {
		sections: sections.map((section) => ({
			sourceSectionID: section.id,
			heading: section.heading,
			body: section[depth],
		})),
	};
}

async function saveImportedDraft(
	article: ExtractedArticle,
	generated: z.infer<typeof generatedArticleSchema>,
	requestedBy: string,
) {
	"use step";
	const payload = await getPayload({ config });
	const aligned = generated.sections.map((section) => ({
		...section,
		id: crypto.randomUUID(),
	}));
	const created = await payload.create({
		collection: "articles",
		draft: true,
		overrideAccess: true,
		data: {
			title: generated.title,
			slug: `${slugify(generated.title)}-${Date.now().toString(36)}`,
			dek: generated.dek,
			byline: article.byline ?? generated.byline ?? "Overture Editorial",
			category: generated.category,
			estimatedReadingMinutes: Math.max(
				1,
				Math.ceil(
					generated.sections.reduce(
						(sum, section) => sum + section.full.split(/\s+/).length,
						0,
					) / 220,
				),
			),
			sourceURL: article.sourceURL,
			importedAt: new Date().toISOString(),
			importedBy: requestedBy,
			body: aligned.map((section, index) =>
				lexicalBlock(section.full, section.heading, index, section.id),
			),
			variants: {
				glance: variantGroup(aligned, "glance"),
				brief: variantGroup(aligned, "brief"),
				standard: variantGroup(aligned, "standard"),
			},
			variantGeneration: {
				status: "needs-review",
				sourceHash: createHash("sha256").update(article.text).digest("hex"),
				model,
				generatedAt: new Date().toISOString(),
			},
			_status: "draft",
		},
	});
	return { articleID: created.id, title: created.title };
}

function lexicalText(node: unknown): string {
	if (!node || typeof node !== "object") return "";
	const value = node as { text?: unknown; children?: unknown[] };
	const own = typeof value.text === "string" ? value.text : "";
	const children =
		value.children?.map(lexicalText).filter(Boolean).join(" ") ?? "";
	return [own, children].filter(Boolean).join(" ").replace(/\s+/g, " ").trim();
}

async function loadCanonicalArticle(articleID: number | string) {
	"use step";
	const payload = await getPayload({ config });
	const article = await payload.findByID({
		collection: "articles",
		id: articleID,
		draft: true,
		overrideAccess: true,
	});
	const sections: CanonicalSection[] = (article.body ?? []).flatMap(
		(block, index) => {
			const id = block.id ?? `section-${index + 1}`;
			if (block.blockType === "richText") {
				const body = lexicalText(block.content?.root);
				return body ? [{ id, heading: block.heading ?? null, body }] : [];
			}
			if (block.blockType === "pullQuote") {
				return [
					{
						id,
						heading: "In their words",
						body: `“${block.quote}”${block.attribution ? ` — ${block.attribution}` : ""}`,
					},
				];
			}
			return [];
		},
	);
	if (!sections.length)
		throw new FatalError(
			"The article needs canonical body text before variants can be generated.",
		);
	return {
		articleID: article.id,
		title: article.title,
		dek: article.dek ?? "",
		sections,
	};
}

async function generateVariants(
	article: Awaited<ReturnType<typeof loadCanonicalArticle>>,
) {
	"use step";
	const result = await generateText({
		model,
		output: Output.object({ schema: generatedVariantsSchema }),
		prompt: `Generate aligned shorter versions of this Overture article.

Return exactly one item for every source section and copy sourceSectionID exactly.
- Glance: one compact paragraph preserving the section's central claim.
- Brief: a concise reading that preserves key evidence and caveats.
- Standard: a substantial compression that preserves facts, names, numbers, uncertainty, and attribution.
- Never invent facts or quotations. A quote must be retained exactly or omitted.
- Preserve the section order.

Article: ${article.title}
Dek: ${article.dek}
Sections:
${article.sections.map((section) => `[${section.id}] ${section.heading ?? "Opening"}\n${section.body}`).join("\n\n")}`,
	});
	const byID = new Map(
		result.output.sections.map((section) => [section.sourceSectionID, section]),
	);
	return article.sections.map((source) => {
		const generated = byID.get(source.id);
		if (!generated)
			throw new Error(`Generation omitted source section ${source.id}.`);
		return { ...generated, heading: generated.heading ?? source.heading };
	});
}

async function saveVariants(
	article: Awaited<ReturnType<typeof loadCanonicalArticle>>,
	generated: Awaited<ReturnType<typeof generateVariants>>,
) {
	"use step";
	const payload = await getPayload({ config });
	const sourceText = article.sections
		.map(
			(section) => `${section.id}\n${section.heading ?? ""}\n${section.body}`,
		)
		.join("\n\n");
	await payload.update({
		collection: "articles",
		id: article.articleID,
		draft: true,
		overrideAccess: true,
		data: {
			variants: {
				glance: variantGroup(
					generated.map((section) => ({
						...section,
						id: section.sourceSectionID,
					})),
					"glance",
				),
				brief: variantGroup(
					generated.map((section) => ({
						...section,
						id: section.sourceSectionID,
					})),
					"brief",
				),
				standard: variantGroup(
					generated.map((section) => ({
						...section,
						id: section.sourceSectionID,
					})),
					"standard",
				),
			},
			variantGeneration: {
				status: "needs-review",
				sourceHash: createHash("sha256").update(sourceText).digest("hex"),
				model,
				generatedAt: new Date().toISOString(),
				lastError: null,
			},
		},
	});
	return { articleID: article.articleID, sectionCount: generated.length };
}

async function markGenerationFailed(
	articleID: number | string,
	message: string,
) {
	"use step";
	const payload = await getPayload({ config });
	await payload.update({
		collection: "articles",
		id: articleID,
		draft: true,
		overrideAccess: true,
		data: {
			variantGeneration: {
				status: "failed",
				lastError: message.slice(0, 2_000),
			},
		},
	});
}

export async function importArticleWorkflow(input: ArticleImportInput) {
	"use workflow";
	const source = await extractArticle(input.sourceURL);
	const existing = await findImportedArticle(source.sourceURL);
	if (existing) return { ...existing, alreadyImported: true };
	const generated = await generateImportedDraft(source);
	return {
		...(await saveImportedDraft(source, generated, input.requestedBy)),
		alreadyImported: false,
	};
}

export async function generateArticleVariantsWorkflow(
	input: VariantGenerationInput,
) {
	"use workflow";
	try {
		const article = await loadCanonicalArticle(input.articleID);
		const generated = await generateVariants(article);
		return await saveVariants(article, generated);
	} catch (error) {
		await markGenerationFailed(
			input.articleID,
			error instanceof Error ? error.message : String(error),
		);
		throw error;
	}
}
