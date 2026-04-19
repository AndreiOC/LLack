import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import '../data/db/database_config.dart';

/// Provider for the database instance
final databaseProvider = FutureProvider<Database>((ref) async {
  DatabaseConfig.initialize();
  final path = await DatabaseConfig.getDatabasePath();
  return await openDatabase(
    path,
    version: DatabaseConfig.databaseVersion,
    onCreate: DatabaseConfig.options.onCreate,
    onUpgrade: DatabaseConfig.options.onUpgrade,
  );
});
