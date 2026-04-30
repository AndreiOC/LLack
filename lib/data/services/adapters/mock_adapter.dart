import 'dart:async';

import '../../../domain/entities/entities.dart';
import '../../../domain/errors/chat_errors.dart';
import '../../../domain/interfaces/chat_provider_adapter.dart';

/// A mock adapter for integration testing.
/// Returns canned responses without making real HTTP requests.
class MockChatProviderAdapter implements ChatProviderAdapter {
  final bool shouldSucceed;
  final String? cannedResponse;
  final List<ProviderModel>? cannedModels;
  final Duration streamDelay;

  MockChatProviderAdapter({
    this.shouldSucceed = true,
    this.cannedResponse,
    this.cannedModels,
    this.streamDelay = const Duration(milliseconds: 50),
  });

  @override
  Future<ProviderValidationResult> validateConfig(Provider provider) async {
    if (shouldSucceed) {
      return ProviderValidationResult.success(
        metadata: {'models_available': cannedModels?.length ?? 2},
      );
    }
    return ProviderValidationResult.failure('Mock validation failed');
  }

  @override
  Future<List<ProviderModel>> fetchModels(Provider provider) async {
    await Future.delayed(const Duration(milliseconds: 100));
    return cannedModels ?? [
      ProviderModel.fromProviderResponse(
        id: '${provider.id}_model_a',
        providerId: provider.id,
        remoteModelId: 'model-a',
        displayName: 'Model A',
        supportsStreaming: true,
      ),
      ProviderModel.fromProviderResponse(
        id: '${provider.id}_model_b',
        providerId: provider.id,
        remoteModelId: 'model-b',
        displayName: 'Model B',
        supportsStreaming: true,
      ),
    ];
  }

  @override
  Future<ProviderHealthStatus> healthCheck(Provider provider) async {
    return shouldSucceed
        ? ProviderHealthStatus.healthy
        : ProviderHealthStatus.unreachable;
  }

  @override
  Stream<ChatStreamEvent> streamChat(
    ChatRequest request,
    String apiKey, {
    Object? cancelToken,
  }) async* {
    if (!shouldSucceed) {
      throw const ProviderError('Mock stream error');
    }

    final response = cannedResponse ?? 'This is a mock response for testing.';
    final words = response.split(' ');

    for (var i = 0; i < words.length; i++) {
      await Future.delayed(streamDelay);
      final delta = i == 0 ? words[i] : ' ${words[i]}';
      yield ChatStreamEvent.delta(delta);
    }

    yield ChatStreamEvent.done(metadata: {
      'prompt_tokens': 10,
      'completion_tokens': words.length,
      'total_tokens': 10 + words.length,
    });
  }

  @override
  Future<ChatCompletionResult> completeChat(
    ChatRequest request,
    String apiKey,
  ) async {
    if (!shouldSucceed) {
      throw const ProviderError('Mock completion error');
    }

    final response = cannedResponse ?? 'This is a mock response for testing.';
    return ChatCompletionResult(
      content: response,
      metadata: {
        'prompt_tokens': 10,
        'completion_tokens': response.split(' ').length,
        'total_tokens': 10 + response.split(' ').length,
      },
    );
  }
}
