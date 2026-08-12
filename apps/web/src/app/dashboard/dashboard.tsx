"use client";
import type { Route } from "next";
import Link from "next/link";
import { useEffect, useState } from "react";

import SaveStoryButton, { getSavedStorySlugs } from "@/components/save-story-button";
import type { PublicationStory } from "@/lib/publication";

export default function Dashboard({ stories }: { stories: PublicationStory[] }) {
  const [savedSlugs, setSavedSlugs] = useState<string[]>([]);

  useEffect(() => {
    const update = () => setSavedSlugs(getSavedStorySlugs());
    update();
    window.addEventListener("overture-saved-stories", update);
    return () => window.removeEventListener("overture-saved-stories", update);
  }, []);

  const savedStories = stories.filter((story) => savedSlugs.includes(story.slug));

  if (savedStories.length === 0) {
    return <p className="saved-page__empty">Stories you bookmark will appear here.</p>;
  }

  return (
    <div className="saved-list">
      {savedStories.map((story) => (
        <article key={story.id}>
          <div>
            <p>{story.category} · {story.readTimeMinutes} min read</p>
            <h2><Link href={`/stories/${story.slug}` as Route}>{story.title}</Link></h2>
          </div>
          <SaveStoryButton slug={story.slug} title={story.title} />
        </article>
      ))}
    </div>
  );
}
