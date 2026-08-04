CREATE TABLE IF NOT EXISTS "schema_migrations" ("version" varchar NOT NULL PRIMARY KEY);
CREATE TABLE IF NOT EXISTS "ar_internal_metadata" ("key" varchar NOT NULL PRIMARY KEY, "value" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE TABLE solid_queue_jobs (
  id INTEGER PRIMARY KEY,
  queue_name varchar NOT NULL,
  class_name varchar NOT NULL,
  arguments text,
  priority integer DEFAULT 0 NOT NULL,
  active_job_id varchar,
  scheduled_at datetime,
  finished_at datetime,
  concurrency_key varchar,
  created_at datetime NOT NULL,
  updated_at datetime NOT NULL
);
CREATE INDEX index_solid_queue_jobs_on_active_job_id ON solid_queue_jobs (active_job_id);
CREATE INDEX index_solid_queue_jobs_on_class_name ON solid_queue_jobs (class_name);
CREATE INDEX index_solid_queue_jobs_on_finished_at ON solid_queue_jobs (finished_at);
CREATE INDEX index_solid_queue_jobs_for_filtering ON solid_queue_jobs (queue_name, finished_at);
CREATE INDEX index_solid_queue_jobs_for_alerting ON solid_queue_jobs (scheduled_at, finished_at);
CREATE TABLE solid_queue_blocked_executions (
  job_id bigint NOT NULL,
  queue_name varchar NOT NULL,
  priority integer DEFAULT 0 NOT NULL,
  concurrency_key varchar NOT NULL,
  expires_at datetime NOT NULL,
  created_at datetime NOT NULL,
  FOREIGN KEY (job_id) REFERENCES solid_queue_jobs(id) ON DELETE CASCADE
);
CREATE INDEX index_solid_queue_blocked_executions_for_release ON solid_queue_blocked_executions (concurrency_key, priority, job_id);
CREATE INDEX index_solid_queue_blocked_executions_for_maintenance ON solid_queue_blocked_executions (expires_at, concurrency_key);
CREATE UNIQUE INDEX index_solid_queue_blocked_executions_on_job_id ON solid_queue_blocked_executions (job_id);
CREATE TABLE solid_queue_claimed_executions (
  job_id bigint NOT NULL,
  process_id bigint,
  created_at datetime NOT NULL,
  FOREIGN KEY (job_id) REFERENCES solid_queue_jobs(id) ON DELETE CASCADE
);
CREATE UNIQUE INDEX index_solid_queue_claimed_executions_on_job_id ON solid_queue_claimed_executions (job_id);
CREATE INDEX index_solid_queue_claimed_executions_on_process_id_and_job_id ON solid_queue_claimed_executions (process_id, job_id);
CREATE TABLE solid_queue_failed_executions (
  job_id bigint NOT NULL,
  error text,
  created_at datetime NOT NULL,
  FOREIGN KEY (job_id) REFERENCES solid_queue_jobs(id) ON DELETE CASCADE
);
CREATE UNIQUE INDEX index_solid_queue_failed_executions_on_job_id ON solid_queue_failed_executions (job_id);
CREATE TABLE solid_queue_pauses (
  queue_name varchar NOT NULL,
  created_at datetime NOT NULL
);
CREATE UNIQUE INDEX index_solid_queue_pauses_on_queue_name ON solid_queue_pauses (queue_name);
CREATE TABLE solid_queue_processes (
  id INTEGER PRIMARY KEY,
  kind varchar NOT NULL,
  last_heartbeat_at datetime NOT NULL,
  supervisor_id bigint,
  pid integer NOT NULL,
  hostname varchar,
  metadata text,
  created_at datetime NOT NULL,
  name varchar NOT NULL
);
CREATE INDEX index_solid_queue_processes_on_last_heartbeat_at ON solid_queue_processes (last_heartbeat_at);
CREATE UNIQUE INDEX index_solid_queue_processes_on_name_and_supervisor_id ON solid_queue_processes (name, supervisor_id);
CREATE INDEX index_solid_queue_processes_on_supervisor_id ON solid_queue_processes (supervisor_id);
CREATE TABLE solid_queue_ready_executions (
  job_id bigint NOT NULL,
  queue_name varchar NOT NULL,
  priority integer DEFAULT 0 NOT NULL,
  created_at datetime NOT NULL,
  FOREIGN KEY (job_id) REFERENCES solid_queue_jobs(id) ON DELETE CASCADE
);
CREATE UNIQUE INDEX index_solid_queue_ready_executions_on_job_id ON solid_queue_ready_executions (job_id);
CREATE INDEX index_solid_queue_poll_all ON solid_queue_ready_executions (priority, job_id);
CREATE INDEX index_solid_queue_poll_by_queue ON solid_queue_ready_executions (queue_name, priority, job_id);
CREATE TABLE solid_queue_recurring_executions (
  job_id bigint NOT NULL,
  task_key varchar NOT NULL,
  run_at datetime NOT NULL,
  created_at datetime NOT NULL,
  FOREIGN KEY (job_id) REFERENCES solid_queue_jobs(id) ON DELETE CASCADE
);
CREATE UNIQUE INDEX index_solid_queue_recurring_executions_on_job_id ON solid_queue_recurring_executions (job_id);
CREATE UNIQUE INDEX index_solid_queue_recurring_executions_on_task_key_and_run_at ON solid_queue_recurring_executions (task_key, run_at);
CREATE TABLE solid_queue_recurring_tasks (
  id INTEGER PRIMARY KEY,
  key varchar NOT NULL,
  schedule varchar NOT NULL,
  command varchar(2048),
  class_name varchar,
  arguments text,
  queue_name varchar,
  priority integer DEFAULT 0,
  static boolean DEFAULT 1 NOT NULL,
  description text,
  created_at datetime NOT NULL,
  updated_at datetime NOT NULL
);
CREATE UNIQUE INDEX index_solid_queue_recurring_tasks_on_key ON solid_queue_recurring_tasks (key);
CREATE INDEX index_solid_queue_recurring_tasks_on_static ON solid_queue_recurring_tasks (static);
CREATE TABLE solid_queue_scheduled_executions (
  job_id bigint NOT NULL,
  queue_name varchar NOT NULL,
  priority integer DEFAULT 0 NOT NULL,
  scheduled_at datetime NOT NULL,
  created_at datetime NOT NULL,
  FOREIGN KEY (job_id) REFERENCES solid_queue_jobs(id) ON DELETE CASCADE
);
CREATE UNIQUE INDEX index_solid_queue_scheduled_executions_on_job_id ON solid_queue_scheduled_executions (job_id);
CREATE INDEX index_solid_queue_dispatch_all ON solid_queue_scheduled_executions (scheduled_at, priority, job_id);
CREATE TABLE solid_queue_semaphores (
  id INTEGER PRIMARY KEY,
  key varchar NOT NULL,
  value integer DEFAULT 1 NOT NULL,
  expires_at datetime NOT NULL,
  created_at datetime NOT NULL,
  updated_at datetime NOT NULL
);
CREATE INDEX index_solid_queue_semaphores_on_expires_at ON solid_queue_semaphores (expires_at);
CREATE INDEX index_solid_queue_semaphores_on_key_and_value ON solid_queue_semaphores (key, value);
CREATE UNIQUE INDEX index_solid_queue_semaphores_on_key ON solid_queue_semaphores (key);
CREATE TABLE IF NOT EXISTS "favorites" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "url" varchar NOT NULL, "title" varchar, "favicon_url" varchar, "thumbnail_url" varchar, "content_type" varchar DEFAULT 'webpage' NOT NULL, "status" varchar DEFAULT 'pending' NOT NULL, "raw_content" text, "error_message" text, "retry_count" integer DEFAULT 0 NOT NULL, "note" text, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "category" varchar DEFAULT '기타' /*application='UrlFavorites20'*/, "pinned" boolean DEFAULT FALSE /*application='UrlFavorites20'*/, "source_metadata" text /*application='UrlFavorites20'*/);
CREATE UNIQUE INDEX "index_favorites_on_url" ON "favorites" ("url") /*application='UrlFavorites20'*/;
CREATE TABLE IF NOT EXISTS "analyses" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "favorite_id" integer NOT NULL, "summary" text, "tags" text, "key_points" text, "sentiment" varchar, "transcript" text, "subtitle_source" varchar, "video_metadata" text, "model_used" varchar, "analyzed_at" datetime(6), "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, "raw_content" text /*application='UrlFavorites20'*/, "detail_content" text /*application='UrlFavorites20'*/, "transcript_segments" text /*application='UrlFavorites20'*/, "analysis_style" varchar DEFAULT 'execution_brief' NOT NULL /*application='UrlFavorites20'*/, "analysis_tier" varchar DEFAULT 'fast' NOT NULL /*application='UrlFavorites20'*/, CONSTRAINT "fk_rails_b11216332f"
FOREIGN KEY ("favorite_id")
  REFERENCES "favorites" ("id")
);
CREATE UNIQUE INDEX "index_analyses_on_favorite_id" ON "analyses" ("favorite_id") /*application='UrlFavorites20'*/;
CREATE TABLE IF NOT EXISTS "collections" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "name" varchar NOT NULL, "description" text, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_collections_on_name" ON "collections" ("name") /*application='UrlFavorites20'*/;
CREATE TABLE IF NOT EXISTS "collection_memberships" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "favorite_id" integer NOT NULL, "collection_id" integer NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_77b6a5a4cd"
FOREIGN KEY ("favorite_id")
  REFERENCES "favorites" ("id")
, CONSTRAINT "fk_rails_8a440d7672"
FOREIGN KEY ("collection_id")
  REFERENCES "collections" ("id")
);
CREATE INDEX "index_collection_memberships_on_favorite_id" ON "collection_memberships" ("favorite_id") /*application='UrlFavorites20'*/;
CREATE INDEX "index_collection_memberships_on_collection_id" ON "collection_memberships" ("collection_id") /*application='UrlFavorites20'*/;
CREATE UNIQUE INDEX "index_collection_memberships_on_favorite_id_and_collection_id" ON "collection_memberships" ("favorite_id", "collection_id") /*application='UrlFavorites20'*/;
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
CREATE INDEX "index_favorites_on_category" ON "favorites" ("category") /*application='UrlFavorites20'*/;
CREATE INDEX "index_favorites_on_pinned" ON "favorites" ("pinned") /*application='UrlFavorites20'*/;
CREATE UNIQUE INDEX "index_favorites_on_id" ON "favorites" ("id") /*application='UrlFavorites20'*/;
CREATE TABLE IF NOT EXISTS "users" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "email_address" varchar NOT NULL, "password_digest" varchar NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL);
CREATE UNIQUE INDEX "index_users_on_email_address" ON "users" ("email_address") /*application='UrlFavorites20'*/;
CREATE TABLE IF NOT EXISTS "sessions" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "user_id" integer NOT NULL, "token" varchar NOT NULL, "user_agent" varchar, "ip_address" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_758836b4f0"
FOREIGN KEY ("user_id")
  REFERENCES "users" ("id")
);
CREATE INDEX "index_sessions_on_user_id" ON "sessions" ("user_id") /*application='UrlFavorites20'*/;
CREATE UNIQUE INDEX "index_sessions_on_token" ON "sessions" ("token") /*application='UrlFavorites20'*/;
CREATE TABLE IF NOT EXISTS "analysis_sections" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "analysis_id" integer NOT NULL, "position" integer NOT NULL, "heading" varchar NOT NULL, "focus" text, "body" text, "backend_model" varchar, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_4a858decad"
FOREIGN KEY ("analysis_id")
  REFERENCES "analyses" ("id")
);
CREATE INDEX "index_analysis_sections_on_analysis_id" ON "analysis_sections" ("analysis_id") /*application='UrlFavorites20'*/;
CREATE UNIQUE INDEX "index_analysis_sections_on_analysis_id_and_position" ON "analysis_sections" ("analysis_id", "position") /*application='UrlFavorites20'*/;
CREATE TABLE IF NOT EXISTS "favorite_embeddings" ("id" integer PRIMARY KEY AUTOINCREMENT NOT NULL, "favorite_id" integer NOT NULL, "embedding" text NOT NULL, "model" varchar NOT NULL, "dimensions" integer NOT NULL, "created_at" datetime(6) NOT NULL, "updated_at" datetime(6) NOT NULL, CONSTRAINT "fk_rails_65f8f3e3d0"
FOREIGN KEY ("favorite_id")
  REFERENCES "favorites" ("id")
);
CREATE UNIQUE INDEX "index_favorite_embeddings_on_favorite_id" ON "favorite_embeddings" ("favorite_id") /*application='UrlFavorites20'*/;
INSERT INTO "schema_migrations" (version) VALUES
('20260804000001'),
('20260803000001'),
('20260730000001'),
('20260724000001'),
('20260509000001'),
('20260429000002'),
('20260429000001'),
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
('20260407000001'),
('0');

