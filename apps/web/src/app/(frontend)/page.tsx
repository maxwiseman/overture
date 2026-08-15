import { ArrowRight, ChevronDown } from "lucide-react";
import type { Route } from "next";
import Image from "next/image";
import Link from "next/link";
import { connection } from "next/server";
import { Suspense } from "react";

import SaveStoryButton from "@/components/save-story-button";
import {
  getCurrentEdition,
  type PublicationEdition,
  storyImage,
} from "@/lib/publication";

const storyHref = (slug: string) => `/stories/${slug}` as Route;

type HomeSearchParams = Promise<{ q?: string }>;

export const instant = true;

export default function Home({ searchParams }: { searchParams: HomeSearchParams }) {
  return (
    <Suspense fallback={<HomeFallback />}>
      <PublicationHome searchParams={searchParams} />
    </Suspense>
  );
}

async function PublicationHome({ searchParams }: { searchParams: HomeSearchParams }) {
  await connection();

  const edition = await getCurrentEdition().catch(() => null);

  if (!edition || edition.stories.length === 0) {
    return (
      <main className="grid min-h-[calc(100svh-88px)] place-items-center bg-[#05080c] p-10 text-white">
        <h1 className="[font-family:Georgia,'Times_New_Roman',serif] text-5xl font-normal">
          The next issue is being prepared.
        </h1>
      </main>
    );
  }

  const lead = edition.stories[0];
  const leadImage = storyImage(lead);

  return (
    <main>
      <section className="relative min-h-[784px] overflow-hidden bg-[#081525] text-white max-[800px]:min-h-svh">
        {leadImage ? (
          <Image
            className="object-cover object-[center_55%] max-[800px]:object-[58%_center]"
            src={leadImage}
            alt=""
            fill
            priority
            sizes="100vw"
          />
        ) : null}
        <div className="absolute inset-0 bg-[linear-gradient(90deg,rgb(2_7_14_/_0.82)_0%,rgb(2_7_14_/_0.45)_38%,transparent_70%),linear-gradient(0deg,rgb(2_5_10_/_0.45),transparent_55%)] max-[800px]:bg-[linear-gradient(0deg,rgb(2_7_14_/_0.88)_0%,rgb(2_7_14_/_0.28)_72%)]" />
        <div className="relative z-2 mx-auto flex min-h-[784px] max-w-[1440px] flex-col items-start justify-center px-[42px] pt-[190px] pb-[70px] max-[800px]:min-h-svh max-[800px]:justify-end max-[800px]:px-5 max-[800px]:pt-[180px] max-[800px]:pb-[54px]">
          <h1 className="m-0 max-w-[660px] [font-family:Georgia,'Times_New_Roman',serif] text-[clamp(4.5rem,7.15vw,7.1rem)] leading-[0.96] font-normal tracking-[-0.055em] max-[800px]:max-w-[350px] max-[800px]:text-[clamp(3.6rem,17vw,5.1rem)]">
            {lead.title}
          </h1>
          <p className="mt-8 max-w-[510px] text-[1.35rem] leading-[1.45] text-white/85 max-[800px]:mt-[22px] max-[800px]:max-w-[345px] max-[800px]:text-[1.05rem]">
            {lead.deck}
          </p>
          <p className="mt-[34px] text-base max-[800px]:mt-[22px]">
            {lead.readTimeMinutes} min read
          </p>
          <Link
            className="absolute inset-0 z-1"
            href={storyHref(lead.slug)}
            prefetch
            aria-label={`Read ${lead.title}`}
          />
        </div>
        <details className="group absolute top-[126px] right-[max(42px,calc((100vw-1440px)/2+42px))] z-4 w-[260px] max-[800px]:top-[122px] max-[800px]:right-5 max-[800px]:w-auto">
          <summary className="flex h-16 cursor-pointer list-none items-center gap-4 rounded-[14px] bg-[rgb(4_10_18_/_0.82)] px-6 backdrop-blur-[20px] [&::-webkit-details-marker]:hidden max-[800px]:h-12 max-[800px]:px-4 max-[800px]:text-[0.82rem]">
            <ChevronDown className="group-open:rotate-180" size={20} aria-hidden="true" /> {edition.title}
          </summary>
          <div className="mt-2 rounded-[14px] bg-[rgb(4_10_18_/_0.94)] px-6 py-5 text-white/76 shadow-[0_18px_60px_rgb(0_0_0_/_0.3)] max-[800px]:absolute max-[800px]:right-0 max-[800px]:w-[250px]">
            <p className="mb-[14px] leading-normal">{edition.description}</p>
            <ol className="mt-5 list-none border-t border-white/14 p-0">
              {edition.stories.map((story, index) => (
                <li
                  className="grid grid-cols-[30px_1fr] gap-2.5 border-b border-white/14 py-[13px]"
                  key={story.id}
                >
                  <span className="text-[0.7rem] tracking-[0.1em] text-[#4b8dff]">
                    {(index + 1).toString().padStart(2, "0")}
                  </span>
                  <Link
                    className="[font-family:Georgia,'Times_New_Roman',serif] text-base leading-[1.15] text-white"
                    href={storyHref(story.slug)}
                  >
                    {story.title}
                  </Link>
                </li>
              ))}
            </ol>
          </div>
        </details>
      </section>

      <Suspense fallback={<StoriesSection edition={edition} query="" />}>
        <SearchableStories edition={edition} searchParams={searchParams} />
      </Suspense>
    </main>
  );
}

function HomeFallback() {
  return (
    <main aria-busy="true" aria-label="Loading today’s issue">
      <section className="flex min-h-[784px] items-end bg-[#081525] px-[42px] pb-[70px] text-white max-[800px]:min-h-svh max-[800px]:px-5 max-[800px]:pb-[54px]">
        <div className="w-full max-w-[660px] animate-pulse">
          <div className="h-24 w-full bg-white/14 max-[800px]:h-20" />
          <div className="mt-8 h-7 w-full max-w-[510px] bg-white/10" />
          <div className="mt-3 h-7 w-2/3 max-w-[340px] bg-white/10" />
          <div className="mt-8 h-4 w-20 bg-white/12" />
        </div>
      </section>
      <section className="mx-auto max-w-[1440px] px-[42px] py-[70px] max-[800px]:px-5">
        <div className="h-14 w-full max-w-[360px] animate-pulse bg-[#d9d7d0]" />
      </section>
    </main>
  );
}

async function SearchableStories({
  edition,
  searchParams,
}: {
  edition: PublicationEdition;
  searchParams: HomeSearchParams;
}) {
  const { q } = await searchParams;
  return <StoriesSection edition={edition} query={q?.trim() ?? ""} />;
}

function StoriesSection({ edition, query }: { edition: PublicationEdition; query: string }) {
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
      >
        Begin with today’s lead <ArrowRight size={18} aria-hidden="true" />
      </Link>
    </section>
  );
}
