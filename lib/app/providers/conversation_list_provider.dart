import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/conversation_repository.dart';
import '../../domain/entities/entities.dart';
import 'repository_providers.dart';

final conversationListProvider = AutoDisposeAsyncNotifierProvider<
    ConversationListNotifier, List<Conversation>>(
  ConversationListNotifier.new,
);

class ConversationListNotifier
    extends AutoDisposeAsyncNotifier<List<Conversation>> {
  late final ConversationRepository _conversationRepo;

  @override
  Future<List<Conversation>> build() async {
    _conversationRepo = await ref.watch(conversationRepositoryProvider.future);
    return _conversationRepo.getAll();
  }

  Future<void> load() async {
    state = const AsyncLoading<List<Conversation>>();
    state = await AsyncValue.guard(_conversationRepo.getAll);
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_conversationRepo.getAll);
  }

  Future<void> deleteConversation(String id) async {
    final previous = state.valueOrNull ?? const <Conversation>[];
    state = AsyncData(
      previous.where((conversation) => conversation.id != id).toList(),
    );

    try {
      await _conversationRepo.delete(id);
      await refresh();
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> restoreConversation(String id) async {
    try {
      await _conversationRepo.restore(id);
      await refresh();
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> togglePin(String id) async {
    final previous = state.valueOrNull ?? const <Conversation>[];

    try {
      await _conversationRepo.togglePin(id);
      await refresh();
    } catch (error, stackTrace) {
      state = AsyncData(previous);
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> archive(String id) async {
    final previous = state.valueOrNull ?? const <Conversation>[];
    state = AsyncData(
      previous.where((conversation) => conversation.id != id).toList(),
    );

    try {
      await _conversationRepo.archive(id);
      await refresh();
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> rename(String id, String newTitle) async {
    try {
      await _conversationRepo.updateTitle(id, newTitle);
      await refresh();
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> search(String query) async {
    if (query.trim().isEmpty) {
      await refresh();
      return;
    }
    state = await AsyncValue.guard(
      () => _conversationRepo.search(query.trim()),
    );
  }
}
