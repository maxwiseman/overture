import { ArrowRight } from "lucide-react";
import type { Route } from "next";
import Image from "next/image";
import Link from "next/link";

import type { PublicationEdition } from "@/lib/publication";
import { storyImage } from "@/lib/publication";

import SaveStoryButton from "./save-story-button";

const storyHref = (slug: string) => `/stories/${slug}` as Route;

export function StoriesSection({ edition, query }: { edition: PublicationEdition; query: string }) {
  const [lead, ...nextStories] = edition.stories;
  const normalizedQuery = query.toLocaleLowerCase();
  const storiesForGrid = normalizedQuery
    ? edition.stories.filter((story) =>
        [story.title, story.deck, story.category, story.byline].some((value) =>
          value.toLocaleLowerCase().includes(normalizedQuery),
        ),
      )
    : nextStories;

  return (
    <section
      className="mx-auto max-w-[1440px] px-[42px] pt-[70px] pb-[90px] text-[#10100f] max-[800px]:px-5 max-[800px]:pt-[54px] max-[800px]:pb-[70px]"
      id="next-stories"
    >
      <div className="flex items-end justify-between gap-8 border-b border-[#cbc8c0] pb-7 max-[800px]:flex-col max-[800px]:items-start">
        <div>
          <p className="mb-3 text-[0.72rem] font-[650] tracking-[0.17em] text-[#2d6bd1] uppercase">
            {query ? `Results for “${query}”` : edition.title}
          </p>
          <h2 className="m-0 [font-family:Georgia,'Times_New_Roman',serif] text-[clamp(2.7rem,4.5vw,4.5rem)] font-normal tracking-[-0.04em]">
            {query ? "Search results" : "Next stories"}
          </h2>
        </div>
        <p className="mb-2 max-w-[350px] leading-[1.6] text-[#62615c] max-[800px]:m-0">
          {query
            ? `${storiesForGrid.length} matching ${storiesForGrid.length === 1 ? "story" : "stories"}.`
            : edition.description}
        </p>
      </div>
      <div className="grid grid-cols-2 max-[800px]:grid-cols-1">
        {storiesForGrid.map((story, gridIndex) => {
          const image = storyImage(story);
          const storyNumber =
            edition.stories.findIndex((candidate) => candidate.id === story.id) + 1;
          return (
            <article
              className={`group grid min-h-[390px] grid-cols-[minmax(180px,.85fr)_minmax(220px,1fr)] gap-8 border-b border-[#cbc8c0] py-[38px] pr-[38px] max-[800px]:grid-cols-1 max-[800px]:gap-6 max-[800px]:px-0 max-[800px]:py-[30px] ${gridIndex > 0 ? "border-l border-l-[#cbc8c0] pl-[38px] max-[800px]:border-l-0 max-[800px]:pl-0" : ""}`}
              key={story.id}
            >
              <Link
                className="relative min-h-[310px] overflow-hidden bg-[#d9d7d0] max-[800px]:min-h-[300px]"
                href={storyHref(story.slug)}
                prefetch
              >
                {image ? (
                  <Image
                    className="object-cover transition-transform duration-550 ease-in-out group-hover:scale-[1.025]"
                    src={image}
                    alt=""
                    fill
                    sizes="(max-width: 720px) 100vw, 50vw"
                  />
                ) : null}
              </Link>
              <div className="flex flex-col">
                <div className="flex gap-[18px] text-[0.69rem] tracking-[0.13em] text-[#2d6bd1] uppercase">
                  <span>{storyNumber.toString().padStart(2, "0")}</span>
                  <span>{story.category}</span>
                </div>
                <h3 className="mt-11 mb-4 [font-family:Georgia,'Times_New_Roman',serif] text-[clamp(2rem,3vw,3.1rem)] leading-[1.02] font-normal tracking-[-0.04em] max-[800px]:mt-[22px]">
                  <Link href={storyHref(story.slug)}>{story.title}</Link>
                </h3>
                <p className="m-0 leading-[1.55] text-[#62615c] max-[800px]:mb-7">{story.deck}</p>
                <div className="mt-auto flex items-center justify-between text-[0.82rem] text-[#62615c] [&_button]:cursor-pointer [&_button]:border-0 [&_button]:bg-transparent [&_button]:p-[7px]">
                  <span>{story.readTimeMinutes} min read</span>
                  <SaveStoryButton slug={story.slug} title={story.title} />
                </div>
              </div>
            </article>
          );
        })}
        {storiesForGrid.length === 0 ? (
          <p className="col-span-full py-14 text-[#62615c]">No stories found in this issue.</p>
        ) : null}
      </div>
      <Link
        className="mt-9 ml-auto flex w-max items-center gap-[9px] text-[#2d6bd1] max-[800px]:ml-0"
        href={storyHref(lead.slug)}
        prefetch
      >
        Begin with today’s lead <ArrowRight size={18} aria-hidden="true" />
      </Link>
    </section>
  );
}
