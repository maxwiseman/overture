import type { CollectionConfig } from "payload";

import {
	ImageBlock,
	PullQuoteBlock,
	RichTextBlock,
} from "../blocks/articleBlocks";

export const Articles: CollectionConfig = {
	slug: "articles",
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
			name: "heroImage",
			type: "upload",
			relationTo: "media",
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
			name: "body",
			type: "blocks",
			blocks: [RichTextBlock, ImageBlock, PullQuoteBlock],
			required: true,
		},
	],
};
