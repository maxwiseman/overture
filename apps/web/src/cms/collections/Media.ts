import type { CollectionConfig } from "payload";

export const Media: CollectionConfig = {
	slug: "media",
	access: {
		read: () => true,
	},
	fields: [
		{
			name: "alt",
			type: "text",
			required: true,
		},
		{
			name: "caption",
			type: "textarea",
		},
		{
			name: "credit",
			type: "text",
			admin: {
				description:
					"Visible creator, agency, or publication credit. Keep this separate from accessibility alt text.",
			},
		},
		{
			name: "sourceURL",
			type: "text",
			admin: {
				description: "Page where the original or reference image was found.",
			},
		},
		{
			name: "licenseName",
			type: "text",
			admin: {
				description:
					"Required before an externally sourced image can be published (for example, Public Domain or CC BY 4.0).",
			},
		},
		{
			name: "licenseURL",
			type: "text",
		},
		{
			name: "generatedByAI",
			type: "checkbox",
			defaultValue: false,
		},
		{
			name: "generationPrompt",
			type: "textarea",
			admin: { readOnly: true },
		},
		{
			name: "referenceImageURL",
			type: "text",
			admin: {
				readOnly: true,
				description:
					"Factual visual reference supplied to the image model. This is provenance, not a republication license.",
			},
		},
	],
	upload: {
		focalPoint: true,
		imageSizes: [
			{
				name: "thumbnail",
				width: 480,
			},
			{
				name: "article",
				width: 1600,
			},
			{
				name: "heroDesktop",
				width: 1536,
				height: 1024,
				fit: "cover",
			},
			{
				name: "heroMobile",
				width: 1024,
				height: 1536,
				fit: "cover",
			},
		],
	},
};
