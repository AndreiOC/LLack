import 'dart:async';
import 'package:dio/dio.dart';
import '../../data/repositories/repositories.dart';
import '../../data/services/adapters/adapters.dart';
import '../../domain/entities/entities.dart';
import '../../domain/interfaces/chat_provider_adapter.dart';

/// Service for managing chat operations
/// Orchestrates adapters, repositories, and streaming
class ChatService {
  final ProviderRepository _providerRepo;
  final ConversationRepository _conversationRepo;
  final MessageRepository _messageRepo;
  final Map<String, CancelToken> _activeCancelTokens = {};

  ChatService({
    required ProviderRepository providerRepo,
    required ConversationRepository conversationRepo,
    required MessageRepository messageRepo,
  })  : _providerRepo = providerRepo,
        _conversationRepo = conversationRepo,
        _messageRepo = messageRepo;

  /// Create a new conversation and send first message
  Future<
      (
        Conversation conversation,
        Message userMessage,
        Message assistantMessage
      )> createConversationAndSendMessage({
    required String content,
    required String providerId,
    required String modelId,
    String? title,
  }) async {
    // Create conversation
    final conversation = await _conversationRepo.create(
      title: title ?? _generateTitle(content),
      providerId: providerId,
      modelId: modelId,
    );

    // Send message
    final (userMessage, assistantMessage) = await _messageRepo.sendMessage(
      conversationId: conversation.id,
      content: content,
      providerId: providerId,
      modelId: modelId,
    );

    return (conversation, userMessage, assistantMessage);
  }

  /// Send message in existing conversation
  Future<(Message userMessage, Message assistantMessage)> sendMessage({
    required String conversationId,
    required String content,
  }) async {
    final conversation = await _conversationRepo.getById(conversationId);
    if (conversation == null) {
      throw Exception('Conversation not found');
    }

    final providerId = conversation.selectedProviderId;
    final modelId = conversation.selectedModelId;

    if (providerId == null || modelId == null) {
      throw Exception('No provider/model selected for conversation');
    }

    // Send message
    final (userMessage, assistantMessage) = await _messageRepo.sendMessage(
      conversationId: conversationId,
      content: content,
      providerId: providerId,
      modelId: modelId,
    );

    // Update conversation
    await _conversationRepo.update(conversation.copyWith(
      updatedAt: DateTime.now(),
    ));

    return (userMessage, assistantMessage);
  }

  /// Stream response from provider
  Stream<ChatStreamEvent> streamResponse({
    required String conversationId,
    required String assistantMessageId,
    required List<ChatMessage> messages,
    Map<String, dynamic>? parameters,
  }) async* {
    final conversation = await _conversationRepo.getById(conversationId);
    if (conversation == null) {
      yield ChatStreamEvent.error('Conversation not found');
      return;
    }

    final providerId = conversation.selectedProviderId;
    final modelId = conversation.selectedModelId;

    if (providerId == null || modelId == null) {
      yield ChatStreamEvent.error('No provider/model selected');
      return;
    }

    final provider = await _providerRepo.getById(providerId);
    if (provider == null) {
      yield ChatStreamEvent.error('Provider not found');
      return;
    }

    // Get API key if needed
    String? apiKey;
    if (provider.requiresApiKey) {
      apiKey = await _providerRepo.getApiKey(providerId);
      if (apiKey == null) {
        yield ChatStreamEvent.error('API key not found');
        return;
      }
    }

    // Create adapter
    final adapter = ChatAdapterFactory.createAdapter(provider);

    // Create request
    final request = ChatRequest(
      baseUrl: provider.baseUrl,
      modelId: modelId,
      messages: messages,
      parameters: parameters ?? provider.settings,
    );

    // Create cancel token for this stream
    final cancelToken = CancelToken();
    _activeCancelTokens[assistantMessageId] = cancelToken;

    await _messageRepo.updateStatus(
        assistantMessageId, MessageStatus.streaming);

    try {
      // Stream response
      final buffer = StringBuffer();
      Map<String, dynamic>? metadata;
      String? error;

      await for (final event in adapter.streamChat(request, apiKey ?? '', cancelToken: cancelToken)) {
        if (event.error != null) {
          error = event.error;
          break;
        }

        if (event.contentDelta != null) {
          buffer.write(event.contentDelta);
          // Update streaming content periodically
          await _messageRepo.updateStreamingContent(
            assistantMessageId,
            buffer.toString(),
          );
        }

        if (event.isDone) {
          metadata = event.metadata;
          break;
        }

        yield event;
      }

      // Finalize message
      if (error != null) {
        await _messageRepo.finalizeStreaming(
          id: assistantMessageId,
          content: buffer.toString(),
          status: MessageStatus.failed,
          metadata: {'error': error},
        );
        yield ChatStreamEvent.error(error);
      } else {
        await _messageRepo.finalizeStreaming(
          id: assistantMessageId,
          content: buffer.toString(),
          status: MessageStatus.completed,
          metadata: metadata,
          inputTokens:
              metadata?['prompt_tokens'] ?? metadata?['prompt_eval_count'],
          outputTokens: metadata?['completion_tokens'] ?? metadata?['eval_count'],
        );
        yield ChatStreamEvent.done(metadata: metadata);
      }

      // Update conversation
      await _conversationRepo.update(conversation.copyWith(
        updatedAt: DateTime.now(),
      ));
    } finally {
      _activeCancelTokens.remove(assistantMessageId);
    }
  }

  /// Cancel ongoing stream
  Future<void> cancelMessage(String messageId) async {
    final cancelToken = _activeCancelTokens[messageId];
    if (cancelToken != null && !cancelToken.isCancelled) {
      cancelToken.cancel('User cancelled');
    }
    await _messageRepo.updateStatus(messageId, MessageStatus.cancelled);
  }

  /// Get messages for conversation
  Future<List<Message>> getMessages(String conversationId) {
    return _messageRepo.getByConversationId(conversationId);
  }

  /// Get all conversations
  Future<List<Conversation>> getConversations() {
    return _conversationRepo.getAll();
  }

  /// Delete conversation
  Future<void> deleteConversation(String id) {
    return _conversationRepo.delete(id);
  }

  /// Get all providers
  Future<List<Provider>> getProviders() {
    return _providerRepo.getAll();
  }

  /// Validate provider configuration
  Future<ProviderValidationResult> validateProvider(Provider provider) async {
    final adapter = ChatAdapterFactory.createAdapter(provider);
    return await adapter.validateConfig(provider);
  }

  /// Fetch models from provider
  Future<List<ProviderModel>> fetchModels(Provider provider) async {
    final adapter = ChatAdapterFactory.createAdapter(provider);
    return await adapter.fetchModels(provider);
  }

  String _generateTitle(String content) {
    final trimmed = content.trim();
    if (trimmed.length <= 30) return trimmed;
    return '${trimmed.substring(0, 27)}...';
  }
}
