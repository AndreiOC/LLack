-- Migration 002: Add usage_snapshots table
-- For existing databases upgrading from version 1

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

CREATE INDEX IF NOT EXISTS idx_usage_snapshots_period ON usage_snapshots(provider_id, period_type, period_start);
CREATE INDEX IF NOT EXISTS idx_usage_snapshots_conversation ON usage_snapshots(conversation_id, created_at);
