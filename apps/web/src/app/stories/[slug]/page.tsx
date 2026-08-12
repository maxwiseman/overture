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
    <main>
      <header className="relative min-h-[738px] overflow-hidden bg-[#081525] text-white max-[800px]:min-h-svh">
        {image ? <Image className="object-cover object-[center_55%]" src={image} alt="" fill priority sizes="100vw" /> : null}
        <div className="absolute inset-0 bg-[linear-gradient(90deg,rgb(2_7_14_/_0.86),rgb(2_7_14_/_0.28)_65%,transparent)]" />
        <div className="relative z-2 mx-auto flex min-h-[738px] max-w-[1440px] flex-col items-start justify-end px-[42px] pt-[150px] pb-[70px] max-[800px]:min-h-svh max-[800px]:px-5 max-[800px]:pb-12">
          <p className="mb-3 text-[0.72rem] font-[650] tracking-[0.17em] text-[#2d6bd1] uppercase">{story.category}</p>
          <h1 className="m-0 max-w-[760px] [font-family:Georgia,'Times_New_Roman',serif] text-[clamp(4rem,7vw,7rem)] leading-[0.95] font-normal tracking-[-0.055em] max-[800px]:text-[clamp(3.5rem,16vw,5rem)]">{story.title}</h1>
          <p className="my-7 max-w-[580px] text-[1.3rem] leading-normal text-white/82 max-[800px]:text-[1.05rem]">{story.deck}</p>
          <div className="flex gap-[26px] text-[0.9rem] text-white/70"><span>By {story.byline}</span><span>{story.readTimeMinutes} min read</span></div>
        </div>
      </header>
      <article className="mx-auto max-w-[740px] px-8 pt-[76px] pb-[130px] [&_section+section]:mt-[42px] [&_section_h2]:[font-family:Georgia,'Times_New_Roman',serif] [&_section_h2]:text-[2.2rem] [&_section_h2]:font-normal [&_section_p]:m-0 [&_section_p]:[font-family:Georgia,'Times_New_Roman',serif] [&_section_p]:text-[clamp(1.35rem,2vw,1.65rem)] [&_section_p]:leading-[1.65] [&_section_p]:text-[#22211f]">
        <Link className="mb-[68px] flex items-center gap-2 text-[0.88rem] text-[#2d6bd1]" href="/"><ArrowLeft size={18} /> Today’s issue</Link>
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
