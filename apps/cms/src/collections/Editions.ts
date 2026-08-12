import type { CollectionConfig } from "payload";

import {
	revalidatePublicationAfterChange,
	revalidatePublicationAfterDelete,
} from "../hooks/revalidatePublication";

export const Editions: CollectionConfig = {
	slug: "editions",
	hooks: {
		afterChange: [revalidatePublicationAfterChange],
		afterDelete: [revalidatePublicationAfterDelete],
	},
	admin: {
		defaultColumns: ["title", "slug", "releaseDate", "updatedAt"],
		useAsTitle: "title",
	},
	versions: {
		drafts: true,
		maxPerDoc: 25,
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
			name: "description",
			type: "textarea",
		},
		{
			name: "coverImage",
			type: "upload",
			relationTo: "media",
		},
		{
			name: "releaseDate",
			type: "date",
			required: true,
		},
		{
			name: "articles",
			type: "relationship",
			hasMany: true,
			relationTo: "articles",
			required: true,
		},
		{
			name: "theme",
			type: "json",
			admin: {
				description:
					"Presentation tokens consumed by the web and native edition renderers.",
			},
		},
	],
};
