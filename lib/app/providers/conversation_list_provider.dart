import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/conversation_repository.dart';
import '../../domain/entities/entities.dart';
import 'repository_providers.dart';

final conversationListProvider = AutoDisposeAsyncNotifierProvider<
    ConversationListNotifier, ConversationListState>(
  ConversationListNotifier.new,
);

class ConversationListState {
  final List<Conversation> conversations;
  final Map<String, String> snippetsByConversationId;
  final String searchQuery;
  final bool hasMore;
  final bool isLoadingMore;

  const ConversationListState({
    required this.conversations,
    this.snippetsByConversationId = const <String, String>{},
    this.searchQuery = '',
    required this.hasMore,
    this.isLoadingMore = false,
  });

  bool get isSearching => searchQuery.isNotEmpty;

  ConversationListState copyWith({
    List<Conversation>? conversations,
    Map<String, String>? snippetsByConversationId,
    String? searchQuery,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return ConversationListState(
      conversations: conversations ?? this.conversations,
      snippetsByConversationId:
          snippetsByConversationId ?? this.snippetsByConversationId,
      searchQuery: searchQuery ?? this.searchQuery,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }
}

class ConversationListNotifier
    extends AutoDisposeAsyncNotifier<ConversationListState> {
  late final ConversationRepository _conversationRepo;
  static const int _pageSize = 20;

  @override
  Future<ConversationListState> build() async {
    _conversationRepo = await ref.watch(conversationRepositoryProvider.future);
    final conversations = await _conversationRepo.getPaginated(
      limit: _pageSize,
      offset: 0,
    );
    return ConversationListState(
      conversations: conversations,
      searchQuery: '',
      hasMore: conversations.length == _pageSize,
    );
  }

  Future<void> load() async {
    state = const AsyncLoading<ConversationListState>();
    final conversations = await _conversationRepo.getPaginated(
      limit: _pageSize,
      offset: 0,
    );
    state = AsyncData(ConversationListState(
      conversations: conversations,
      searchQuery: '',
      hasMore: conversations.length == _pageSize,
    ));
  }

  Future<void> refresh() async {
    final conversations = await _conversationRepo.getPaginated(
      limit: _pageSize,
      offset: 0,
    );
    state = AsyncData(ConversationListState(
      conversations: conversations,
      searchQuery: '',
      hasMore: conversations.length == _pageSize,
    ));
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !current.hasMore || current.isLoadingMore) return;

    state = AsyncData(current.copyWith(isLoadingMore: true));

    try {
      final nextConversations = await _conversationRepo.getPaginated(
        limit: _pageSize,
        offset: current.conversations.length,
      );
      final all = [...current.conversations, ...nextConversations];
      state = AsyncData(ConversationListState(
        conversations: all,
        searchQuery: current.searchQuery,
        snippetsByConversationId: current.snippetsByConversationId,
        hasMore: nextConversations.length == _pageSize,
        isLoadingMore: false,
      ));
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> deleteConversation(String id) async {
    final previous = state.valueOrNull;
    if (previous == null) return;
    final filtered = previous.conversations.where((c) => c.id != id).toList();
    state = AsyncData(previous.copyWith(conversations: filtered));

    try {
      await _conversationRepo.delete(id);
      await _reloadPreservingQuery();
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> restoreConversation(String id) async {
    try {
      await _conversationRepo.restore(id);
      await _reloadPreservingQuery();
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> unarchiveConversation(String id) async {
    try {
      await _conversationRepo.unarchive(id);
      await _reloadPreservingQuery();
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> togglePin(String id) async {
    final previous = state.valueOrNull;

    try {
      await _conversationRepo.togglePin(id);
      await _reloadPreservingQuery();
    } catch (error, stackTrace) {
      if (previous != null) {
        state = AsyncData(previous);
      }
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> archive(String id) async {
    final previous = state.valueOrNull;
    if (previous == null) return;
    final filtered = previous.conversations.where((c) => c.id != id).toList();
    state = AsyncData(previous.copyWith(conversations: filtered));

    try {
      await _conversationRepo.archive(id);
      await _reloadPreservingQuery();
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> rename(String id, String newTitle) async {
    try {
      await _conversationRepo.updateTitle(id, newTitle);
      await _reloadPreservingQuery();
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<List<Conversation>> getArchived() async {
    return _conversationRepo.getArchived();
  }

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      await refresh();
      return;
    }
    try {
      final trimmed = query.trim();
      final results = await _conversationRepo.searchDetailed(trimmed);
      state = AsyncData(ConversationListState(
        conversations: results.map((result) => result.conversation).toList(),
        snippetsByConversationId: <String, String>{
          for (final result in results) result.conversation.id: result.snippet,
        },
        searchQuery: trimmed,
        hasMore: false,
      ));
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> _reloadPreservingQuery() async {
    final query = state.valueOrNull?.searchQuery ?? '';
    if (query.isNotEmpty) {
      await search(query);
      return;
    }
    await refresh();
  }
}
