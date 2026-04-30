import 'dart:async';
import 'package:dio/dio.dart';
import '../../data/repositories/repositories.dart';
import '../../data/services/adapters/adapters.dart';
import '../../data/services/logging_service.dart';
import '../../data/services/usage_service.dart';
import '../../domain/entities/entities.dart';
import '../../domain/errors/chat_errors.dart';
import '../../domain/interfaces/chat_provider_adapter.dart';

/// Service for managing chat operations
/// Orchestrates adapters, repositories, and streaming
class ChatService {
  final ProviderRepository _providerRepo;
  final ConversationRepository _conversationRepo;
  final MessageRepository _messageRepo;
  final ProviderModelRepository? _providerModelRepo;
  final UsageService? _usageService;
  final ChatProviderAdapter Function(Provider)? _testAdapterFactory;
  final Map<String, CancelToken> _activeCancelTokens = {};

  ChatService({
    required ProviderRepository providerRepo,
    required ConversationRepository conversationRepo,
    required MessageRepository messageRepo,
    ProviderModelRepository? providerModelRepo,
    UsageService? usageService,
    ChatProviderAdapter Function(Provider)? testAdapterFactory,
  })  : _providerRepo = providerRepo,
        _conversationRepo = conversationRepo,
        _messageRepo = messageRepo,
        _providerModelRepo = providerModelRepo,
        _usageService = usageService,
        _testAdapterFactory = testAdapterFactory;

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
    LoggingService.instance.info(
      'Starting stream for conversation $conversationId',
      category: LogCategory.chat,
      data: {'messageCount': messages.length, 'providerId': conversationId},
    );

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
    final adapter = _createAdapter(provider);

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

    final buffer = StringBuffer();
    DateTime? lastDbWrite;

    try {
      // Stream response
      Map<String, dynamic>? metadata;
      String? error;

      await for (final event in adapter.streamChat(request, apiKey ?? '',
          cancelToken: cancelToken)) {
        if (event.error != null) {
          error = event.error;
          break;
        }

        if (event.contentDelta != null) {
          buffer.write(event.contentDelta);
          // Throttle DB writes to avoid I/O churn (spec §7.2)
          final now = DateTime.now();
          if (lastDbWrite == null ||
              now.difference(lastDbWrite) >=
                  const Duration(milliseconds: 300)) {
            await _messageRepo.updateStreamingContent(
              assistantMessageId,
              buffer.toString(),
            );
            lastDbWrite = now;
          }
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
        final inputTokens = _coerceInt(metadata?['prompt_tokens']) ??
            _coerceInt(metadata?['prompt_eval_count']) ??
            _estimateTokensFromContent(
              messages.map((message) => message.content).join(' '),
            );
        final outputTokens = _coerceInt(metadata?['completion_tokens']) ??
            _coerceInt(metadata?['eval_count']) ??
            _estimateTokensFromContent(buffer.toString());
        final estimatedCostMicros = _estimateCostMicros(
          provider: provider,
          inputTokens: inputTokens,
          outputTokens: outputTokens,
        );

        await _messageRepo.finalizeStreaming(
          id: assistantMessageId,
          content: buffer.toString(),
          status: MessageStatus.completed,
          metadata: metadata,
          inputTokens: inputTokens,
          outputTokens: outputTokens,
          estimatedCostMicros: estimatedCostMicros,
        );

        await _providerModelRepo?.touchLastUsedByRemoteModelId(
          provider.id,
          modelId,
        );
        await _usageService?.recordMessageUsage(
          conversationId: conversation.id,
          messageId: assistantMessageId,
          provider: provider,
          modelId: modelId,
          inputTokens: inputTokens,
          outputTokens: outputTokens,
          estimatedCostMicros: estimatedCostMicros,
        );
        yield ChatStreamEvent.done(metadata: metadata);
      }

      // Update conversation
      await _conversationRepo.update(conversation.copyWith(
        updatedAt: DateTime.now(),
      ));
    } on CancellationError {
      // User-initiated cancellation: status is already set by cancelMessage().
      rethrow;
    } catch (e, stack) {
      LoggingService.instance.error(
        'Stream error for conversation $conversationId',
        category: LogCategory.chat,
        error: e,
        stackTrace: stack,
      );
      // Ensure the message is marked failed when the stream throws unexpectedly
      // so it does not remain stuck in streaming state (spec §7.2).
      final currentMessage = await _messageRepo.getById(assistantMessageId);
      if (currentMessage != null && !currentMessage.isFinal) {
        await _messageRepo.finalizeStreaming(
          id: assistantMessageId,
          content: buffer.toString(),
          status: MessageStatus.failed,
          metadata: {'error': e.toString()},
        );
      }
      rethrow;
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
    final adapter = _createAdapter(provider);
    return await adapter.validateConfig(provider);
  }

  /// Fetch models from provider
  Future<List<ProviderModel>> fetchModels(Provider provider) async {
    final adapter = _createAdapter(provider);
    return await adapter.fetchModels(provider);
  }

  /// Spec FR-PRV-3: provider health state is refreshed independently from full
  /// config validation so the UI can cache and display health checks.
  Future<ProviderHealthStatus> checkProviderHealth(Provider provider) async {
    final adapter = _createAdapter(provider);
    return adapter.healthCheck(provider);
  }

  /// Edit a user message and regenerate the assistant response (spec FR-CHT-7).
  Future<(Message editedUserMessage, Message assistantMessage)> editMessage({
    required String conversationId,
    required String originalMessageId,
    required int originalSequenceNo,
    required String newContent,
    String? providerId,
    String? modelId,
  }) async {
    return _messageRepo.editMessage(
      conversationId: conversationId,
      originalMessageId: originalMessageId,
      originalSequenceNo: originalSequenceNo,
      newContent: newContent,
      providerId: providerId,
      modelId: modelId,
    );
  }

  /// Retry an outbox job by streaming into the existing assistant message.
  Future<void> retryOutboxJob(OutboxJob job) async {
    final conversation = await _conversationRepo.getById(job.conversationId);
    if (conversation == null) {
      throw Exception('Conversation not found');
    }

    final providerId = conversation.selectedProviderId;
    final modelId = conversation.selectedModelId;
    if (providerId == null || modelId == null) {
      throw Exception('No provider/model selected for conversation');
    }

    final provider = await _providerRepo.getById(providerId);
    if (provider == null) {
      throw Exception('Provider not found');
    }

    // Get conversation history excluding the placeholder assistant message
    final messages = await _messageRepo.getByConversationId(job.conversationId);
    final chatMessages = messages
        .where(
            (m) => m.id != job.messageId && m.contentMarkdown.trim().isNotEmpty)
        .map((m) => ChatMessage(role: m.role.name, content: m.contentMarkdown))
        .toList();

    // Ensure the user message content is represented in history
    final content = job.payload['content'] as String?;
    if (content != null && content.trim().isNotEmpty) {
      if (chatMessages.isEmpty || chatMessages.last.content != content) {
        chatMessages.add(ChatMessage(role: 'user', content: content));
      }
    }

    // Consume the stream into the existing assistant message
    await for (final _ in streamResponse(
      conversationId: job.conversationId,
      assistantMessageId: job.messageId,
      messages: chatMessages,
    )) {
      // Stream is consumed; message is updated by streamResponse.
    }
  }

  String _generateTitle(String content) {
    final trimmed = content.trim();
    if (trimmed.length <= 30) return trimmed;
    return '${trimmed.substring(0, 27)}...';
  }

  ChatProviderAdapter _createAdapter(Provider provider) {
    if (_testAdapterFactory != null) {
      return _testAdapterFactory!(provider);
    }
    return ChatAdapterFactory.createAdapter(
      provider,
      modelRepo: _providerModelRepo,
    );
  }

  int _estimateCostMicros({
    required Provider provider,
    required int inputTokens,
    required int outputTokens,
  }) {
    if (provider.isOllama) {
      return 0;
    }

    final inputRate = _readPricingMicros(
      provider.settings,
      keys: const <String>[
        'input_cost_per_1k_micros',
        'inputCostPer1kMicros',
        'prompt_cost_per_1k_micros',
      ],
    );
    final outputRate = _readPricingMicros(
      provider.settings,
      keys: const <String>[
        'output_cost_per_1k_micros',
        'outputCostPer1kMicros',
        'completion_cost_per_1k_micros',
      ],
    );

    final inputCost = ((inputTokens / 1000) * inputRate).round();
    final outputCost = ((outputTokens / 1000) * outputRate).round();
    return inputCost + outputCost;
  }

  int _readPricingMicros(
    Map<String, dynamic> settings, {
    required List<String> keys,
  }) {
    for (final key in keys) {
      final rawValue = settings[key];
      final value = _coerceInt(rawValue);
      if (value != null) {
        return value;
      }
    }
    return 0;
  }

  int _estimateTokensFromContent(String content) {
    final trimmed = content.trim();
    if (trimmed.isEmpty) {
      return 0;
    }
    return (trimmed.length / 4).ceil();
  }

  int? _coerceInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    return int.tryParse('$value');
  }
}
