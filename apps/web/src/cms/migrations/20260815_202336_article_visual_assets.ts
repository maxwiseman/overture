import { sql } from '@payloadcms/db-postgres'
import type { MigrateDownArgs, MigrateUpArgs } from '@payloadcms/db-postgres'

export async function up({ db, payload, req }: MigrateUpArgs): Promise<void> {
  await db.execute(sql`
   CREATE TYPE "payload"."enum_articles_visual_generation_status" AS ENUM('generating', 'needs-review', 'approved', 'skipped', 'failed');
  CREATE TYPE "payload"."enum__articles_v_version_visual_generation_status" AS ENUM('generating', 'needs-review', 'approved', 'skipped', 'failed');
  CREATE TABLE "payload"."articles_rels" (
  	"id" serial PRIMARY KEY NOT NULL,
  	"order" integer,
  	"parent_id" integer NOT NULL,
  	"path" varchar NOT NULL,
  	"media_id" integer
  );
  
  CREATE TABLE "payload"."_articles_v_rels" (
  	"id" serial PRIMARY KEY NOT NULL,
  	"order" integer,
  	"parent_id" integer NOT NULL,
  	"path" varchar NOT NULL,
  	"media_id" integer
  );
  
  ALTER TABLE "payload"."media" ADD COLUMN "credit" varchar;
  ALTER TABLE "payload"."media" ADD COLUMN "source_u_r_l" varchar;
  ALTER TABLE "payload"."media" ADD COLUMN "license_name" varchar;
  ALTER TABLE "payload"."media" ADD COLUMN "license_u_r_l" varchar;
  ALTER TABLE "payload"."media" ADD COLUMN "generated_by_a_i" boolean DEFAULT false;
  ALTER TABLE "payload"."media" ADD COLUMN "generation_prompt" varchar;
  ALTER TABLE "payload"."media" ADD COLUMN "reference_image_u_r_l" varchar;
  ALTER TABLE "payload"."media" ADD COLUMN "sizes_hero_desktop_url" varchar;
  ALTER TABLE "payload"."media" ADD COLUMN "sizes_hero_desktop_width" numeric;
  ALTER TABLE "payload"."media" ADD COLUMN "sizes_hero_desktop_height" numeric;
  ALTER TABLE "payload"."media" ADD COLUMN "sizes_hero_desktop_mime_type" varchar;
  ALTER TABLE "payload"."media" ADD COLUMN "sizes_hero_desktop_filesize" numeric;
  ALTER TABLE "payload"."media" ADD COLUMN "sizes_hero_desktop_filename" varchar;
  ALTER TABLE "payload"."media" ADD COLUMN "sizes_hero_mobile_url" varchar;
  ALTER TABLE "payload"."media" ADD COLUMN "sizes_hero_mobile_width" numeric;
  ALTER TABLE "payload"."media" ADD COLUMN "sizes_hero_mobile_height" numeric;
  ALTER TABLE "payload"."media" ADD COLUMN "sizes_hero_mobile_mime_type" varchar;
  ALTER TABLE "payload"."media" ADD COLUMN "sizes_hero_mobile_filesize" numeric;
  ALTER TABLE "payload"."media" ADD COLUMN "sizes_hero_mobile_filename" varchar;
  ALTER TABLE "payload"."articles_blocks_image" ADD COLUMN "credit" varchar;
  ALTER TABLE "payload"."articles" ADD COLUMN "hero_image_mobile_id" integer;
  ALTER TABLE "payload"."articles" ADD COLUMN "visual_generation_status" "payload"."enum_articles_visual_generation_status";
  ALTER TABLE "payload"."articles" ADD COLUMN "visual_generation_model" varchar;
  ALTER TABLE "payload"."articles" ADD COLUMN "visual_generation_selected_candidate" numeric;
  ALTER TABLE "payload"."articles" ADD COLUMN "visual_generation_generated_at" timestamp(3) with time zone;
  ALTER TABLE "payload"."articles" ADD COLUMN "visual_generation_last_error" varchar;
  ALTER TABLE "payload"."_articles_v_blocks_image" ADD COLUMN "credit" varchar;
  ALTER TABLE "payload"."_articles_v" ADD COLUMN "version_hero_image_mobile_id" integer;
  ALTER TABLE "payload"."_articles_v" ADD COLUMN "version_visual_generation_status" "payload"."enum__articles_v_version_visual_generation_status";
  ALTER TABLE "payload"."_articles_v" ADD COLUMN "version_visual_generation_model" varchar;
  ALTER TABLE "payload"."_articles_v" ADD COLUMN "version_visual_generation_selected_candidate" numeric;
  ALTER TABLE "payload"."_articles_v" ADD COLUMN "version_visual_generation_generated_at" timestamp(3) with time zone;
  ALTER TABLE "payload"."_articles_v" ADD COLUMN "version_visual_generation_last_error" varchar;
  ALTER TABLE "payload"."articles_rels" ADD CONSTRAINT "articles_rels_parent_fk" FOREIGN KEY ("parent_id") REFERENCES "payload"."articles"("id") ON DELETE cascade ON UPDATE no action;
  ALTER TABLE "payload"."articles_rels" ADD CONSTRAINT "articles_rels_media_fk" FOREIGN KEY ("media_id") REFERENCES "payload"."media"("id") ON DELETE cascade ON UPDATE no action;
  ALTER TABLE "payload"."_articles_v_rels" ADD CONSTRAINT "_articles_v_rels_parent_fk" FOREIGN KEY ("parent_id") REFERENCES "payload"."_articles_v"("id") ON DELETE cascade ON UPDATE no action;
  ALTER TABLE "payload"."_articles_v_rels" ADD CONSTRAINT "_articles_v_rels_media_fk" FOREIGN KEY ("media_id") REFERENCES "payload"."media"("id") ON DELETE cascade ON UPDATE no action;
  CREATE INDEX "articles_rels_order_idx" ON "payload"."articles_rels" USING btree ("order");
  CREATE INDEX "articles_rels_parent_idx" ON "payload"."articles_rels" USING btree ("parent_id");
  CREATE INDEX "articles_rels_path_idx" ON "payload"."articles_rels" USING btree ("path");
  CREATE INDEX "articles_rels_media_id_idx" ON "payload"."articles_rels" USING btree ("media_id");
  CREATE INDEX "_articles_v_rels_order_idx" ON "payload"."_articles_v_rels" USING btree ("order");
  CREATE INDEX "_articles_v_rels_parent_idx" ON "payload"."_articles_v_rels" USING btree ("parent_id");
  CREATE INDEX "_articles_v_rels_path_idx" ON "payload"."_articles_v_rels" USING btree ("path");
  CREATE INDEX "_articles_v_rels_media_id_idx" ON "payload"."_articles_v_rels" USING btree ("media_id");
  ALTER TABLE "payload"."articles" ADD CONSTRAINT "articles_hero_image_mobile_id_media_id_fk" FOREIGN KEY ("hero_image_mobile_id") REFERENCES "payload"."media"("id") ON DELETE set null ON UPDATE no action;
  ALTER TABLE "payload"."_articles_v" ADD CONSTRAINT "_articles_v_version_hero_image_mobile_id_media_id_fk" FOREIGN KEY ("version_hero_image_mobile_id") REFERENCES "payload"."media"("id") ON DELETE set null ON UPDATE no action;
  CREATE INDEX "media_sizes_hero_desktop_sizes_hero_desktop_filename_idx" ON "payload"."media" USING btree ("sizes_hero_desktop_filename");
  CREATE INDEX "media_sizes_hero_mobile_sizes_hero_mobile_filename_idx" ON "payload"."media" USING btree ("sizes_hero_mobile_filename");
  CREATE INDEX "articles_hero_image_mobile_idx" ON "payload"."articles" USING btree ("hero_image_mobile_id");
  CREATE INDEX "_articles_v_version_version_hero_image_mobile_idx" ON "payload"."_articles_v" USING btree ("version_hero_image_mobile_id");`)
}

export async function down({ db, payload, req }: MigrateDownArgs): Promise<void> {
  await db.execute(sql`
   ALTER TABLE "payload"."articles_rels" DISABLE ROW LEVEL SECURITY;
  ALTER TABLE "payload"."_articles_v_rels" DISABLE ROW LEVEL SECURITY;
  DROP TABLE "payload"."articles_rels" CASCADE;
  DROP TABLE "payload"."_articles_v_rels" CASCADE;
  ALTER TABLE "payload"."articles" DROP CONSTRAINT "articles_hero_image_mobile_id_media_id_fk";
  
  ALTER TABLE "payload"."_articles_v" DROP CONSTRAINT "_articles_v_version_hero_image_mobile_id_media_id_fk";
  
  DROP INDEX "payload"."media_sizes_hero_desktop_sizes_hero_desktop_filename_idx";
  DROP INDEX "payload"."media_sizes_hero_mobile_sizes_hero_mobile_filename_idx";
  DROP INDEX "payload"."articles_hero_image_mobile_idx";
  DROP INDEX "payload"."_articles_v_version_version_hero_image_mobile_idx";
  ALTER TABLE "payload"."media" DROP COLUMN "credit";
  ALTER TABLE "payload"."media" DROP COLUMN "source_u_r_l";
  ALTER TABLE "payload"."media" DROP COLUMN "license_name";
  ALTER TABLE "payload"."media" DROP COLUMN "license_u_r_l";
  ALTER TABLE "payload"."media" DROP COLUMN "generated_by_a_i";
  ALTER TABLE "payload"."media" DROP COLUMN "generation_prompt";
  ALTER TABLE "payload"."media" DROP COLUMN "reference_image_u_r_l";
  ALTER TABLE "payload"."media" DROP COLUMN "sizes_hero_desktop_url";
  ALTER TABLE "payload"."media" DROP COLUMN "sizes_hero_desktop_width";
  ALTER TABLE "payload"."media" DROP COLUMN "sizes_hero_desktop_height";
  ALTER TABLE "payload"."media" DROP COLUMN "sizes_hero_desktop_mime_type";
  ALTER TABLE "payload"."media" DROP COLUMN "sizes_hero_desktop_filesize";
  ALTER TABLE "payload"."media" DROP COLUMN "sizes_hero_desktop_filename";
  ALTER TABLE "payload"."media" DROP COLUMN "sizes_hero_mobile_url";
  ALTER TABLE "payload"."media" DROP COLUMN "sizes_hero_mobile_width";
  ALTER TABLE "payload"."media" DROP COLUMN "sizes_hero_mobile_height";
  ALTER TABLE "payload"."media" DROP COLUMN "sizes_hero_mobile_mime_type";
  ALTER TABLE "payload"."media" DROP COLUMN "sizes_hero_mobile_filesize";
  ALTER TABLE "payload"."media" DROP COLUMN "sizes_hero_mobile_filename";
  ALTER TABLE "payload"."articles_blocks_image" DROP COLUMN "credit";
  ALTER TABLE "payload"."articles" DROP COLUMN "hero_image_mobile_id";
  ALTER TABLE "payload"."articles" DROP COLUMN "visual_generation_status";
  ALTER TABLE "payload"."articles" DROP COLUMN "visual_generation_model";
  ALTER TABLE "payload"."articles" DROP COLUMN "visual_generation_selected_candidate";
  ALTER TABLE "payload"."articles" DROP COLUMN "visual_generation_generated_at";
  ALTER TABLE "payload"."articles" DROP COLUMN "visual_generation_last_error";
  ALTER TABLE "payload"."_articles_v_blocks_image" DROP COLUMN "credit";
  ALTER TABLE "payload"."_articles_v" DROP COLUMN "version_hero_image_mobile_id";
  ALTER TABLE "payload"."_articles_v" DROP COLUMN "version_visual_generation_status";
  ALTER TABLE "payload"."_articles_v" DROP COLUMN "version_visual_generation_model";
  ALTER TABLE "payload"."_articles_v" DROP COLUMN "version_visual_generation_selected_candidate";
  ALTER TABLE "payload"."_articles_v" DROP COLUMN "version_visual_generation_generated_at";
  ALTER TABLE "payload"."_articles_v" DROP COLUMN "version_visual_generation_last_error";
  DROP TYPE "payload"."enum_articles_visual_generation_status";
  DROP TYPE "payload"."enum__articles_v_version_visual_generation_status";`)
}
