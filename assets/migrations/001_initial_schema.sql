-- Unified schema for FOSS Chat.
-- This file is the single source of truth for fresh installs and pre-release
-- schema resets. Do not add incremental migration files without updating
-- DatabaseConfig accordingly.

-- App Settings Table
CREATE TABLE app_settings (
  key TEXT PRIMARY KEY NOT NULL,
  value_json TEXT NOT NULL,
  updated_at INTEGER NOT NULL
);

-- Providers Table
CREATE TABLE providers (
  id TEXT PRIMARY KEY NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('ollama', 'openai_compatible')),
  display_name TEXT NOT NULL,
  base_url TEXT NOT NULL,
  api_key_ref TEXT,
  default_model_id TEXT,
  headers_json TEXT,
  settings_json TEXT,
  health_status TEXT CHECK (health_status IN ('healthy', 'degraded', 'unreachable', 'never_checked')),
  health_checked_at INTEGER,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  deleted_at INTEGER
);

-- Provider Models Table
CREATE TABLE provider_models (
  id TEXT PRIMARY KEY NOT NULL,
  provider_id TEXT NOT NULL REFERENCES providers(id) ON DELETE CASCADE,
  remote_model_id TEXT NOT NULL,
  display_name TEXT NOT NULL,
  context_window INTEGER,
  supports_streaming INTEGER NOT NULL DEFAULT 1,
  supports_tools INTEGER NOT NULL DEFAULT 0,
  last_used_at INTEGER,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

-- Conversations Table
CREATE TABLE conversations (
  id TEXT PRIMARY KEY NOT NULL,
  title TEXT NOT NULL,
  selected_provider_id TEXT REFERENCES providers(id),
  selected_model_id TEXT,
  pinned_at INTEGER,
  archived_at INTEGER,
  deleted_at INTEGER,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

-- Messages Table
CREATE TABLE messages (
  id TEXT PRIMARY KEY NOT NULL,
  conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  role TEXT NOT NULL CHECK (role IN ('system', 'user', 'assistant')),
  content_markdown TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('draft', 'queued', 'sending', 'streaming', 'completed', 'failed', 'cancelled', 'superseded')),
  provider_id TEXT REFERENCES providers(id),
  model_id TEXT,
  sequence_no INTEGER NOT NULL,
  edited_from_message_id TEXT REFERENCES messages(id),
  generation_group_id TEXT,
  input_tokens INTEGER,
  output_tokens INTEGER,
  estimated_cost_micros INTEGER,
  error_code TEXT,
  error_message TEXT,
  response_metadata_json TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

-- FTS5 virtual tables
CREATE VIRTUAL TABLE conversations_fts USING fts5(
  title,
  content='conversations',
  content_rowid='rowid'
);

CREATE VIRTUAL TABLE messages_fts USING fts5(
  content_markdown,
  content='messages',
  content_rowid='rowid'
);

-- Outbox Jobs Table
CREATE TABLE outbox_jobs (
  id TEXT PRIMARY KEY NOT NULL,
  conversation_id TEXT NOT NULL REFERENCES conversations(id) ON DELETE CASCADE,
  message_id TEXT NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  provider_id TEXT NOT NULL REFERENCES providers(id),
  payload_json TEXT NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('pending', 'processing', 'retry_wait', 'failed', 'completed', 'cancelled')),
  retry_count INTEGER NOT NULL DEFAULT 0,
  next_retry_at INTEGER,
  last_error TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

-- Indexes
CREATE INDEX idx_conversations_updated_at ON conversations(updated_at DESC);
CREATE INDEX idx_conversations_deleted_at ON conversations(deleted_at);
CREATE INDEX idx_conversations_pinned_at ON conversations(pinned_at DESC);
CREATE INDEX idx_messages_conversation_id_sequence_no ON messages(conversation_id, sequence_no);
CREATE INDEX idx_messages_generation_group_id ON messages(generation_group_id);
CREATE INDEX idx_messages_created_at ON messages(created_at);
CREATE INDEX idx_outbox_jobs_status_next_retry_at ON outbox_jobs(status, next_retry_at);
CREATE INDEX idx_provider_models_provider_id_last_used_at ON provider_models(provider_id, last_used_at);

-- Usage Snapshots Table (spec §5.1, §9.6)
CREATE TABLE IF NOT EXISTS usage_snapshots (
  id TEXT PRIMARY KEY NOT NULL,
  conversation_id TEXT,
  message_id TEXT,
  provider_id TEXT,
  model_id TEXT,
  period_start INTEGER NOT NULL,
  period_end INTEGER NOT NULL,
  period_type TEXT NOT NULL CHECK (period_type IN ('daily', 'weekly', 'monthly')),
  input_tokens INTEGER NOT NULL DEFAULT 0,
  output_tokens INTEGER NOT NULL DEFAULT 0,
  estimated_cost_micros INTEGER NOT NULL DEFAULT 0,
  is_local INTEGER NOT NULL DEFAULT 0 CHECK (is_local IN (0, 1)),
  created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now') * 1000)
);

-- Usage snapshot indexes
CREATE INDEX idx_usage_snapshots_period ON usage_snapshots(provider_id, period_type, period_start);
CREATE INDEX idx_usage_snapshots_conversation ON usage_snapshots(conversation_id, created_at);

-- Auto-update updated_at trigger for messages (safety net — DAOs also set it explicitly)
CREATE TRIGGER trg_messages_updated_at
AFTER UPDATE ON messages
FOR EACH ROW
WHEN NEW.updated_at = OLD.updated_at
BEGIN
  UPDATE messages SET updated_at = CAST(strftime('%s', 'now') AS INTEGER) * 1000 WHERE id = NEW.id;
END;

-- FTS5 sync triggers for conversations
CREATE TRIGGER trg_conversations_fts_insert
AFTER INSERT ON conversations
BEGIN
  INSERT INTO conversations_fts (rowid, title)
  VALUES (new.rowid, new.title);
END;

CREATE TRIGGER trg_conversations_fts_delete
AFTER DELETE ON conversations
BEGIN
  INSERT INTO conversations_fts (conversations_fts, rowid, title)
  VALUES ('delete', old.rowid, old.title);
END;

CREATE TRIGGER trg_conversations_fts_update
AFTER UPDATE OF title ON conversations
BEGIN
  INSERT INTO conversations_fts (conversations_fts, rowid, title)
  VALUES ('delete', old.rowid, old.title);
  INSERT INTO conversations_fts (rowid, title)
  VALUES (new.rowid, new.title);
END;

-- FTS5 sync triggers for messages
CREATE TRIGGER trg_messages_fts_insert
AFTER INSERT ON messages
BEGIN
  INSERT INTO messages_fts (rowid, content_markdown)
  VALUES (new.rowid, new.content_markdown);
END;

CREATE TRIGGER trg_messages_fts_delete
AFTER DELETE ON messages
BEGIN
  INSERT INTO messages_fts (messages_fts, rowid, content_markdown)
  VALUES ('delete', old.rowid, old.content_markdown);
END;

CREATE TRIGGER trg_messages_fts_update
AFTER UPDATE OF content_markdown ON messages
BEGIN
  INSERT INTO messages_fts (messages_fts, rowid, content_markdown)
  VALUES ('delete', old.rowid, old.content_markdown);
  INSERT INTO messages_fts (rowid, content_markdown)
  VALUES (new.rowid, new.content_markdown);
END;

-- Initial app settings
INSERT INTO app_settings (key, value_json, updated_at) VALUES
  ('has_completed_onboarding', 'false', strftime('%s', 'now') * 1000),
  ('skip_cloud_providers', 'false', strftime('%s', 'now') * 1000),
  ('monthly_spend_threshold', 'null', strftime('%s', 'now') * 1000),
  ('show_code_line_numbers', 'false', strftime('%s', 'now') * 1000),
  ('last_successful_ollama_endpoint', 'null', strftime('%s', 'now') * 1000);

-- Initial FTS population (no-op on fresh databases, useful after dev resets)
INSERT INTO conversations_fts (rowid, title)
SELECT rowid, title FROM conversations WHERE deleted_at IS NULL;

INSERT INTO messages_fts (rowid, content_markdown)
SELECT rowid, content_markdown FROM messages;
