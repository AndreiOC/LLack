import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_chat/app/providers/chat_state_provider.dart';
import 'package:foss_chat/app/providers/conversation_list_provider.dart';
import 'package:foss_chat/app/providers/provider_management_provider.dart';
import 'package:foss_chat/app/providers/repository_providers.dart';
import 'package:foss_chat/app/providers/usage_provider.dart';
import 'package:foss_chat/data/db/dao/app_setting_dao.dart';
import 'package:foss_chat/data/db/dao/provider_model_dao.dart';
import 'package:foss_chat/data/db/database_config.dart';
import 'package:foss_chat/data/repositories/provider_model_repository.dart';
import 'package:foss_chat/data/services/usage_service.dart';
import 'package:foss_chat/domain/entities/entities.dart';
import 'package:foss_chat/features/chat/chat_workspace.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late Database database;
  late ProviderModelRepository modelRepository;
  late AppSettingDao appSettingDao;

  setUp(() async {
    database = await openDatabase(
      inMemoryDatabasePath,
      version: DatabaseConfig.databaseVersion,
      onCreate: DatabaseConfig.onCreate,
    );
    modelRepository = ProviderModelRepository(ProviderModelDao(database));
    appSettingDao = AppSettingDao(database);
    await appSettingDao.setBool(AppSettingKeys.showCodeLineNumbers, false);
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('composer send button enables when the user types', (
    tester,
  ) async {
    final provider = _buildProvider(
      id: 'provider-local',
      displayName: 'Local Ollama',
    );
    await _pumpChatWorkspace(
      tester,
      providers: <Provider>[provider],
      chatState: ChatState.initial(selectedProvider: provider),
      listPages: <List<Conversation>>[
        <Conversation>[_buildConversation(id: 'conv-1', title: 'First thread')],
      ],
      modelRepository: modelRepository,
      appSettingDao: appSettingDao,
    );

    final sendFinder = find.widgetWithText(FilledButton, 'Send');
    expect(sendFinder, findsOneWidget);
    expect(tester.widget<FilledButton>(sendFinder).onPressed, isNull);

    await tester.enterText(
      find.widgetWithText(TextField, 'Write a prompt...'),
      'Draft a reply',
    );
    await tester.pump();

    expect(tester.widget<FilledButton>(sendFinder).onPressed, isNotNull);
  });

  testWidgets('scrolling near the rail bottom triggers load more', (
    tester,
  ) async {
    final provider = _buildProvider(
      id: 'provider-local',
      displayName: 'Local Ollama',
    );
    final firstPage = List<Conversation>.generate(
      20,
      (index) => _buildConversation(
        id: 'conv-$index',
        title: 'Conversation ${index + 1}',
      ),
    );
    final secondPage = List<Conversation>.generate(
      5,
      (index) => _buildConversation(
        id: 'conv-more-$index',
        title: 'Conversation ${index + 21}',
      ),
    );

    await _pumpChatWorkspace(
      tester,
      providers: <Provider>[provider],
      chatState: ChatState.initial(selectedProvider: provider),
      listPages: <List<Conversation>>[firstPage, secondPage],
      modelRepository: modelRepository,
      appSettingDao: appSettingDao,
    );

    expect(find.text('Conversation 25'), findsNothing);

    await tester.drag(find.byType(ListView).first, const Offset(0, -2400));
    await tester.pump();
    await tester.pump();

    expect(find.text('Conversation 25'), findsOneWidget);
  });

  testWidgets('search waits for the debounce before applying results', (
    tester,
  ) async {
    final provider = _buildProvider(
      id: 'provider-local',
      displayName: 'Local Ollama',
    );
    final firstPage = List<Conversation>.generate(
      20,
      (index) => _buildConversation(
        id: 'conv-$index',
        title: 'Conversation ${index + 1}',
      ),
    );
    final secondPage = <Conversation>[
      _buildConversation(id: 'conv-special', title: 'Conversation 25'),
    ];

    await _pumpChatWorkspace(
      tester,
      providers: <Provider>[provider],
      chatState: ChatState.initial(selectedProvider: provider),
      listPages: <List<Conversation>>[firstPage, secondPage],
      modelRepository: modelRepository,
      appSettingDao: appSettingDao,
    );

    await tester.enterText(
      find.widgetWithText(TextField, 'Search conversations...'),
      'Conversation 25',
    );
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('Conversation 25'), findsNothing);

    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('Conversation 25'), findsOneWidget);
  });
}

Future<void> _pumpChatWorkspace(
  WidgetTester tester, {
  required List<Provider> providers,
  required ChatState chatState,
  required List<List<Conversation>> listPages,
  required ProviderModelRepository modelRepository,
  required AppSettingDao appSettingDao,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        chatStateProvider.overrideWith(
          () => _FakeChatStateNotifier(chatState),
        ),
        conversationListProvider.overrideWith(
          () => _FakeConversationListNotifier(listPages),
        ),
        providerManagementProvider.overrideWith(
          () => _FakeProviderManagementNotifier(providers),
        ),
        providerModelRepositoryProvider.overrideWith(
          (ref) async => modelRepository,
        ),
        appSettingDaoProvider.overrideWith((ref) async => appSettingDao),
        usageOverviewProvider.overrideWith(
          (ref) async => const UsageOverview(
            daily: UsageMetric(),
            weekly: UsageMetric(),
            monthly: UsageMetric(),
            monthlyLocal: UsageMetric(),
            monthlyCloud: UsageMetric(),
            providerBreakdown: <ProviderUsageMetric>[],
            monthlyThresholdMicros: null,
            thresholdState: UsageThresholdState.none,
            shouldShowThresholdBanner: false,
          ),
        ),
      ],
      child: const MaterialApp(home: ChatWorkspace()),
    ),
  );
  await tester.pumpAndSettle();
}

Provider _buildProvider({
  required String id,
  required String displayName,
}) {
  final now = DateTime(2026, 5, 1, 10);
  return Provider(
    id: id,
    kind: ProviderKind.ollama,
    displayName: displayName,
    baseUrl: 'http://localhost:11434',
    defaultModelId: 'llama3',
    healthStatus: ProviderHealthStatus.healthy,
    createdAt: now,
    updatedAt: now,
  );
}

Conversation _buildConversation({
  required String id,
  required String title,
}) {
  final now = DateTime(2026, 5, 1, 10);
  return Conversation(
    id: id,
    title: title,
    createdAt: now,
    updatedAt: now,
  );
}

class _FakeChatStateNotifier extends ChatStateNotifier {
  _FakeChatStateNotifier(this._initialState);

  final ChatState _initialState;

  @override
  Future<ChatState> build() async => _initialState;
}

class _FakeConversationListNotifier extends ConversationListNotifier {
  _FakeConversationListNotifier(this._pages);

  final List<List<Conversation>> _pages;
  int _currentPage = 0;

  List<Conversation> get _allConversations =>
      _pages.expand((page) => page).toList(growable: false);

  @override
  Future<ConversationListState> build() async {
    return ConversationListState(
      conversations: _pages.first,
      hasMore: _pages.length > 1,
    );
  }

  @override
  Future<void> refresh() async {
    _currentPage = 0;
    state = AsyncData(
      ConversationListState(
        conversations: _pages.first,
        hasMore: _pages.length > 1,
      ),
    );
  }

  @override
  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) {
      return;
    }
    state = AsyncData(current.copyWith(isLoadingMore: true));
    await Future<void>.delayed(Duration.zero);

    _currentPage += 1;
    final nextPage = _pages[_currentPage];
    state = AsyncData(
      ConversationListState(
        conversations: <Conversation>[
          ...current.conversations,
          ...nextPage,
        ],
        hasMore: _currentPage < _pages.length - 1,
      ),
    );
  }

  @override
  Future<void> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      await refresh();
      return;
    }

    final matches = _allConversations
        .where(
          (conversation) => conversation.title.toLowerCase().contains(
                trimmed.toLowerCase(),
              ),
        )
        .toList(growable: false);
    state = AsyncData(
      ConversationListState(
        conversations: matches,
        snippetsByConversationId: <String, String>{
          for (final conversation in matches)
            conversation.id: 'Search result for <mark>$trimmed</mark>',
        },
        searchQuery: trimmed,
        hasMore: false,
      ),
    );
  }

  @override
  Future<List<Conversation>> getArchived() async => const <Conversation>[];
}

class _FakeProviderManagementNotifier extends ProviderManagementNotifier {
  _FakeProviderManagementNotifier(this._providers);

  final List<Provider> _providers;

  @override
  Future<List<Provider>> build() async => _providers;
}
