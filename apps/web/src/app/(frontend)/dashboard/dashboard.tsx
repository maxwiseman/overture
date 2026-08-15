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
    return <p className="mt-[22px] border-t border-[#cbc8c0] pt-[54px] text-[#62615c]">Stories you bookmark will appear here.</p>;
  }

  return (
    <div className="mt-[54px] border-t border-[#cbc8c0]">
      {savedStories.map((story) => (
        <article className="flex justify-between gap-6 border-b border-[#cbc8c0] py-7" key={story.id}>
          <div>
            <p className="mb-2 text-[0.72rem] tracking-[0.12em] text-[#2d6bd1] uppercase">{story.category} · {story.readTimeMinutes} min read</p>
            <h2 className="m-0 [font-family:Georgia,'Times_New_Roman',serif] text-[2rem] font-normal"><Link href={`/stories/${story.slug}` as Route}>{story.title}</Link></h2>
          </div>
          <div className="self-center [&_button]:cursor-pointer [&_button]:border-0 [&_button]:bg-transparent [&_button]:p-2.5">
            <SaveStoryButton slug={story.slug} title={story.title} />
          </div>
        </article>
      ))}
    </div>
  );
}
