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
		],
	},
};
