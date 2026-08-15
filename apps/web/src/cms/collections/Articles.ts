import type { CollectionConfig } from "payload";

import {
	ImageBlock,
	PullQuoteBlock,
	RichTextBlock,
} from "../blocks/articleBlocks";
import { articleGenerationEndpoints } from "../endpoints/articleGeneration";
import { articleVariantFields } from "../fields/articleVariants";
import {
	revalidatePublicationAfterChange,
	revalidatePublicationAfterDelete,
} from "../hooks/revalidatePublication";

export const Articles: CollectionConfig = {
	slug: "articles",
	endpoints: articleGenerationEndpoints,
	hooks: {
		afterChange: [revalidatePublicationAfterChange],
		afterDelete: [revalidatePublicationAfterDelete],
	},
	admin: {
		defaultColumns: ["title", "status", "publishedAt", "updatedAt"],
		useAsTitle: "title",
	},
	versions: {
		drafts: {
			autosave: true,
			schedulePublish: true,
		},
		maxPerDoc: 50,
	},
	access: {
		read: ({ req }) => {
			if (req.user) return true;

			return {
				_status: {
					equals: "published",
				},
			};
		},
	},
	fields: [
		{
			name: "title",
			type: "text",
			required: true,
		},
		{
			name: "slug",
			type: "text",
			index: true,
			required: true,
			unique: true,
		},
		{
			name: "dek",
			type: "textarea",
		},
		{
			name: "byline",
			type: "text",
			required: true,
		},
		{
			name: "category",
			type: "text",
			defaultValue: "Ideas",
			required: true,
		},
		{
			name: "estimatedReadingMinutes",
			type: "number",
			defaultValue: 5,
			min: 1,
			required: true,
		},
		{
			name: "heroImage",
			type: "upload",
			relationTo: "media",
		},
		{
			name: "heroImageMobile",
			type: "upload",
			relationTo: "media",
			admin: {
				description:
					"A deliberately reframed portrait asset. Falls back to the desktop hero when empty.",
			},
		},
		{
			name: "heroImageCandidates",
			type: "upload",
			relationTo: "media",
			hasMany: true,
			maxRows: 2,
			admin: {
				description:
					"The desktop alternatives considered by the visual agent. heroImage is its selected candidate.",
			},
		},
		{
			name: "visualGeneration",
			type: "group",
			label: "Visual generation",
			fields: [
				{
					name: "status",
					type: "select",
					options: [
						{ label: "Generating", value: "generating" },
						{ label: "Needs review", value: "needs-review" },
						{ label: "Approved", value: "approved" },
						{ label: "Skipped", value: "skipped" },
						{ label: "Failed", value: "failed" },
					],
				},
				{ name: "model", type: "text", admin: { readOnly: true } },
				{
					name: "selectedCandidate",
					type: "number",
					min: 1,
					max: 2,
					admin: { readOnly: true },
				},
				{ name: "generatedAt", type: "date", admin: { readOnly: true } },
				{ name: "lastError", type: "textarea", admin: { readOnly: true } },
			],
		},
		{
			name: "publishedAt",
			type: "date",
			admin: {
				date: {
					pickerAppearance: "dayAndTime",
				},
			},
		},
		{
			name: "sourceURL",
			type: "text",
			index: true,
			unique: true,
			admin: {
				description:
					"Original URL for an article imported through the Overture share extension.",
			},
		},
		{ name: "importedAt", type: "date", admin: { readOnly: true } },
		{ name: "importedBy", type: "text", admin: { readOnly: true } },
		{
			name: "body",
			type: "blocks",
			blocks: [RichTextBlock, ImageBlock, PullQuoteBlock],
			required: true,
		},
		...articleVariantFields,
	],
};
