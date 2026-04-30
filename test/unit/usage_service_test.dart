import 'package:flutter_test/flutter_test.dart';
import 'package:foss_chat/data/db/dao/app_setting_dao.dart';
import 'package:foss_chat/data/db/dao/provider_dao.dart';
import 'package:foss_chat/data/db/dao/usage_snapshot_dao.dart';
import 'package:foss_chat/data/db/database_config.dart';
import 'package:foss_chat/data/repositories/provider_repository.dart';
import 'package:foss_chat/data/services/usage_service.dart';
import 'package:foss_chat/domain/entities/entities.dart';
import 'package:foss_chat/platform/secure_storage/secure_storage.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database database;
  late UsageService usageService;

  setUp(() async {
    database = await openDatabase(
      inMemoryDatabasePath,
      version: DatabaseConfig.databaseVersion,
      onCreate: DatabaseConfig.onCreate,
    );

    final providerDao = ProviderDao(database);
    final providerRepository = ProviderRepository(
      providerDao,
      SecureStorageService(),
    );
    usageService = UsageService(
      usageDao: UsageSnapshotDao(database),
      appSettingDao: AppSettingDao(database),
      providerRepository: providerRepository,
    );

    await providerDao.insert(
      Provider(
        id: 'provider-cloud',
        kind: ProviderKind.openaiCompatible,
        displayName: 'Cloud',
        baseUrl: 'https://api.example.com',
        createdAt: DateTime(2026, 5, 1, 10),
        updatedAt: DateTime(2026, 5, 1, 10),
      ),
    );
    await providerDao.insert(
      Provider(
        id: 'provider-local',
        kind: ProviderKind.ollama,
        displayName: 'Local',
        baseUrl: 'http://localhost:11434',
        createdAt: DateTime(2026, 5, 1, 10),
        updatedAt: DateTime(2026, 5, 1, 10),
      ),
    );
  });

  tearDown(() async {
    await database.close();
  });

  test('overview keeps estimated usage separate from actual totals', () async {
    final now = DateTime(2026, 5, 1, 9, 30);

    await usageService.recordMessageUsage(
      conversationId: 'conversation-1',
      messageId: 'message-1',
      provider: Provider(
        id: 'provider-cloud',
        kind: ProviderKind.openaiCompatible,
        displayName: 'Cloud',
        baseUrl: 'https://api.example.com',
        createdAt: now,
        updatedAt: now,
      ),
      modelId: 'model-a',
      inputTokens: 100,
      outputTokens: 40,
      estimatedCostMicros: 120,
      isEstimated: false,
      timestamp: now,
    );
    await usageService.recordMessageUsage(
      conversationId: 'conversation-1',
      messageId: 'message-2',
      provider: Provider(
        id: 'provider-cloud',
        kind: ProviderKind.openaiCompatible,
        displayName: 'Cloud',
        baseUrl: 'https://api.example.com',
        createdAt: now,
        updatedAt: now,
      ),
      modelId: 'model-a',
      inputTokens: 30,
      outputTokens: 12,
      estimatedCostMicros: 45,
      isEstimated: true,
      timestamp: now,
    );
    await usageService.recordMessageUsage(
      conversationId: 'conversation-2',
      messageId: 'message-3',
      provider: Provider(
        id: 'provider-local',
        kind: ProviderKind.ollama,
        displayName: 'Local',
        baseUrl: 'http://localhost:11434',
        createdAt: now,
        updatedAt: now,
      ),
      modelId: 'llama3',
      inputTokens: 20,
      outputTokens: 10,
      estimatedCostMicros: 0,
      isEstimated: false,
      timestamp: now,
    );

    final overview = await usageService.getOverview(now: now);
    final cloudBreakdown = overview.providerBreakdown.firstWhere(
      (provider) => provider.providerId == 'provider-cloud',
    );

    expect(overview.monthly.estimatedCostMicros, 165);
    expect(overview.monthly.estimatedCostMicrosPortion, 45);
    expect(overview.monthly.estimatedMessageCount, 1);
    expect(overview.monthlyCloud.estimatedCostMicrosPortion, 45);
    expect(cloudBreakdown.totals.estimatedMessageCount, 1);
    expect(cloudBreakdown.totals.actualCostMicros, 120);
  });
}
