import { ChevronDown } from "lucide-react";
import type { Route } from "next";
import Image from "next/image";
import Link from "next/link";

import { StoriesSection } from "@/components/stories-section";
import { getCurrentEdition, storyImage } from "@/lib/publication";

const storyHref = (slug: string) => `/stories/${slug}` as Route;

export const instant = true;

export default function Home() {
	return <PublicationHome />;
}

async function PublicationHome() {
	const edition = await getCurrentEdition().catch(() => null);

	if (!edition || edition.stories.length === 0) {
		return (
			<main className="grid min-h-[calc(100svh-88px)] place-items-center bg-[#05080c] p-10 text-white">
				<h1 className="font-[Georgia,'Times_New_Roman',serif] font-normal text-5xl">
					The next issue is being prepared.
				</h1>
			</main>
		);
	}

	const lead = edition.stories[0];
	const leadImage = storyImage(lead);

	return (
		<main>
			<section className="relative min-h-196 overflow-hidden bg-[#081525] text-white max-[800px]:min-h-svh">
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
				<div className="absolute inset-0 bg-[linear-gradient(90deg,rgb(2_7_14/0.82)_0%,rgb(2_7_14/0.45)_38%,transparent_70%),linear-gradient(0deg,rgb(2_5_10/0.45),transparent_55%)] max-[800px]:bg-[linear-gradient(0deg,rgb(2_7_14/0.88)_0%,rgb(2_7_14/0.28)_72%)]" />
				<div className="relative z-2 mx-auto flex min-h-196 max-w-360 flex-col items-start justify-center px-10.5 pt-47.5 pb-17.5 max-[800px]:min-h-svh max-[800px]:justify-end max-[800px]:px-5 max-[800px]:pt-45 max-[800px]:pb-13.5">
					<h1 className="m-0 max-w-165 font-[Georgia,'Times_New_Roman',serif] font-normal text-[clamp(4.5rem,7.15vw,7.1rem)] leading-[0.96] tracking-[-0.055em] max-[800px]:max-w-87.5 max-[800px]:text-[clamp(3.6rem,17vw,5.1rem)]">
						{lead.title}
					</h1>
					<p className="mt-8 max-w-127.5 text-[1.35rem] text-white/85 leading-[1.45] max-[800px]:mt-5.5 max-[800px]:max-w-86.25 max-[800px]:text-[1.05rem]">
						{lead.deck}
					</p>
					<p className="mt-8.5 text-base max-[800px]:mt-5.5">
						{lead.readTimeMinutes} min read
					</p>
					<Link
						className="absolute inset-0 z-1"
						href={storyHref(lead.slug)}
						prefetch
						aria-label={`Read ${lead.title}`}
					/>
				</div>
				<details className="group absolute top-31.5 right-[max(42px,calc((100vw-1440px)/2+42px))] z-4 w-65 max-[800px]:top-30.5 max-[800px]:right-5 max-[800px]:w-auto">
					<summary className="flex h-16 cursor-pointer list-none items-center gap-4 rounded-[14px] bg-[rgb(4_10_18/0.82)] px-6 backdrop-blur-[20px] max-[800px]:h-12 max-[800px]:px-4 max-[800px]:text-[0.82rem] [&::-webkit-details-marker]:hidden">
						<ChevronDown
							className="group-open:rotate-180"
							size={20}
							aria-hidden="true"
						/>{" "}
						{edition.title}
					</summary>
					<div className="mt-2 rounded-[14px] bg-[rgb(4_10_18/0.94)] px-6 py-5 text-white/76 shadow-[0_18px_60px_rgb(0_0_0/0.3)] max-[800px]:absolute max-[800px]:right-0 max-[800px]:w-62.5">
						<p className="mb-3.5 leading-normal">{edition.description}</p>
						<ol className="mt-5 list-none border-white/14 border-t p-0">
							{edition.stories.map((story, index) => (
								<li
									className="grid grid-cols-[30px_1fr] gap-2.5 border-white/14 border-b py-3.25"
									key={story.id}
								>
									<span className="text-[#4b8dff] text-[0.7rem] tracking-widest">
										{(index + 1).toString().padStart(2, "0")}
									</span>
									<Link
										className="font-[Georgia,'Times_New_Roman',serif] text-base text-white leading-[1.15]"
										href={storyHref(story.slug)}
										prefetch
									>
										{story.title}
									</Link>
								</li>
							))}
						</ol>
					</div>
				</details>
			</section>

			<StoriesSection edition={edition} query="" />
		</main>
	);
}
