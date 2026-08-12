import { ArrowRight, ChevronDown } from "lucide-react";
import type { Route } from "next";
import Image from "next/image";
import Link from "next/link";
import { ViewTransition } from "react";

import SaveStoryButton from "@/components/save-story-button";
import { getCurrentEdition, storyImage } from "@/lib/publication";

const storyHref = (slug: string) => `/stories/${slug}` as Route;

export default async function Home({
  searchParams,
}: {
  searchParams: Promise<{ q?: string }>;
}) {
  const edition = await getCurrentEdition().catch(() => null);
  const { q } = await searchParams;
  const query = q?.trim().toLocaleLowerCase() ?? "";

  if (!edition || edition.stories.length === 0) {
    return <main className="empty-edition"><h1>The next issue is being prepared.</h1></main>;
  }

  const [lead, ...nextStories] = edition.stories;
  const leadImage = storyImage(lead);
  const storiesForGrid = query
    ? edition.stories.filter((story) =>
        [story.title, story.deck, story.category, story.byline].some((value) =>
          value.toLocaleLowerCase().includes(query),
        ),
      )
    : nextStories;

  return (
    <main className="publication-home">
      <section className="hero">
        {leadImage ? (
          <ViewTransition name={`story-image-${lead.slug}`} share="story-media" default="none">
            <Image className="hero__image" src={leadImage} alt="" fill priority sizes="100vw" />
          </ViewTransition>
        ) : null}
        <div className="hero__veil" />
        <div className="hero__content">
          <ViewTransition name={`story-title-${lead.slug}`} share="story-title" default="none">
            <h1>{lead.title}</h1>
          </ViewTransition>
          <p className="hero__deck">{lead.deck}</p>
          <p className="read-time">{lead.readTimeMinutes} min read</p>
          <Link className="hero__link" href={storyHref(lead.slug)} aria-label={`Read ${lead.title}`} />
        </div>
        <details className="issue-picker">
          <summary><ChevronDown size={20} aria-hidden="true" /> {edition.title}</summary>
          <div className="issue-picker__panel">
            <p>{edition.description}</p>
            <ol>
              {edition.stories.map((story, index) => (
                <li key={story.id}>
                  <span>{(index + 1).toString().padStart(2, "0")}</span>
                  <Link href={storyHref(story.slug)}>{story.title}</Link>
                </li>
              ))}
            </ol>
          </div>
        </details>
      </section>

      <section className="issue-section" id="next-stories">
        <div className="issue-heading">
          <div>
            <p className="eyebrow">{query ? `Results for “${q?.trim()}”` : edition.title}</p>
            <h2>{query ? "Search results" : "Next stories"}</h2>
          </div>
          <p>{query ? `${storiesForGrid.length} matching ${storiesForGrid.length === 1 ? "story" : "stories"}.` : edition.description}</p>
        </div>
        <div className="story-grid">
          {storiesForGrid.map((story) => {
            const image = storyImage(story);
            const storyNumber = edition.stories.findIndex((candidate) => candidate.id === story.id) + 1;
            return (
              <article className="story-card" key={story.id}>
                <Link className="story-card__image-link" href={storyHref(story.slug)}>
                  {image ? (
                    <ViewTransition name={`story-image-${story.slug}`} share="story-media" default="none">
                      <Image src={image} alt="" fill sizes="(max-width: 720px) 100vw, 50vw" />
                    </ViewTransition>
                  ) : null}
                </Link>
                <div className="story-card__copy">
                  <div className="story-card__meta">
                    <span>{storyNumber.toString().padStart(2, "0")}</span>
                    <span>{story.category}</span>
                  </div>
                  <ViewTransition name={`story-title-${story.slug}`} share="story-title" default="none">
                    <h3><Link href={storyHref(story.slug)}>{story.title}</Link></h3>
                  </ViewTransition>
                  <p>{story.deck}</p>
                  <div className="story-card__footer">
                    <span>{story.readTimeMinutes} min read</span>
                    <SaveStoryButton slug={story.slug} title={story.title} />
                  </div>
                </div>
              </article>
            );
          })}
          {storiesForGrid.length === 0 ? <p className="no-results">No stories found in this issue.</p> : null}
        </div>
        <Link className="edition-link" href={storyHref(lead.slug)}>
          Begin with today’s lead <ArrowRight size={18} aria-hidden="true" />
        </Link>
      </section>
    </main>
  );
}
