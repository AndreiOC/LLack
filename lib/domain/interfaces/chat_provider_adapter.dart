import 'dart:async';
import '../../domain/entities/entities.dart';

/// Result of provider validation
class ProviderValidationResult {
  final bool isValid;
  final String? errorMessage;
  final Map<String, dynamic>? metadata;

  ProviderValidationResult({
    required this.isValid,
    this.errorMessage,
    this.metadata,
  });

  factory ProviderValidationResult.success({Map<String, dynamic>? metadata}) {
    return ProviderValidationResult(isValid: true, metadata: metadata);
  }

  factory ProviderValidationResult.failure(String error) {
    return ProviderValidationResult(isValid: false, errorMessage: error);
  }
}

/// Request for chat completion
class ChatRequest {
  final String baseUrl;
  final String modelId;
  final List<ChatMessage> messages;
  final Map<String, dynamic>? parameters;

  ChatRequest({
    required this.baseUrl,
    required this.modelId,
    required this.messages,
    this.parameters,
  });
}

/// Single message in chat request
class ChatMessage {
  final String role;
  final String content;

  ChatMessage({required this.role, required this.content});

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

/// Streaming event from provider
class ChatStreamEvent {
  final String? contentDelta;
  final bool isDone;
  final Map<String, dynamic>? metadata;
  final String? error;

  ChatStreamEvent({
    this.contentDelta,
    this.isDone = false,
    this.metadata,
    this.error,
  });

  factory ChatStreamEvent.delta(String content) {
    return ChatStreamEvent(contentDelta: content);
  }

  factory ChatStreamEvent.done({Map<String, dynamic>? metadata}) {
    return ChatStreamEvent(isDone: true, metadata: metadata);
  }

  factory ChatStreamEvent.error(String error) {
    return ChatStreamEvent(error: error, isDone: true);
  }
}

/// Result of chat completion (non-streaming)
class ChatCompletionResult {
  final String content;
  final Map<String, dynamic>? metadata;
  final int? inputTokens;
  final int? outputTokens;

  ChatCompletionResult({
    required this.content,
    this.metadata,
    this.inputTokens,
    this.outputTokens,
  });
}

/// Abstract adapter interface for chat providers
abstract class ChatProviderAdapter {
  /// Validate provider configuration
  Future<ProviderValidationResult> validateConfig(Provider provider);

  /// Fetch available models from provider
  Future<List<ProviderModel>> fetchModels(Provider provider);

  /// Check provider health
  Future<ProviderHealthStatus> healthCheck(Provider provider);

  /// Stream chat completion
  Stream<ChatStreamEvent> streamChat(ChatRequest request, String apiKey);

  /// Complete chat (non-streaming fallback)
  Future<ChatCompletionResult> completeChat(
    ChatRequest request,
    String apiKey,
  );
}
