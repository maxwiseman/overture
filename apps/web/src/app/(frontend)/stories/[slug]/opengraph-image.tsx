import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { notFound } from "next/navigation";
import { ImageResponse } from "next/og";

import { getStory, storyImage } from "@/lib/publication";

export const alt = "Overture story";
export const size = {
	width: 1200,
	height: 630,
};
export const contentType = "image/png";

type OpenGraphImageProps = {
	params: Promise<{ slug: string }>;
};

async function imageSource(path: string) {
	if (path.startsWith("/")) {
		const image = await readFile(join(process.cwd(), "public", path));
		return `data:image/png;base64,${image.toString("base64")}`;
	}

	const response = await fetch(path);
	if (!response.ok)
		throw new Error(`Unable to load story image: ${response.status}`);
	const contentType = response.headers.get("content-type") ?? "image/jpeg";
	const image = Buffer.from(await response.arrayBuffer());
	return `data:${contentType};base64,${image.toString("base64")}`;
}

export default async function OpenGraphImage({ params }: OpenGraphImageProps) {
	const { slug } = await params;
	const story = await getStory(slug).catch(() => null);
	if (!story) notFound();

	const heroImage = storyImage(story);
	const heroSource = heroImage ? await imageSource(heroImage) : null;
	const titleSize = story.title.length > 54 ? 66 : 78;

	return new ImageResponse(
		<div
			style={{
				width: "100%",
				height: "100%",
				display: "flex",
				position: "relative",
				overflow: "hidden",
				background: "#081525",
				color: "white",
			}}
		>
			{heroSource ? (
				// biome-ignore lint/performance/noImgElement: ImageResponse renders this outside the browser.
				<img
					src={heroSource}
					alt=""
					width={size.width}
					height={size.height}
					style={{
						position: "absolute",
						inset: 0,
						width: "100%",
						height: "100%",
						objectFit: "cover",
						objectPosition: "center 55%",
					}}
				/>
			) : null}

			<div
				style={{
					position: "absolute",
					inset: 0,
					display: "flex",
					background:
						"linear-gradient(90deg, rgba(2, 7, 14, 0.94) 0%, rgba(2, 7, 14, 0.72) 52%, rgba(2, 7, 14, 0.18) 100%)",
				}}
			/>

			<div
				style={{
					position: "relative",
					width: "850px",
					height: "100%",
					padding: "66px 72px",
					display: "flex",
					flexDirection: "column",
					justifyContent: "space-between",
				}}
			>
				<div
					style={{
						display: "flex",
						fontSize: 25,
						letterSpacing: "0.08em",
						fontWeight: 650,
					}}
				>
					Overture
				</div>

				<div style={{ display: "flex", flexDirection: "column" }}>
					<div
						style={{
							display: "flex",
							color: "#78a6ff",
							fontSize: 18,
							fontWeight: 700,
							letterSpacing: "0.16em",
							textTransform: "uppercase",
							marginBottom: 18,
						}}
					>
						{story.category}
					</div>
					<div
						style={{
							display: "flex",
							fontFamily: "Georgia, serif",
							fontSize: titleSize,
							lineHeight: 0.98,
							letterSpacing: "-0.045em",
						}}
					>
						{story.title}
					</div>
				</div>
			</div>
		</div>,
		size,
	);
}
