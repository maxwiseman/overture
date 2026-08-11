import type { Block } from "payload";

export const RichTextBlock: Block = {
	slug: "richText",
	fields: [
		{
			name: "content",
			type: "richText",
			required: true,
		},
	],
};

export const ImageBlock: Block = {
	slug: "image",
	fields: [
		{
			name: "image",
			type: "upload",
			relationTo: "media",
			required: true,
		},
		{
			name: "caption",
			type: "text",
		},
	],
};

export const PullQuoteBlock: Block = {
	slug: "pullQuote",
	fields: [
		{
			name: "quote",
			type: "textarea",
			required: true,
		},
		{
			name: "attribution",
			type: "text",
		},
	],
};
