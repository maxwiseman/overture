import type { Endpoint, PayloadRequest } from "payload";
import { start } from "workflow/api";
import { z } from "zod";

import {
	generateArticleVariantsWorkflow,
	importArticleWorkflow,
} from "../workflows/articleGeneration";

const importSchema = z.object({
	sourceURL: z.url(),
	requestedBy: z.string().email(),
});

function isTrustedInternalRequest(req: PayloadRequest) {
	const configuredSecret = process.env.ARTICLE_INGEST_SECRET;
	return Boolean(
		configuredSecret &&
			req.headers.get("x-overture-ingest-secret") === configuredSecret,
	);
}

async function requestJSON(req: PayloadRequest) {
	try {
		if (!req.json) return null;
		return await req.json();
	} catch {
		return null;
	}
}

export const articleGenerationEndpoints: Endpoint[] = [
	{
		path: "/import",
		method: "post",
		handler: async (req) => {
			if (!req.user && !isTrustedInternalRequest(req)) {
				return Response.json({ message: "Unauthorized" }, { status: 401 });
			}

			const parsed = importSchema.safeParse(await requestJSON(req));
			if (!parsed.success) {
				return Response.json(
					{ message: "A valid article URL and editor email are required." },
					{ status: 400 },
				);
			}

			const run = await start(importArticleWorkflow, [parsed.data]);
			return Response.json(
				{ runID: run.runId, status: "generating" },
				{ status: 202 },
			);
		},
	},
	{
		path: "/:id/generate-variants",
		method: "post",
		handler: async (req) => {
			if (!req.user)
				return Response.json({ message: "Unauthorized" }, { status: 401 });
			const articleID = req.routeParams?.id;
			if (typeof articleID !== "string" && typeof articleID !== "number") {
				return Response.json(
					{ message: "Article ID is required." },
					{ status: 400 },
				);
			}
			const article = await req.payload.findByID({
				collection: "articles",
				id: articleID,
				draft: true,
				overrideAccess: true,
			});
			if (article.variantGeneration?.status === "generating") {
				return Response.json(
					{
						message: "Variant generation is already running for this article.",
					},
					{ status: 409 },
				);
			}

			const run = await start(generateArticleVariantsWorkflow, [
				{
					articleID,
					requestedBy: req.user.email,
				},
			]);
			await req.payload.update({
				collection: "articles",
				id: articleID,
				draft: true,
				overrideAccess: true,
				data: {
					variantGeneration: {
						status: "generating",
						workflowRunID: run.runId,
						lastError: null,
					},
				},
			});

			return Response.json(
				{ runID: run.runId, status: "generating" },
				{ status: 202 },
			);
		},
	},
];
