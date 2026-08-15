import type { Metadata } from "next";
import { Suspense } from "react";

import { StoriesSection } from "@/components/stories-section";
import { getCurrentEdition, type PublicationEdition } from "@/lib/publication";

type SearchParams = Promise<{ q?: string }>;

export const metadata: Metadata = { title: "Search" };
export const instant = true;

export default async function SearchPage({ searchParams }: { searchParams: SearchParams }) {
  const edition = await getCurrentEdition().catch(() => null);

  if (!edition || edition.stories.length === 0) {
    return (
      <main className="grid min-h-svh place-items-center bg-[#f4f2ec] p-10 pt-22 text-[#10100f]">
        <h1 className="font-[Georgia,'Times_New_Roman',serif] font-normal text-5xl">
          The next issue is being prepared.
        </h1>
      </main>
    );
  }

  return (
    <main className="min-h-svh bg-[#f4f2ec] pt-22">
      <Suspense fallback={<StoriesSection edition={edition} query="" />}>
        <SearchResults edition={edition} searchParams={searchParams} />
      </Suspense>
    </main>
  );
}

async function SearchResults({
  edition,
  searchParams,
}: {
  edition: PublicationEdition;
  searchParams: SearchParams;
}) {
  const { q } = await searchParams;
  return <StoriesSection edition={edition} query={q?.trim() ?? ""} />;
}
