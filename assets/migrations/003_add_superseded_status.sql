-- Migration 3: Add 'superseded' to message status enum and add superseded_by_message_id column
-- SQLite does not support ALTER TABLE DROP CONSTRAINT, so we recreate the messages table.

PRAGMA foreign_keys = OFF;

BEGIN TRANSACTION;

CREATE TABLE messages_new (
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

INSERT INTO messages_new SELECT * FROM messages;

DROP TABLE messages;
ALTER TABLE messages_new RENAME TO messages;

CREATE INDEX idx_messages_conversation_id_sequence_no ON messages(conversation_id, sequence_no);
CREATE INDEX idx_messages_generation_group_id ON messages(generation_group_id);
CREATE INDEX idx_messages_created_at ON messages(created_at);

COMMIT;

PRAGMA foreign_keys = ON;
