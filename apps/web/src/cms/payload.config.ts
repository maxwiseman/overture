import path from "node:path";
import { fileURLToPath } from "node:url";
import { postgresAdapter } from "@payloadcms/db-postgres";
import { lexicalEditor } from "@payloadcms/richtext-lexical";
import { vercelBlobStorage } from "@payloadcms/storage-vercel-blob";
import { buildConfig } from "payload";
import sharp from "sharp";

import { Articles } from "./collections/Articles";
import { Editions } from "./collections/Editions";
import { Media } from "./collections/Media";
import { Users } from "./collections/Users";

const filename = fileURLToPath(import.meta.url);
const dirname = path.dirname(filename);

export default buildConfig({
	admin: {
		importMap: {
			baseDir: path.resolve(dirname),
		},
		user: Users.slug,
	},
	collections: [Users, Media, Articles, Editions],
	db: postgresAdapter({
		migrationDir: path.resolve(dirname, "migrations"),
		schemaName: "payload",
		pool: {
			connectionString: process.env.DATABASE_URL || "",
		},
	}),
	editor: lexicalEditor(),
	plugins: [
		vercelBlobStorage({
			collections: {
				[Media.slug]: true,
			},
			enabled: Boolean(process.env.BLOB_READ_WRITE_TOKEN),
			token: process.env.BLOB_READ_WRITE_TOKEN || "",
		}),
	],
	secret: process.env.PAYLOAD_SECRET || "",
	sharp,
	typescript: {
		outputFile: path.resolve(dirname, "payload-types.ts"),
	},
});
