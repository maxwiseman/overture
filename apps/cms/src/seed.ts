import { getPayload } from "payload";

import config from "./payload.config";

type StarterStory = {
	slug: string;
	title: string;
	dek: string;
	byline: string;
	category: string;
	estimatedReadingMinutes: number;
	sections: string[];
};

const starterStories: StarterStory[] = [
	{
		slug: "quiet-flight",
		title: "The Shape of Quiet Flight",
		dek: "NASA’s experimental aircraft is testing whether supersonic travel can become quiet enough for cities.",
		byline: "Mara Bell",
		category: "Aviation",
		estimatedReadingMinutes: 7,
		sections: [
			"For more than half a century, the sonic boom made commercial supersonic flight incompatible with life below. NASA’s X-59 is designed around a different premise: reshape the pressure wave itself.",
			"Its long needle nose keeps pressure waves separated so people on the ground should hear something closer to a distant car door than an explosive crack.",
			"The decisive test belongs to communities beneath the flight path. Their responses could give regulators evidence for sound-based limits rather than an absolute ban on supersonic flight over land.",
		],
	},
	{
		slug: "paper-battery",
		title: "A Battery Made From Paper",
		dek: "Engineers created a flexible cell from paper-based materials that could power a new wave of tiny devices.",
		byline: "Mara Bell",
		category: "Materials",
		estimatedReadingMinutes: 6,
		sections: [
			"A thin square of paper can produce enough electricity for a small sensor. Its layers use inexpensive, flexible materials and activate with a drop of water.",
			"The dry battery remains dormant during storage. Water dissolves salts embedded in the paper, allowing ions to move between printed conductive layers.",
			"The opportunity is less about a spectacular battery than eliminating millions of quiet, wasteful ones in diagnostic tests, environmental sensors, and smart packaging.",
		],
	},
	{
		slug: "laundry-robot",
		title: "The Robot That Learned to Fold Laundry",
		dek: "A new AI model helps robots handle the unpredictable—one shirt at a time.",
		byline: "Mara Bell",
		category: "Robotics",
		estimatedReadingMinutes: 8,
		sections: [
			"Laundry exposes a stubborn weakness in robotics: every shirt collapses into a different shape. A new system learns to identify corners, sleeves, and layers, then revises its plan when the fabric moves unexpectedly.",
			"Cameras estimate the garment’s hidden structure. The model predicts what a grasp will reveal, performs the move, and looks again.",
			"The prototype remains too slow and expensive for most homes, but its ability to notice uncertainty and recover could transfer to many ordinary household tasks.",
		],
	},
];

function richTextBlock(text: string, index: number) {
	return {
		blockName: `Section ${index + 1}`,
		blockType: "richText" as const,
		content: {
			root: {
				type: "root",
				format: "" as const,
				indent: 0,
				version: 1,
				direction: "ltr" as const,
				children: [
					{
						type: "paragraph",
						format: "" as const,
						indent: 0,
						version: 1,
						direction: "ltr" as const,
						textFormat: 0,
						textStyle: "",
						children: [
							{
								type: "text",
								format: 0,
								style: "",
								mode: "normal",
								detail: 0,
								version: 1,
								text,
							},
						],
					},
				],
			},
		},
	};
}

const payload = await getPayload({ config });
const publishedAt = new Date().toISOString();
const articleIDs: number[] = [];

for (const story of starterStories) {
	const existing = await payload.find({
		collection: "articles",
		where: { slug: { equals: story.slug } },
		limit: 1,
		draft: true,
		overrideAccess: true,
	});

	const data = {
		title: story.title,
		slug: story.slug,
		dek: story.dek,
		byline: story.byline,
		category: story.category,
		estimatedReadingMinutes: story.estimatedReadingMinutes,
		publishedAt,
		body: story.sections.map(richTextBlock),
		_status: "published" as const,
	};

	const article = existing.docs[0]
		? await payload.update({
				collection: "articles",
				id: existing.docs[0].id,
				data,
				overrideAccess: true,
			})
		: await payload.create({
				collection: "articles",
				data,
				overrideAccess: true,
			});

	articleIDs.push(article.id);
}

const existingEdition = await payload.find({
	collection: "editions",
	where: { slug: { equals: "tomorrow" } },
	limit: 1,
	draft: true,
	overrideAccess: true,
});

const editionData = {
	title: "Tomorrow Issue",
	slug: "tomorrow",
	description: "Three ideas making tomorrow feel possible.",
	releaseDate: publishedAt,
	articles: articleIDs,
	_status: "published" as const,
};

if (existingEdition.docs[0]) {
	await payload.update({
		collection: "editions",
		id: existingEdition.docs[0].id,
		data: editionData,
		overrideAccess: true,
	});
} else {
	await payload.create({
		collection: "editions",
		data: editionData,
		overrideAccess: true,
	});
}

payload.logger.info(`Seeded ${articleIDs.length} published stories and the Tomorrow Issue.`);
process.exit(0);
