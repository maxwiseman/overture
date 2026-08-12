import Link from "next/link";

import { getCurrentEdition } from "@/lib/publication";

export default async function Home() {
  const edition = await getCurrentEdition().catch(() => null);

  return (
    <main className="mx-auto max-w-5xl px-6 py-16">
      <p className="text-sm font-semibold uppercase tracking-[0.24em] text-muted-foreground">
        The ideas opening tomorrow
      </p>
      <h1 className="mt-4 text-6xl font-semibold tracking-tight">Overture</h1>

      {edition ? (
        <section className="mt-16">
          <div className="flex items-end justify-between gap-6 border-b pb-5">
            <div>
              <p className="text-sm text-muted-foreground">Latest edition</p>
              <h2 className="mt-1 text-3xl font-medium">{edition.title}</h2>
            </div>
            <p className="text-sm text-muted-foreground">{edition.stories.length} stories</p>
          </div>
          <div className="grid gap-8 py-8 md:grid-cols-2">
            {edition.stories.map((story) => (
              <article key={story.id} className="space-y-3">
                <p className="text-xs font-semibold uppercase tracking-widest text-muted-foreground">
                  {story.category}
                </p>
                <h3 className="text-2xl font-medium leading-tight">{story.title}</h3>
                <p className="leading-7 text-muted-foreground">{story.deck}</p>
                <p className="text-sm">{story.readTimeMinutes} min read</p>
              </article>
            ))}
          </div>
        </section>
      ) : (
        <section className="mt-16 rounded-2xl border p-8">
          <h2 className="text-2xl font-medium">The first edition is being prepared.</h2>
          <p className="mt-3 max-w-2xl text-muted-foreground">
            Start Payload, publish an edition, and it will appear here and in the iOS app through
            the same publication API.
          </p>
        </section>
      )}

      <div className="mt-12 flex gap-6 text-sm">
        <Link className="underline underline-offset-4" href="/login">Sign in</Link>
        <Link className="underline underline-offset-4" href="/api/publication/editions/current">
          View publication API
        </Link>
      </div>
    </main>
  );
}
