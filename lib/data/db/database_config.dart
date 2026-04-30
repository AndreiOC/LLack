import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Database configuration and initialization
class DatabaseConfig {
  static const String databaseName = 'foss_chat.db';
  static const int databaseVersion = 6;
  static const String _schemaAssetPath =
      'assets/migrations/001_initial_schema.sql';
  static const List<String> _dropStatements = <String>[
    'DROP TABLE IF EXISTS conversations_fts',
    'DROP TABLE IF EXISTS messages_fts',
    'DROP TABLE IF EXISTS usage_snapshots',
    'DROP TABLE IF EXISTS outbox_jobs',
    'DROP TABLE IF EXISTS messages',
    'DROP TABLE IF EXISTS conversations',
    'DROP TABLE IF EXISTS provider_models',
    'DROP TABLE IF EXISTS providers',
    'DROP TABLE IF EXISTS app_settings',
  ];

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

  /// Database onCreate callback
  static Future<void> onCreate(Database db, int version) =>
      _onCreate(db, version);

  /// Database onUpgrade callback
  static Future<void> onUpgrade(Database db, int oldVersion, int newVersion) =>
      _onUpgrade(db, oldVersion, newVersion);

  /// Called when database is created for the first time
  static Future<void> _onCreate(Database db, int version) =>
      _applyUnifiedSchema(db);

  /// Called when database needs to be upgraded
  static Future<void> _onUpgrade(
    Database db,
    int _oldVersion,
    int _newVersion,
  ) async {
    // Pre-release simplification: old local schemas are disposable, so recreate
    // the database from the single canonical schema instead of maintaining a
    // migration chain.
    await _recreateDatabase(db);
  }

  static Future<void> _applyUnifiedSchema(Database db) async {
    final sql = await rootBundle.loadString(_schemaAssetPath);
    final statements = _splitSqlStatements(sql);
    for (final statement in statements) {
      await db.execute(statement);
    }
  }

  static Future<void> _recreateDatabase(Database db) async {
    await db.execute('PRAGMA foreign_keys = OFF');
    try {
      for (final statement in _dropStatements) {
        await db.execute(statement);
      }
      await _applyUnifiedSchema(db);
    } finally {
      await db.execute('PRAGMA foreign_keys = ON');
    }
  }

  static List<String> _splitSqlStatements(String sql) {
    final statements = <String>[];
    var buffer = StringBuffer();
    var inTrigger = false;

    for (final rawLine in sql.split('\n')) {
      final line = rawLine.trimRight();
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('--')) {
        continue;
      }

      if (buffer.length > 0) {
        buffer.writeln();
      }
      buffer.write(line);

      final upperTrimmed = trimmed.toUpperCase();
      if (!inTrigger && upperTrimmed.startsWith('CREATE TRIGGER')) {
        inTrigger = true;
      }

      final isEndOfStatement =
          inTrigger ? upperTrimmed == 'END;' : trimmed.endsWith(';');
      if (!isEndOfStatement) {
        continue;
      }

      statements.add(buffer.toString());
      buffer = StringBuffer();
      inTrigger = false;
    }

    if (buffer.length > 0) {
      statements.add(buffer.toString());
    }

    return statements;
  }
}
