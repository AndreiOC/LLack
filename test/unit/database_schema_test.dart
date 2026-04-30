import 'package:flutter_test/flutter_test.dart';
import 'package:foss_chat/data/db/database_config.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('unified schema creates FTS tables and estimated flags', () async {
    final database = await openDatabase(
      inMemoryDatabasePath,
      version: DatabaseConfig.databaseVersion,
      onCreate: DatabaseConfig.onCreate,
    );

    final messageColumns = await database.rawQuery('PRAGMA table_info(messages)');
    final usageColumns =
        await database.rawQuery('PRAGMA table_info(usage_snapshots)');
    final ftsTables = await database.rawQuery('''
      SELECT name
      FROM sqlite_master
      WHERE type = 'table'
        AND name IN ('conversations_fts', 'messages_fts')
    ''');

    expect(
      messageColumns.any((column) => column['name'] == 'is_estimated'),
      isTrue,
    );
    expect(
      usageColumns.any((column) => column['name'] == 'is_estimated'),
      isTrue,
    );
    expect(ftsTables.map((row) => row['name']), containsAll(<String>[
      'conversations_fts',
      'messages_fts',
    ]));

    await database.close();
  });
}
