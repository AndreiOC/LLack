-- Migration 004: Add FTS5 full-text search for conversations and messages
-- FTS5 is available in SQLite 3.9.0+ (included in all supported platforms)

-- FTS5 virtual table for conversations (title search)
CREATE VIRTUAL TABLE IF NOT EXISTS conversations_fts USING fts5(
  title,
  content='conversations',
  content_rowid='rowid'
);

-- FTS5 virtual table for messages (content search)
CREATE VIRTUAL TABLE IF NOT EXISTS messages_fts USING fts5(
  content_markdown,
  content='messages',
  content_rowid='rowid'
);

-- Triggers to keep conversations_fts in sync
CREATE TRIGGER IF NOT EXISTS trg_conversations_fts_insert
AFTER INSERT ON conversations
BEGIN
  INSERT INTO conversations_fts (rowid, title)
  VALUES (new.rowid, new.title);
END;

CREATE TRIGGER IF NOT EXISTS trg_conversations_fts_delete
AFTER DELETE ON conversations
BEGIN
  INSERT INTO conversations_fts (conversations_fts, rowid, title)
  VALUES ('delete', old.rowid, old.title);
END;

CREATE TRIGGER IF NOT EXISTS trg_conversations_fts_update
AFTER UPDATE OF title ON conversations
BEGIN
  INSERT INTO conversations_fts (conversations_fts, rowid, title)
  VALUES ('delete', old.rowid, old.title);
  INSERT INTO conversations_fts (rowid, title)
  VALUES (new.rowid, new.title);
END;

-- Triggers to keep messages_fts in sync
CREATE TRIGGER IF NOT EXISTS trg_messages_fts_insert
AFTER INSERT ON messages
BEGIN
  INSERT INTO messages_fts (rowid, content_markdown)
  VALUES (new.rowid, new.content_markdown);
END;

CREATE TRIGGER IF NOT EXISTS trg_messages_fts_delete
AFTER DELETE ON messages
BEGIN
  INSERT INTO messages_fts (messages_fts, rowid, content_markdown)
  VALUES ('delete', old.rowid, old.content_markdown);
END;

CREATE TRIGGER IF NOT EXISTS trg_messages_fts_update
AFTER UPDATE OF content_markdown ON messages
BEGIN
  INSERT INTO messages_fts (messages_fts, rowid, content_markdown)
  VALUES ('delete', old.rowid, old.content_markdown);
  INSERT INTO messages_fts (rowid, content_markdown)
  VALUES (new.rowid, new.content_markdown);
END;

-- Populate FTS tables with existing data
INSERT INTO conversations_fts (rowid, title)
SELECT rowid, title FROM conversations WHERE deleted_at IS NULL;

INSERT INTO messages_fts (rowid, content_markdown)
SELECT rowid, content_markdown FROM messages;
