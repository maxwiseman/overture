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

type PayloadMedia = {
  url?: string | null;
  sizes?: { article?: { url?: string | null } | null } | null;
};

type LexicalNode = {
  text?: string;
  children?: LexicalNode[];
};

type PayloadBlock = {
  id?: string | null;
  blockName?: string | null;
  heading?: string | null;
  blockType?: string;
  content?: { root?: LexicalNode } | null;
  quote?: string | null;
  attribution?: string | null;
  caption?: string | null;
};

type PayloadVariantSection = {
  sourceSectionID: string;
  heading?: string | null;
  body: string;
};

type PayloadVariant = { sections?: PayloadVariantSection[] | null };

type PayloadVariants = {
  glance?: PayloadVariant | null;
  brief?: PayloadVariant | null;
  standard?: PayloadVariant | null;
};

type PayloadArticle = {
  id: string | number;
  slug: string;
  title: string;
  dek?: string | null;
  byline: string;
  category?: string | null;
  estimatedReadingMinutes?: number | null;
  publishedAt?: string | null;
  heroImage?: PayloadMedia | string | number | null;
  body?: PayloadBlock[] | null;
  variants?: PayloadVariants | null;
};

type PayloadEdition = {
  id: string | number;
  slug: string;
  title: string;
  description?: string | null;
  releaseDate: string;
  articles?: Array<PayloadArticle | string | number> | null;
};

type PayloadList<T> = { docs: T[] };

function payloadBaseURL() {
  return (process.env.PAYLOAD_URL ?? "http://localhost:3002").replace(/\/$/, "");
}

function absoluteMediaURL(pathname: string | null | undefined) {
  if (!pathname) return null;
  return new URL(pathname, `${payloadBaseURL()}/`).toString();
}

function lexicalText(node: LexicalNode | undefined): string {
  if (!node) return "";
  const ownText = node.text ?? "";
  const childText = node.children?.map(lexicalText).filter(Boolean).join(" ") ?? "";
  return [ownText, childText].filter(Boolean).join(" ").replace(/\s+/g, " ").trim();
}

function normalizeSections(
  blocks: PayloadBlock[] | null | undefined,
  variants: PayloadVariants | null | undefined,
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

function normalizeArticle(article: PayloadArticle): PublicationStory {
  const media = typeof article.heroImage === "object" ? article.heroImage : null;
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

  cacheLife("hours");
  cacheTag("publication");

  const query = new URLSearchParams({
    depth: "2",
    limit: "1",
    sort: "-releaseDate",
  });
  const response = await fetch(`${payloadBaseURL()}/api/editions?${query}`, {
    headers: { Accept: "application/json" },
  });

  if (!response.ok) {
    throw new Error(`Payload returned ${response.status}`);
  }

  const data = (await response.json()) as PayloadList<PayloadEdition>;
  const edition = data.docs[0];
  if (!edition) return null;

  const articles = (edition.articles ?? []).filter(
    (article): article is PayloadArticle => typeof article === "object",
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
import { cacheLife, cacheTag } from "next/cache";
