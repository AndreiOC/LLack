-- Migration 001: Initial Schema
-- Creates all tables for FOSS Chat Release 1

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
    status TEXT NOT NULL CHECK (status IN ('draft', 'queued', 'sending', 'streaming', 'completed', 'failed', 'cancelled')),
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

-- Indexes for performance
CREATE INDEX idx_conversations_updated_at ON conversations(updated_at DESC);
CREATE INDEX idx_conversations_deleted_at ON conversations(deleted_at);
CREATE INDEX idx_conversations_pinned_at ON conversations(pinned_at DESC);
CREATE INDEX idx_messages_conversation_id_sequence_no ON messages(conversation_id, sequence_no);
CREATE INDEX idx_messages_generation_group_id ON messages(generation_group_id);
CREATE INDEX idx_messages_created_at ON messages(created_at);
CREATE INDEX idx_outbox_jobs_status_next_retry_at ON outbox_jobs(status, next_retry_at);
CREATE INDEX idx_provider_models_provider_id_last_used_at ON provider_models(provider_id, last_used_at);

-- Initial app settings
INSERT INTO app_settings (key, value_json, updated_at) VALUES
    ('has_completed_onboarding', 'false', strftime('%s', 'now') * 1000),
    ('skip_cloud_providers', 'false', strftime('%s', 'now') * 1000),
    ('monthly_spend_threshold', 'null', strftime('%s', 'now') * 1000),
    ('show_code_line_numbers', 'false', strftime('%s', 'now') * 1000),
    ('last_successful_ollama_endpoint', 'null', strftime('%s', 'now') * 1000);
