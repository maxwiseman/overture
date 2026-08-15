import type { Field } from "payload";

const variantSections = (
	name: "glance" | "brief" | "standard",
	label: string,
): Field => ({
	name,
	type: "group",
	label,
	admin: {
		description: `${label} copy is aligned to the canonical full-article sections and remains editable before publication.`,
	},
	fields: [
		{
			name: "sections",
			type: "array",
			labels: { singular: "Section", plural: "Sections" },
			fields: [
				{
					name: "sourceSectionID",
					type: "text",
					required: true,
					admin: { readOnly: true },
				},
				{ name: "heading", type: "text" },
				{ name: "body", type: "textarea", required: true },
			],
		},
	],
});

export const articleVariantFields: Field[] = [
	{
		name: "variantGenerationControl",
		type: "ui",
		admin: {
			components: {
				Field: "/components/GenerateArticleVariants#GenerateArticleVariants",
			},
		},
	},
	{
		name: "variantGeneration",
		type: "group",
		label: "Generation details",
		admin: { condition: (_, siblingData) => Boolean(siblingData?.status) },
		fields: [
			{
				name: "status",
				type: "select",
				options: [
					{ label: "Generating", value: "generating" },
					{ label: "Needs review", value: "needs-review" },
					{ label: "Approved", value: "approved" },
					{ label: "Stale", value: "stale" },
					{ label: "Failed", value: "failed" },
				],
				admin: {
					description:
						"After review, editors can mark this version approved. Canonical body edits should be followed by regeneration.",
				},
			},
			{ name: "sourceHash", type: "text", admin: { readOnly: true } },
			{ name: "model", type: "text", admin: { readOnly: true } },
			{ name: "workflowRunID", type: "text", admin: { readOnly: true } },
			{ name: "generatedAt", type: "date", admin: { readOnly: true } },
			{ name: "lastError", type: "textarea", admin: { readOnly: true } },
		],
	},
	{
		name: "variants",
		type: "group",
		label: "Shorter versions",
		admin: {
			description:
				"Full copy remains in Body. These reviewed versions power semantic zoom in the native reader.",
		},
		fields: [
			variantSections("glance", "Glance"),
			variantSections("brief", "Brief"),
			variantSections("standard", "Standard"),
		],
	},
];
