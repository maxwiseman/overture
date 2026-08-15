import { sql } from '@payloadcms/db-postgres'
import type { MigrateDownArgs, MigrateUpArgs } from '@payloadcms/db-postgres'

export async function up({ db, payload, req }: MigrateUpArgs): Promise<void> {
  await db.execute(sql`
   CREATE TYPE "payload"."enum_articles_variant_generation_status" AS ENUM('generating', 'needs-review', 'approved', 'stale', 'failed');
  CREATE TYPE "payload"."enum__articles_v_version_variant_generation_status" AS ENUM('generating', 'needs-review', 'approved', 'stale', 'failed');
  CREATE TABLE "payload"."articles_variants_glance_sections" (
  	"_order" integer NOT NULL,
  	"_parent_id" integer NOT NULL,
  	"id" varchar PRIMARY KEY NOT NULL,
  	"source_section_i_d" varchar,
  	"heading" varchar,
  	"body" varchar
  );
  
  CREATE TABLE "payload"."articles_variants_brief_sections" (
  	"_order" integer NOT NULL,
  	"_parent_id" integer NOT NULL,
  	"id" varchar PRIMARY KEY NOT NULL,
  	"source_section_i_d" varchar,
  	"heading" varchar,
  	"body" varchar
  );
  
  CREATE TABLE "payload"."articles_variants_standard_sections" (
  	"_order" integer NOT NULL,
  	"_parent_id" integer NOT NULL,
  	"id" varchar PRIMARY KEY NOT NULL,
  	"source_section_i_d" varchar,
  	"heading" varchar,
  	"body" varchar
  );
  
  CREATE TABLE "payload"."_articles_v_version_variants_glance_sections" (
  	"_order" integer NOT NULL,
  	"_parent_id" integer NOT NULL,
  	"id" serial PRIMARY KEY NOT NULL,
  	"source_section_i_d" varchar,
  	"heading" varchar,
  	"body" varchar,
  	"_uuid" varchar
  );
  
  CREATE TABLE "payload"."_articles_v_version_variants_brief_sections" (
  	"_order" integer NOT NULL,
  	"_parent_id" integer NOT NULL,
  	"id" serial PRIMARY KEY NOT NULL,
  	"source_section_i_d" varchar,
  	"heading" varchar,
  	"body" varchar,
  	"_uuid" varchar
  );
  
  CREATE TABLE "payload"."_articles_v_version_variants_standard_sections" (
  	"_order" integer NOT NULL,
  	"_parent_id" integer NOT NULL,
  	"id" serial PRIMARY KEY NOT NULL,
  	"source_section_i_d" varchar,
  	"heading" varchar,
  	"body" varchar,
  	"_uuid" varchar
  );
  
  ALTER TABLE "payload"."articles_blocks_rich_text" ADD COLUMN "heading" varchar;
  ALTER TABLE "payload"."articles" ADD COLUMN "source_u_r_l" varchar;
  ALTER TABLE "payload"."articles" ADD COLUMN "imported_at" timestamp(3) with time zone;
  ALTER TABLE "payload"."articles" ADD COLUMN "imported_by" varchar;
  ALTER TABLE "payload"."articles" ADD COLUMN "variant_generation_status" "payload"."enum_articles_variant_generation_status";
  ALTER TABLE "payload"."articles" ADD COLUMN "variant_generation_source_hash" varchar;
  ALTER TABLE "payload"."articles" ADD COLUMN "variant_generation_model" varchar;
  ALTER TABLE "payload"."articles" ADD COLUMN "variant_generation_workflow_run_i_d" varchar;
  ALTER TABLE "payload"."articles" ADD COLUMN "variant_generation_generated_at" timestamp(3) with time zone;
  ALTER TABLE "payload"."articles" ADD COLUMN "variant_generation_last_error" varchar;
  ALTER TABLE "payload"."_articles_v_blocks_rich_text" ADD COLUMN "heading" varchar;
  ALTER TABLE "payload"."_articles_v" ADD COLUMN "version_source_u_r_l" varchar;
  ALTER TABLE "payload"."_articles_v" ADD COLUMN "version_imported_at" timestamp(3) with time zone;
  ALTER TABLE "payload"."_articles_v" ADD COLUMN "version_imported_by" varchar;
  ALTER TABLE "payload"."_articles_v" ADD COLUMN "version_variant_generation_status" "payload"."enum__articles_v_version_variant_generation_status";
  ALTER TABLE "payload"."_articles_v" ADD COLUMN "version_variant_generation_source_hash" varchar;
  ALTER TABLE "payload"."_articles_v" ADD COLUMN "version_variant_generation_model" varchar;
  ALTER TABLE "payload"."_articles_v" ADD COLUMN "version_variant_generation_workflow_run_i_d" varchar;
  ALTER TABLE "payload"."_articles_v" ADD COLUMN "version_variant_generation_generated_at" timestamp(3) with time zone;
  ALTER TABLE "payload"."_articles_v" ADD COLUMN "version_variant_generation_last_error" varchar;
  ALTER TABLE "payload"."articles_variants_glance_sections" ADD CONSTRAINT "articles_variants_glance_sections_parent_id_fk" FOREIGN KEY ("_parent_id") REFERENCES "payload"."articles"("id") ON DELETE cascade ON UPDATE no action;
  ALTER TABLE "payload"."articles_variants_brief_sections" ADD CONSTRAINT "articles_variants_brief_sections_parent_id_fk" FOREIGN KEY ("_parent_id") REFERENCES "payload"."articles"("id") ON DELETE cascade ON UPDATE no action;
  ALTER TABLE "payload"."articles_variants_standard_sections" ADD CONSTRAINT "articles_variants_standard_sections_parent_id_fk" FOREIGN KEY ("_parent_id") REFERENCES "payload"."articles"("id") ON DELETE cascade ON UPDATE no action;
  ALTER TABLE "payload"."_articles_v_version_variants_glance_sections" ADD CONSTRAINT "_articles_v_version_variants_glance_sections_parent_id_fk" FOREIGN KEY ("_parent_id") REFERENCES "payload"."_articles_v"("id") ON DELETE cascade ON UPDATE no action;
  ALTER TABLE "payload"."_articles_v_version_variants_brief_sections" ADD CONSTRAINT "_articles_v_version_variants_brief_sections_parent_id_fk" FOREIGN KEY ("_parent_id") REFERENCES "payload"."_articles_v"("id") ON DELETE cascade ON UPDATE no action;
  ALTER TABLE "payload"."_articles_v_version_variants_standard_sections" ADD CONSTRAINT "_articles_v_version_variants_standard_sections_parent_id_fk" FOREIGN KEY ("_parent_id") REFERENCES "payload"."_articles_v"("id") ON DELETE cascade ON UPDATE no action;
  CREATE INDEX "articles_variants_glance_sections_order_idx" ON "payload"."articles_variants_glance_sections" USING btree ("_order");
  CREATE INDEX "articles_variants_glance_sections_parent_id_idx" ON "payload"."articles_variants_glance_sections" USING btree ("_parent_id");
  CREATE INDEX "articles_variants_brief_sections_order_idx" ON "payload"."articles_variants_brief_sections" USING btree ("_order");
  CREATE INDEX "articles_variants_brief_sections_parent_id_idx" ON "payload"."articles_variants_brief_sections" USING btree ("_parent_id");
  CREATE INDEX "articles_variants_standard_sections_order_idx" ON "payload"."articles_variants_standard_sections" USING btree ("_order");
  CREATE INDEX "articles_variants_standard_sections_parent_id_idx" ON "payload"."articles_variants_standard_sections" USING btree ("_parent_id");
  CREATE INDEX "_articles_v_version_variants_glance_sections_order_idx" ON "payload"."_articles_v_version_variants_glance_sections" USING btree ("_order");
  CREATE INDEX "_articles_v_version_variants_glance_sections_parent_id_idx" ON "payload"."_articles_v_version_variants_glance_sections" USING btree ("_parent_id");
  CREATE INDEX "_articles_v_version_variants_brief_sections_order_idx" ON "payload"."_articles_v_version_variants_brief_sections" USING btree ("_order");
  CREATE INDEX "_articles_v_version_variants_brief_sections_parent_id_idx" ON "payload"."_articles_v_version_variants_brief_sections" USING btree ("_parent_id");
  CREATE INDEX "_articles_v_version_variants_standard_sections_order_idx" ON "payload"."_articles_v_version_variants_standard_sections" USING btree ("_order");
  CREATE INDEX "_articles_v_version_variants_standard_sections_parent_id_idx" ON "payload"."_articles_v_version_variants_standard_sections" USING btree ("_parent_id");
  CREATE UNIQUE INDEX "articles_source_u_r_l_idx" ON "payload"."articles" USING btree ("source_u_r_l");
  CREATE INDEX "_articles_v_version_version_source_u_r_l_idx" ON "payload"."_articles_v" USING btree ("version_source_u_r_l");`)
}

export async function down({ db, payload, req }: MigrateDownArgs): Promise<void> {
  await db.execute(sql`
   ALTER TABLE "payload"."articles_variants_glance_sections" DISABLE ROW LEVEL SECURITY;
  ALTER TABLE "payload"."articles_variants_brief_sections" DISABLE ROW LEVEL SECURITY;
  ALTER TABLE "payload"."articles_variants_standard_sections" DISABLE ROW LEVEL SECURITY;
  ALTER TABLE "payload"."_articles_v_version_variants_glance_sections" DISABLE ROW LEVEL SECURITY;
  ALTER TABLE "payload"."_articles_v_version_variants_brief_sections" DISABLE ROW LEVEL SECURITY;
  ALTER TABLE "payload"."_articles_v_version_variants_standard_sections" DISABLE ROW LEVEL SECURITY;
  DROP TABLE "payload"."articles_variants_glance_sections" CASCADE;
  DROP TABLE "payload"."articles_variants_brief_sections" CASCADE;
  DROP TABLE "payload"."articles_variants_standard_sections" CASCADE;
  DROP TABLE "payload"."_articles_v_version_variants_glance_sections" CASCADE;
  DROP TABLE "payload"."_articles_v_version_variants_brief_sections" CASCADE;
  DROP TABLE "payload"."_articles_v_version_variants_standard_sections" CASCADE;
  DROP INDEX "payload"."articles_source_u_r_l_idx";
  DROP INDEX "payload"."_articles_v_version_version_source_u_r_l_idx";
  ALTER TABLE "payload"."articles_blocks_rich_text" DROP COLUMN "heading";
  ALTER TABLE "payload"."articles" DROP COLUMN "source_u_r_l";
  ALTER TABLE "payload"."articles" DROP COLUMN "imported_at";
  ALTER TABLE "payload"."articles" DROP COLUMN "imported_by";
  ALTER TABLE "payload"."articles" DROP COLUMN "variant_generation_status";
  ALTER TABLE "payload"."articles" DROP COLUMN "variant_generation_source_hash";
  ALTER TABLE "payload"."articles" DROP COLUMN "variant_generation_model";
  ALTER TABLE "payload"."articles" DROP COLUMN "variant_generation_workflow_run_i_d";
  ALTER TABLE "payload"."articles" DROP COLUMN "variant_generation_generated_at";
  ALTER TABLE "payload"."articles" DROP COLUMN "variant_generation_last_error";
  ALTER TABLE "payload"."_articles_v_blocks_rich_text" DROP COLUMN "heading";
  ALTER TABLE "payload"."_articles_v" DROP COLUMN "version_source_u_r_l";
  ALTER TABLE "payload"."_articles_v" DROP COLUMN "version_imported_at";
  ALTER TABLE "payload"."_articles_v" DROP COLUMN "version_imported_by";
  ALTER TABLE "payload"."_articles_v" DROP COLUMN "version_variant_generation_status";
  ALTER TABLE "payload"."_articles_v" DROP COLUMN "version_variant_generation_source_hash";
  ALTER TABLE "payload"."_articles_v" DROP COLUMN "version_variant_generation_model";
  ALTER TABLE "payload"."_articles_v" DROP COLUMN "version_variant_generation_workflow_run_i_d";
  ALTER TABLE "payload"."_articles_v" DROP COLUMN "version_variant_generation_generated_at";
  ALTER TABLE "payload"."_articles_v" DROP COLUMN "version_variant_generation_last_error";
  DROP TYPE "payload"."enum_articles_variant_generation_status";
  DROP TYPE "payload"."enum__articles_v_version_variant_generation_status";`)
}
