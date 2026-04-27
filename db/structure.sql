CREATE TABLE IF NOT EXISTS "collections" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "created_at" datetime(6) NOT NULL, "description" text, "name" varchar NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_collections_on_name" ON "collections" ("name") /*application='UrlFavorites20'*/;
CREATE TABLE IF NOT EXISTS "favorites" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "content_type" varchar DEFAULT 'webpage' NOT NULL, "created_at" datetime(6) NOT NULL, "error_message" text, "favicon_url" varchar, "note" text, "raw_content" text, "retry_count" integer DEFAULT 0 NOT NULL, "status" varchar DEFAULT 'pending' NOT NULL, "thumbnail_url" varchar, "title" varchar, "updated_at" datetime(6) NOT NULL, "url" varchar NOT NULL, "category" varchar DEFAULT '기타' /*application='UrlFavorites20'*/, "pinned" boolean DEFAULT FALSE /*application='UrlFavorites20'*/);
CREATE UNIQUE INDEX "index_favorites_on_url" ON "favorites" ("url") /*application='UrlFavorites20'*/;
CREATE TABLE IF NOT EXISTS "collection_memberships" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "collection_id" integer NOT NULL, "created_at" datetime(6) NOT NULL, "favorite_id" integer NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_8a440d7672"
FOREIGN KEY ("collection_id")
  REFERENCES "collections" ("id")
, CONSTRAINT "fk_rails_77b6a5a4cd"
FOREIGN KEY ("favorite_id")
  REFERENCES "favorites" ("id")
);
CREATE INDEX "index_collection_memberships_on_collection_id" ON "collection_memberships" ("collection_id") /*application='UrlFavorites20'*/;
CREATE UNIQUE INDEX "index_collection_memberships_on_favorite_id_and_collection_id" ON "collection_memberships" ("favorite_id", "collection_id") /*application='UrlFavorites20'*/;
CREATE INDEX "index_collection_memberships_on_favorite_id" ON "collection_memberships" ("favorite_id") /*application='UrlFavorites20'*/;
CREATE TABLE IF NOT EXISTS "schema_migrations" ("version" varchar NOT NULL PRIMARY KEY);
CREATE TABLE IF NOT EXISTS "ar_internal_metadata" ("key" varchar NOT NULL PRIMARY KEY, "value" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE TABLE IF NOT EXISTS "tag_feedbacks" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "favorite_id" integer NOT NULL, "user_id" integer, "original_tags" text NOT NULL, "corrected_tags" text NOT NULL, "reason" varchar(500), "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_82d6c64491"
FOREIGN KEY ("favorite_id")
  REFERENCES "favorites" ("id")
);
CREATE INDEX "index_tag_feedbacks_on_favorite_id" ON "tag_feedbacks" ("favorite_id") /*application='UrlFavorites20'*/;
CREATE INDEX "index_tag_feedbacks_on_user_id" ON "tag_feedbacks" ("user_id") /*application='UrlFavorites20'*/;
CREATE VIRTUAL TABLE favorites_fts USING fts5(
  favorite_id UNINDEXED,
  title,
  summary,
  tags,
  note,
  content_embedding,
  tokenize='porter ascii'
)
/* favorites_fts(favorite_id,title,summary,tags,note,content_embedding) */;
CREATE TABLE IF NOT EXISTS "analyses" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "analyzed_at" datetime(6), "created_at" datetime(6) NOT NULL, "favorite_id" integer NOT NULL, "key_points" text, "model_used" varchar, "raw_content" text, "sentiment" varchar, "subtitle_source" varchar, "summary" text, "tags" text, "transcript" text, "updated_at" datetime(6) NOT NULL, "video_metadata" text, "detail_content" text /*application='UrlFavorites20'*/, CONSTRAINT "fk_rails_b11216332f"
FOREIGN KEY ("favorite_id")
  REFERENCES "favorites" ("id")
);
CREATE UNIQUE INDEX "index_analyses_on_favorite_id" ON "analyses" ("favorite_id") /*application='UrlFavorites20'*/;
CREATE INDEX "index_favorites_on_category" ON "favorites" ("category") /*application='UrlFavorites20'*/;
CREATE INDEX "index_favorites_on_pinned" ON "favorites" ("pinned") /*application='UrlFavorites20'*/;
CREATE UNIQUE INDEX "index_favorites_on_id" ON "favorites" ("id") /*application='UrlFavorites20'*/;
INSERT INTO "schema_migrations" (version) VALUES
('20260418000001'),
('20260414000001'),
('20260413000002'),
('20260413000001'),
('20260412141412'),
('20260407000006'),
('20260407000005'),
('20260407000004'),
('20260407000003'),
('20260407000002'),
('20260407000001');

