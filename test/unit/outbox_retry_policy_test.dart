import 'package:flutter_test/flutter_test.dart';
import 'package:foss_chat/data/db/dao/conversation_dao.dart';
import 'package:foss_chat/data/db/dao/message_dao.dart';
import 'package:foss_chat/data/db/dao/outbox_job_dao.dart';
import 'package:foss_chat/data/db/dao/provider_dao.dart';
import 'package:foss_chat/data/db/database_config.dart';
import 'package:foss_chat/domain/entities/entities.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database database;
  late OutboxJobDao outboxJobDao;

  setUp(() async {
    database = await openDatabase(
      inMemoryDatabasePath,
      version: DatabaseConfig.databaseVersion,
      onCreate: DatabaseConfig.onCreate,
    );
    outboxJobDao = OutboxJobDao(database);

    final provider = Provider(
      id: 'provider-1',
      kind: ProviderKind.openaiCompatible,
      displayName: 'Remote Provider',
      baseUrl: 'https://api.example.com',
      createdAt: DateTime(2026, 5, 1, 10),
      updatedAt: DateTime(2026, 5, 1, 10),
    );
    await ProviderDao(database).insert(provider);

    final conversation = Conversation(
      id: 'conversation-1',
      title: 'Queued thread',
      selectedProviderId: provider.id,
      selectedModelId: 'test-model',
      createdAt: DateTime(2026, 5, 1, 10),
      updatedAt: DateTime(2026, 5, 1, 10),
    );
    await ConversationDao(database).insert(conversation);

    await MessageDao(database).insert(
      Message.assistantPlaceholder(
        id: 'message-1',
        conversationId: conversation.id,
        sequenceNo: 1,
        providerId: provider.id,
        modelId: 'test-model',
      ),
    );

    await outboxJobDao.insert(
      OutboxJob.create(
        id: 'job-1',
        conversationId: conversation.id,
        messageId: 'message-1',
        providerId: provider.id,
        payload: const <String, dynamic>{'content': 'Retry me'},
      ),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('markForRetry applies exponential backoff', () async {
    final before = DateTime.now();

    await outboxJobDao.markForRetry('job-1', 3, 'temporary failure');
    final updated = await outboxJobDao.getById('job-1');

    expect(updated?.status, OutboxJobStatus.retryWait);
    expect(updated?.retryCount, 3);
    expect(updated?.lastError, 'temporary failure');

    final delay = updated!.nextRetryAt!.difference(before);
    expect(delay.inSeconds, inInclusiveRange(8, 12));
  });

  test('markForRetry caps the delay at five minutes', () async {
    final before = DateTime.now();

    await outboxJobDao.markForRetry('job-1', 9, 'still failing');
    final updated = await outboxJobDao.getById('job-1');

    final delay = updated!.nextRetryAt!.difference(before);
    expect(delay.inSeconds, inInclusiveRange(299, 300));
  });
}
