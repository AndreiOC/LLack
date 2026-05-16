import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:foss_chat/app/providers/chat_service_provider.dart';
import 'package:foss_chat/app/providers/chat_state_provider.dart';
import 'package:foss_chat/app/providers/conversation_list_provider.dart';
import 'package:foss_chat/app/providers/onboarding_provider.dart';
import 'package:foss_chat/app/providers/provider_management_provider.dart';
import 'package:foss_chat/app/providers/repository_providers.dart';
import 'package:foss_chat/data/db/dao/app_setting_dao.dart';
import 'package:foss_chat/data/db/dao/conversation_dao.dart';
import 'package:foss_chat/data/db/dao/message_dao.dart';
import 'package:foss_chat/data/db/dao/provider_dao.dart';
import 'package:foss_chat/data/db/database_config.dart';
import 'package:foss_chat/data/repositories/conversation_repository.dart';
import 'package:foss_chat/data/repositories/message_repository.dart';
import 'package:foss_chat/data/repositories/provider_repository.dart';
import 'package:foss_chat/data/services/chat_service.dart';
import 'package:foss_chat/domain/entities/entities.dart';
import 'package:foss_chat/domain/interfaces/chat_provider_adapter.dart';
import 'package:foss_chat/platform/secure_storage/secure_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database database;
  late AppSettingDao appSettingDao;
  late ProviderRepository providerRepository;
  late ConversationRepository conversationRepository;
  late ChatService chatService;

  setUp(() async {
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    database = await openDatabase(
      inMemoryDatabasePath,
      version: DatabaseConfig.databaseVersion,
      onCreate: DatabaseConfig.onCreate,
    );
    appSettingDao = AppSettingDao(database);
    providerRepository = ProviderRepository(
      ProviderDao(database),
      _MemorySecureStorageService(),
    );
    conversationRepository = ConversationRepository(ConversationDao(database));
    chatService = ChatService(
      providerRepo: providerRepository,
      conversationRepo: conversationRepository,
      messageRepo: MessageRepository(MessageDao(database)),
      testAdapterFactory: (_) => const _FakeChatProviderAdapter(),
    );
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets(
    'saving the first provider rebuilds invalidated notifiers without late init errors',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            appSettingDaoProvider.overrideWith((ref) async => appSettingDao),
            providerRepositoryProvider.overrideWith(
              (ref) async => providerRepository,
            ),
            conversationRepositoryProvider.overrideWith(
              (ref) async => conversationRepository,
            ),
            chatServiceProvider.overrideWith((ref) async => chatService),
            chatStateProvider.overrideWith(_TestChatStateNotifier.new),
          ],
          child: const MaterialApp(home: _ProviderLifecycleHarness()),
        ),
      );

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('providerCount:0'), findsOneWidget);
      expect(find.text('onboardingComplete:false'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Run lifecycle'));
      await tester.pump();
      expect(tester.takeException(), isNull);

      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(find.text('providerCount:1'), findsOneWidget);
      expect(find.text('onboardingProviders:1'), findsOneWidget);
      expect(find.text('onboardingComplete:true'), findsOneWidget);
      expect(find.text('conversationCount:0'), findsOneWidget);
      expect(find.textContaining('actionError:'), findsNothing);
    },
  );
}

class _ProviderLifecycleHarness extends ConsumerStatefulWidget {
  const _ProviderLifecycleHarness();

  @override
  ConsumerState<_ProviderLifecycleHarness> createState() =>
      _ProviderLifecycleHarnessState();
}

class _ProviderLifecycleHarnessState
    extends ConsumerState<_ProviderLifecycleHarness> {
  String? _actionError;
  bool _isRunning = false;

  Future<void> _runLifecycle() async {
    setState(() {
      _actionError = null;
      _isRunning = true;
    });

    try {
      final savedProvider = await ref
          .read(providerManagementProvider.notifier)
          .addProvider(_buildFirstProviderDraft());
      await ref
          .read(providerManagementProvider.notifier)
          .refreshProviderHealth(savedProvider.id, force: true);

      ref.invalidate(onboardingProvider);
      ref.invalidate(chatStateProvider);
      ref.invalidate(conversationListProvider);

      await ref.read(onboardingProvider.notifier).complete(
            localOnlyMode: true,
            lastOllamaEndpoint: savedProvider.baseUrl,
          );

      ref.invalidate(providerManagementProvider);
      ref.invalidate(chatStateProvider);
      ref.invalidate(conversationListProvider);
    } catch (error) {
      setState(() {
        _actionError = '$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isRunning = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final onboardingAsync = ref.watch(onboardingProvider);
    final providersAsync = ref.watch(providerManagementProvider);
    final conversationListAsync = ref.watch(conversationListProvider);
    final chatStateAsync = ref.watch(chatStateProvider);

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'providerCount:${providersAsync.valueOrNull?.length ?? -1}',
            ),
            Text(
              'onboardingProviders:${onboardingAsync.valueOrNull?.providerCount ?? -1}',
            ),
            Text(
              'onboardingComplete:${onboardingAsync.valueOrNull?.isComplete ?? false}',
            ),
            Text(
              'conversationCount:${conversationListAsync.valueOrNull?.conversations.length ?? -1}',
            ),
            Text('chatStateReady:${chatStateAsync.hasValue}'),
            if (_actionError != null) Text('actionError:$_actionError'),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _isRunning ? null : _runLifecycle,
              child: const Text('Run lifecycle'),
            ),
          ],
        ),
      ),
    );
  }
}

Provider _buildFirstProviderDraft() {
  final now = DateTime(2026, 5, 16, 12);
  return Provider(
    id: '',
    kind: ProviderKind.ollama,
    displayName: 'Local Ollama',
    baseUrl: 'http://127.0.0.1:11434',
    defaultModelId: 'llama3',
    createdAt: now,
    updatedAt: now,
  );
}

class _TestChatStateNotifier extends ChatStateNotifier {
  @override
  Future<ChatState> build() async => ChatState.initial();
}

class _MemorySecureStorageService extends SecureStorageService {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<String?> read(String key) async {
    return _values[key];
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}

class _FakeChatProviderAdapter implements ChatProviderAdapter {
  const _FakeChatProviderAdapter();

  @override
  Future<ChatCompletionResult> completeChat(
    ChatRequest request,
    String apiKey,
  ) async {
    return ChatCompletionResult(content: 'ok');
  }

  @override
  Future<List<ProviderModel>> fetchModels(Provider provider) async {
    return <ProviderModel>[
      ProviderModel.fromProviderResponse(
        id: 'model-1',
        providerId: provider.id,
        remoteModelId: 'llama3',
        displayName: 'llama3',
      ),
    ];
  }

  @override
  Future<ProviderHealthStatus> healthCheck(Provider provider) async {
    return ProviderHealthStatus.healthy;
  }

  @override
  Stream<ChatStreamEvent> streamChat(
    ChatRequest request,
    String apiKey, {
    CancelToken? cancelToken,
  }) async* {
    yield ChatStreamEvent.done();
  }

  @override
  Future<ProviderValidationResult> validateConfig(Provider provider) async {
    return ProviderValidationResult.success();
  }
}
