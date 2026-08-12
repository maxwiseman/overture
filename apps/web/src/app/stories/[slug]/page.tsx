import type { Metadata } from "next";
import { ArrowLeft } from "lucide-react";
import Image from "next/image";
import Link from "next/link";
import { notFound } from "next/navigation";

import { getStory, storyImage } from "@/lib/publication";

type StoryPageProps = { params: Promise<{ slug: string }> };

export async function generateMetadata({ params }: StoryPageProps): Promise<Metadata> {
  const { slug } = await params;
  const story = await getStory(slug).catch(() => null);
  return story ? { title: story.title, description: story.deck } : {};
}

export default async function StoryPage({ params }: StoryPageProps) {
  const { slug } = await params;
  const story = await getStory(slug).catch(() => null);
  if (!story) notFound();

  const image = storyImage(story);

  return (
    <main className="story-page">
      <header className="story-lead">
        {image ? <Image className="story-lead__image" src={image} alt="" fill priority sizes="100vw" /> : null}
        <div className="story-lead__veil" />
        <div className="story-lead__copy">
          <p className="eyebrow">{story.category}</p>
          <h1>{story.title}</h1>
          <p>{story.deck}</p>
          <div><span>By {story.byline}</span><span>{story.readTimeMinutes} min read</span></div>
        </div>
      </header>
      <article className="story-body">
        <Link className="back-link" href="/"><ArrowLeft size={18} /> Today’s issue</Link>
        {story.sections.map((section) => (
          <section key={section.id}>
            {section.heading ? <h2>{section.heading}</h2> : null}
            <p>{section.body}</p>
          </section>
        ))}
      </article>
    </main>
  );
}
