import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';

/// Database configuration and initialization
class DatabaseConfig {
  static const String databaseName = 'foss_chat.db';
  static const int databaseVersion = 1;

  /// Initialize the database factory for desktop platforms
  static void initialize() {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
  }

  /// Get the database path
  static Future<String> getDatabasePath() async {
    final directory = await getApplicationDocumentsDirectory();
    return join(directory.path, databaseName);
  }

  /// Database configuration options
  static DatabaseOptions get options => DatabaseOptions(
        version: databaseVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );

  /// Called when database is created for the first time
  static Future<void> _onCreate(Database db, int version) async {
    // Execute initial schema migration
    await _executeMigration(db, '001_initial_schema.sql');
  }

  /// Called when database needs to be upgraded
  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Future migrations will be executed here
    for (int i = oldVersion + 1; i <= newVersion; i++) {
      final migrationFile = '${i.toString().padLeft(3, '0')}_migration.sql';
      await _executeMigration(db, migrationFile);
    }
  }

  /// Execute a SQL migration file
  static Future<void> _executeMigration(Database db, String fileName) async {
    // In production, this would load from assets
    // For now, we'll embed the schema directly
    if (fileName == '001_initial_schema.sql') {
      await _executeInitialSchema(db);
    }
  }

  /// Execute the initial schema
  static Future<void> _executeInitialSchema(Database db) async {
    // App Settings Table
    await db.execute('''
      CREATE TABLE app_settings (
        key TEXT PRIMARY KEY NOT NULL,
        value_json TEXT NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Providers Table
    await db.execute('''
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
      )
    ''');

    // Provider Models Table
    await db.execute('''
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
      )
    ''');

    // Conversations Table
    await db.execute('''
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
      )
    ''');

    // Messages Table
    await db.execute('''
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
      )
    ''');

    // Outbox Jobs Table
    await db.execute('''
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
      )
    ''');

    // Indexes
    await db.execute('CREATE INDEX idx_conversations_updated_at ON conversations(updated_at DESC)');
    await db.execute('CREATE INDEX idx_conversations_deleted_at ON conversations(deleted_at)');
    await db.execute('CREATE INDEX idx_messages_conversation_id_sequence_no ON messages(conversation_id, sequence_no)');
    await db.execute('CREATE INDEX idx_messages_generation_group_id ON messages(generation_group_id)');
    await db.execute('CREATE INDEX idx_messages_created_at ON messages(created_at)');
    await db.execute('CREATE INDEX idx_outbox_jobs_status_next_retry_at ON outbox_jobs(status, next_retry_at)');
    await db.execute('CREATE INDEX idx_provider_models_provider_id_last_used_at ON provider_models(provider_id, last_used_at)');

    // Initial app settings
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.insert('app_settings', {'key': 'has_completed_onboarding', 'value_json': 'false', 'updated_at': now});
    await db.insert('app_settings', {'key': 'skip_cloud_providers', 'value_json': 'false', 'updated_at': now});
    await db.insert('app_settings', {'key': 'monthly_spend_threshold', 'value_json': 'null', 'updated_at': now});
    await db.insert('app_settings', {'key': 'show_code_line_numbers', 'value_json': 'false', 'updated_at': now});
    await db.insert('app_settings', {'key': 'last_successful_ollama_endpoint', 'value_json': 'null', 'updated_at': now});
  }
}
