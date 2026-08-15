import config from "@payload-config";
import { cacheLife, cacheTag } from "next/cache";
import { getPayload } from "payload";

import type { Article, Media } from "@/cms/payload-types";

export type PublicationSection = {
  id: string;
  heading: string | null;
  body: string;
  glance: string;
  brief: string;
  standard: string;
  full: string;
};

export type PublicationStory = {
  id: string;
  slug: string;
  title: string;
  deck: string;
  byline: string;
  category: string;
  readTimeMinutes: number;
  publishedAt: string | null;
  heroImageURL: string | null;
  sections: PublicationSection[];
};

export type PublicationEdition = {
  id: string;
  slug: string;
  title: string;
  description: string;
  releaseDate: string;
  stories: PublicationStory[];
};

const localStoryImages: Record<string, { landscape: string; portrait: string }> = {
  "quiet-flight": {
    landscape: "/images/quiet-flight.png",
    portrait: "/images/quiet-flight-portrait.png",
  },
  "paper-battery": {
    landscape: "/images/paper-battery.png",
    portrait: "/images/paper-battery.png",
  },
  "laundry-robot": {
    landscape: "/images/laundry-robot.png",
    portrait: "/images/laundry-robot.png",
  },
};

export function storyImage(
  story: Pick<PublicationStory, "slug" | "heroImageURL">,
  orientation: "landscape" | "portrait" = "landscape",
) {
  return story.heroImageURL ?? localStoryImages[story.slug]?.[orientation] ?? null;
}

type PayloadBlock = Article["body"][number];
type PayloadVariants = Article["variants"];

function publicationBaseURL() {
  const vercelProductionHost = process.env.VERCEL_PROJECT_PRODUCTION_URL;
  return (
    process.env.BETTER_AUTH_URL ??
    (vercelProductionHost ? `https://${vercelProductionHost}` : "http://localhost:3001")
  ).replace(/\/$/, "");
}

function absoluteMediaURL(pathname: string | null | undefined) {
  if (!pathname) return null;
  return new URL(pathname, `${publicationBaseURL()}/`).toString();
}

function lexicalText(node: unknown): string {
  if (!node || typeof node !== "object") return "";
  const value = node as { text?: unknown; children?: unknown[] };
  const ownText = typeof value.text === "string" ? value.text : "";
  const childText = value.children?.map(lexicalText).filter(Boolean).join(" ") ?? "";
  return [ownText, childText].filter(Boolean).join(" ").replace(/\s+/g, " ").trim();
}

function normalizeSections(
  blocks: PayloadBlock[] | null | undefined,
  variants: PayloadVariants,
): PublicationSection[] {
  const variantMaps = {
    glance: new Map((variants?.glance?.sections ?? []).map((section) => [section.sourceSectionID, section])),
    brief: new Map((variants?.brief?.sections ?? []).map((section) => [section.sourceSectionID, section])),
    standard: new Map((variants?.standard?.sections ?? []).map((section) => [section.sourceSectionID, section])),
  };

  return (blocks ?? []).flatMap((block, index): PublicationSection[] => {
    const id = block.id ?? `section-${index + 1}`;
    const withVariants = (heading: string | null, full: string): PublicationSection => ({
      id,
      heading,
      body: full,
      glance: variantMaps.glance.get(id)?.body ?? full,
      brief: variantMaps.brief.get(id)?.body ?? full,
      standard: variantMaps.standard.get(id)?.body ?? full,
      full,
    });

    if (block.blockType === "richText") {
      const body = lexicalText(block.content?.root);
      return body ? [withVariants(block.heading ?? null, body)] : [];
    }

    if (block.blockType === "pullQuote" && block.quote) {
      const attribution = block.attribution ? ` — ${block.attribution}` : "";
      return [withVariants("In their words", `“${block.quote}”${attribution}`)];
    }

    return [];
  });
}

function normalizeArticle(article: Article): PublicationStory {
  const media: Media | null =
    typeof article.heroImage === "object" && article.heroImage !== null ? article.heroImage : null;
  const mediaPath = media?.sizes?.article?.url ?? media?.url;

  return {
    id: String(article.id),
    slug: article.slug,
    title: article.title,
    deck: article.dek ?? "",
    byline: article.byline,
    category: article.category ?? "Ideas",
    readTimeMinutes: article.estimatedReadingMinutes ?? 5,
    publishedAt: article.publishedAt ?? null,
    heroImageURL: absoluteMediaURL(mediaPath),
    sections: normalizeSections(article.body, article.variants),
  };
}

export async function getCurrentEdition(): Promise<PublicationEdition | null> {
  "use cache";

  cacheLife("max");
  cacheTag("publication");

  const payload = await getPayload({ config });
  const { docs } = await payload.find({
    collection: "editions",
    depth: 2,
    limit: 1,
    sort: "-releaseDate",
    overrideAccess: false,
    where: {
      _status: { equals: "published" },
    },
  });
  const edition = docs[0];
  if (!edition) return null;

  const articles = edition.articles.filter(
    (article): article is Article => typeof article === "object",
  );

  return {
    id: String(edition.id),
    slug: edition.slug,
    title: edition.title,
    description: edition.description ?? "",
    releaseDate: edition.releaseDate,
    stories: articles.map(normalizeArticle),
  };
}

export async function getStory(slug: string): Promise<PublicationStory | null> {
  const edition = await getCurrentEdition();
  return edition?.stories.find((story) => story.slug === slug) ?? null;
}
