import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../data/repositories/conversation_repository.dart';
import '../../data/repositories/message_repository.dart';
import '../../data/repositories/provider_repository.dart';
import '../../data/services/chat_service.dart';
import '../../domain/entities/entities.dart';
import '../../domain/interfaces/chat_provider_adapter.dart';
import 'chat_service_provider.dart';
import 'conversation_list_provider.dart';
import 'repository_providers.dart';

final chatStateProvider =
    AutoDisposeAsyncNotifierProvider<ChatStateNotifier, ChatState>(
  ChatStateNotifier.new,
);

class ChatState {
  static const Object _sentinel = Object();

  final String conversationId;
  final Conversation? conversation;
  final List<Message> messages;
  final bool isStreaming;
  final String? streamingContent;
  final String? error;
  final Provider? selectedProvider;

  const ChatState({
    required this.conversationId,
    required this.messages,
    required this.isStreaming,
    required this.streamingContent,
    required this.error,
    required this.selectedProvider,
    this.conversation,
  });

  factory ChatState.initial({Provider? selectedProvider}) {
    return ChatState(
      conversationId: '',
      conversation: null,
      messages: const <Message>[],
      isStreaming: false,
      streamingContent: null,
      error: null,
      selectedProvider: selectedProvider,
    );
  }

  ChatState copyWith({
    String? conversationId,
    Object? conversation = _sentinel,
    List<Message>? messages,
    bool? isStreaming,
    Object? streamingContent = _sentinel,
    Object? error = _sentinel,
    Object? selectedProvider = _sentinel,
  }) {
    return ChatState(
      conversationId: conversationId ?? this.conversationId,
      conversation: identical(conversation, _sentinel)
          ? this.conversation
          : conversation as Conversation?,
      messages: messages ?? this.messages,
      isStreaming: isStreaming ?? this.isStreaming,
      streamingContent: identical(streamingContent, _sentinel)
          ? this.streamingContent
          : streamingContent as String?,
      error: identical(error, _sentinel) ? this.error : error as String?,
      selectedProvider: identical(selectedProvider, _sentinel)
          ? this.selectedProvider
          : selectedProvider as Provider?,
    );
  }
}

class ChatStateNotifier extends AutoDisposeAsyncNotifier<ChatState> {
  ChatService? _chatService;
  ConversationRepository? _conversationRepo;
  MessageRepository? _messageRepo;
  ProviderRepository? _providerRepo;
  StreamSubscription<ChatStreamEvent>? _streamSubscription;
  String? _activeAssistantMessageId;

  @override
  Future<ChatState> build() async {
    ref.onDispose(() {
      unawaited(_streamSubscription?.cancel());
    });

    await _ensureDependencies(useWatch: true);
    return _buildInitialState();
  }

  Future<void> prepareNewConversation() async {
    await _cancelStreamSubscription();
    state = AsyncData(await _buildInitialState());
  }

  Future<void> loadConversation(String id) async {
    if (id.isEmpty) {
      await prepareNewConversation();
      return;
    }

    await _cancelStreamSubscription();
    state = const AsyncLoading<ChatState>();
    state = await AsyncValue.guard(() => _loadChatState(id));
  }

  Future<void> sendMessage(String content) async {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return;
    }

    final current = await future;
    if (current.isStreaming) {
      state = AsyncData(
        current.copyWith(error: 'Wait for the current response to finish.'),
      );
      return;
    }

    await _ensureDependencies();

    final selectedProvider = current.selectedProvider;
    if (selectedProvider == null) {
      state = AsyncData(
        current.copyWith(error: 'Add a provider before starting a chat.'),
      );
      return;
    }

    final modelId = current.conversation?.selectedModelId ??
        selectedProvider.defaultModelId;
    if (modelId == null || modelId.isEmpty) {
      state = AsyncData(
        current.copyWith(
          error: 'Select a default model in Providers before sending messages.',
        ),
      );
      return;
    }

    try {
      late Conversation conversation;
      late Message userMessage;
      late Message assistantMessage;

      if (current.conversationId.isEmpty) {
        final result = await _chatService!.createConversationAndSendMessage(
          content: trimmed,
          providerId: selectedProvider.id,
          modelId: modelId,
        );
        conversation = result.$1;
        userMessage = result.$2;
        assistantMessage = result.$3;
      } else {
        if (current.conversation == null) {
          throw Exception('Conversation not loaded');
        }

        final needsConversationUpdate =
            current.conversation!.selectedProviderId != selectedProvider.id ||
                current.conversation!.selectedModelId != modelId;
        if (needsConversationUpdate) {
          final updatedConversation = current.conversation!.copyWith(
            selectedProviderId: selectedProvider.id,
            selectedModelId: modelId,
            updatedAt: DateTime.now(),
          );
          await _conversationRepo!.update(updatedConversation);
          conversation = updatedConversation;
        } else {
          conversation = current.conversation!;
        }

        final result = await _chatService!.sendMessage(
          conversationId: conversation.id,
          content: trimmed,
        );
        userMessage = result.$1;
        assistantMessage = result.$2;
      }

      final streamingAssistant = assistantMessage.copyWith(
        status: MessageStatus.streaming,
      );
      final nextMessages = <Message>[
        ...current.messages,
        userMessage,
        streamingAssistant,
      ];

      _activeAssistantMessageId = assistantMessage.id;
      state = AsyncData(
        current.copyWith(
          conversationId: conversation.id,
          conversation: conversation,
          messages: nextMessages,
          isStreaming: true,
          streamingContent: '',
          error: null,
          selectedProvider: selectedProvider,
        ),
      );
      ref.invalidate(conversationListProvider);

      await _startStreaming(
        conversationId: conversation.id,
        assistantMessageId: assistantMessage.id,
        messages: nextMessages
            .where((message) => message.id != assistantMessage.id)
            .toList(),
      );
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> cancelStream() async {
    final current = state.valueOrNull;
    if (current == null || _activeAssistantMessageId == null) {
      return;
    }

    final activeMessageId = _activeAssistantMessageId!;
    await _cancelStreamSubscription();
    await _chatService?.cancelMessage(activeMessageId);
    await _reloadCurrentConversation(error: 'Response cancelled.');
  }

  Future<void> retryMessage(String id) async {
    final current = await future;
    final index = current.messages.indexWhere((message) => message.id == id);
    if (index == -1) {
      return;
    }

    final message = current.messages[index];
    String? content;
    if (message.isUser) {
      content = message.contentMarkdown;
    } else {
      for (int i = index - 1; i >= 0; i -= 1) {
        final candidate = current.messages[i];
        if (candidate.isUser) {
          content = candidate.contentMarkdown;
          break;
        }
      }
    }

    if (content == null || content.trim().isEmpty) {
      state = AsyncData(
        current.copyWith(error: 'Could not determine which prompt to retry.'),
      );
      return;
    }

    await sendMessage(content);
  }

  Future<void> deleteMessage(String id) async {
    await _ensureDependencies();

    if (_activeAssistantMessageId == id) {
      await cancelStream();
      return;
    }

    try {
      await _messageRepo!.delete(id);
      await _reloadCurrentConversation();
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> selectProvider(Provider? provider) async {
    final current = await future;
    if (provider == null) {
      state = AsyncData(current.copyWith(selectedProvider: null, error: null));
      return;
    }

    if (current.conversation == null) {
      state = AsyncData(
        current.copyWith(selectedProvider: provider, error: null),
      );
      return;
    }

    final updatedConversation = current.conversation!.copyWith(
      selectedProviderId: provider.id,
      selectedModelId: provider.defaultModelId,
      updatedAt: DateTime.now(),
    );
    await _conversationRepo!.update(updatedConversation);

    state = AsyncData(
      current.copyWith(
        conversation: updatedConversation,
        selectedProvider: provider,
        error: null,
      ),
    );
  }

  Future<void> _startStreaming({
    required String conversationId,
    required String assistantMessageId,
    required List<Message> messages,
  }) async {
    await _cancelStreamSubscription();

    _streamSubscription = _chatService!
        .streamResponse(
      conversationId: conversationId,
      assistantMessageId: assistantMessageId,
      messages: _toChatMessages(messages),
    )
        .listen(
      (event) {
        if (event.contentDelta != null) {
          _applyStreamDelta(assistantMessageId, event.contentDelta!);
        }

        if (event.error != null) {
          unawaited(_reloadCurrentConversation(error: event.error));
          return;
        }

        if (event.isDone) {
          unawaited(_reloadCurrentConversation());
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        state = AsyncError(error, stackTrace);
      },
      cancelOnError: false,
    );
  }

  void _applyStreamDelta(String assistantMessageId, String delta) {
    final current = state.valueOrNull;
    if (current == null) {
      return;
    }

    final nextContent = '${current.streamingContent ?? ''}$delta';
    final updatedMessages = current.messages.map((message) {
      if (message.id != assistantMessageId) {
        return message;
      }

      return message.copyWith(
        contentMarkdown: nextContent,
        status: MessageStatus.streaming,
        updatedAt: DateTime.now(),
      );
    }).toList();

    state = AsyncData(
      current.copyWith(
        messages: updatedMessages,
        isStreaming: true,
        streamingContent: nextContent,
        error: null,
      ),
    );
  }

  Future<void> _reloadCurrentConversation({String? error}) async {
    final current = state.valueOrNull;
    if (current == null || current.conversationId.isEmpty) {
      return;
    }

    final nextState = await _loadChatState(current.conversationId);
    _activeAssistantMessageId = null;
    ref.invalidate(conversationListProvider);
    state = AsyncData(
      nextState.copyWith(
        isStreaming: false,
        streamingContent: null,
        error: error,
      ),
    );
  }

  Future<ChatState> _loadChatState(String conversationId) async {
    await _ensureDependencies();

    final conversation = await _conversationRepo!.getById(conversationId);
    if (conversation == null) {
      throw Exception('Conversation not found');
    }

    final messages = await _chatService!.getMessages(conversationId);
    Provider? selectedProvider;
    if (conversation.selectedProviderId != null) {
      selectedProvider =
          await _providerRepo!.getById(conversation.selectedProviderId!);
    }

    return ChatState(
      conversationId: conversation.id,
      conversation: conversation,
      messages: messages,
      isStreaming:
          messages.any((message) => message.status == MessageStatus.streaming),
      streamingContent: _currentStreamingContent(messages),
      error: null,
      selectedProvider: selectedProvider,
    );
  }

  Future<ChatState> _buildInitialState() async {
    final providers = await _providerRepo!.getAll();
    return ChatState.initial(
      selectedProvider: providers.isNotEmpty ? providers.first : null,
    );
  }

  Future<void> _ensureDependencies({bool useWatch = false}) async {
    _chatService ??= useWatch
        ? await ref.watch(chatServiceProvider.future)
        : await ref.read(chatServiceProvider.future);
    _conversationRepo ??= useWatch
        ? await ref.watch(conversationRepositoryProvider.future)
        : await ref.read(conversationRepositoryProvider.future);
    _messageRepo ??= useWatch
        ? await ref.watch(messageRepositoryProvider.future)
        : await ref.read(messageRepositoryProvider.future);
    _providerRepo ??= useWatch
        ? await ref.watch(providerRepositoryProvider.future)
        : await ref.read(providerRepositoryProvider.future);
  }

  Future<void> _cancelStreamSubscription() async {
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    _activeAssistantMessageId = null;
  }

  List<ChatMessage> _toChatMessages(List<Message> messages) {
    return messages
        .where((message) => message.contentMarkdown.trim().isNotEmpty)
        .map(
          (message) => ChatMessage(
            role: message.role.name,
            content: message.contentMarkdown,
          ),
        )
        .toList();
  }

  String? _currentStreamingContent(List<Message> messages) {
    for (final message in messages.reversed) {
      if (message.status == MessageStatus.streaming) {
        return message.contentMarkdown;
      }
    }
    return null;
  }
}
