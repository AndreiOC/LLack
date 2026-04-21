import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/interfaces/chat_provider_adapter.dart';

/// Adapter for OpenAI-compatible APIs
/// Works with OpenAI, OpenRouter, Groq, and other compatible providers
class OpenAiCompatibleAdapter implements ChatProviderAdapter {
  final Dio _dio;

  OpenAiCompatibleAdapter({Dio? dio}) : _dio = dio ?? Dio();

  @override
  Future<ProviderValidationResult> validateConfig(Provider provider) async {
    try {
      // Try to fetch models endpoint as validation
      final response = await _dio.get(
        '${provider.baseUrl}/models',
        options: Options(
          headers: _buildHeaders(provider),
          validateStatus: (status) => status != null && status < 500,
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200) {
        return ProviderValidationResult.success(
          metadata: {
            'models_available': (response.data['data'] as List?)?.length ?? 0
          },
        );
      }

      // Some providers don't have /models endpoint, try a minimal completion
      if (response.statusCode == 404) {
        return ProviderValidationResult.success(
          metadata: {'note': 'Models endpoint not available, assuming valid'},
        );
      }

      return ProviderValidationResult.failure(
        'Invalid response: ${response.statusCode}',
      );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        return ProviderValidationResult.failure('Invalid API key');
      }
      return ProviderValidationResult.failure(
        'Connection failed: ${e.message}',
      );
    } catch (e) {
      return ProviderValidationResult.failure('Validation error: $e');
    }
  }

  @override
  Future<List<ProviderModel>> fetchModels(Provider provider) async {
    try {
      final response = await _dio.get(
        '${provider.baseUrl}/models',
        options: Options(
          headers: _buildHeaders(provider),
          validateStatus: (status) => status != null && status < 500,
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch models: ${response.statusCode}');
      }

      final data = response.data as Map<String, dynamic>;
      final models = data['data'] as List<dynamic>? ?? [];

      return models.map((m) {
        final id = m['id'] as String;
        return ProviderModel.fromProviderResponse(
          id: '${provider.id}_$id',
          providerId: provider.id,
          remoteModelId: id,
          displayName: m['name'] ?? id,
          contextWindow: _extractContextWindow(m),
          supportsStreaming: true,
          supportsTools: m['capabilities']?['tools'] == true,
        );
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch models: $e');
    }
  }

  @override
  Future<ProviderHealthStatus> healthCheck(Provider provider) async {
    try {
      final response = await _dio.get(
        '${provider.baseUrl}/models',
        options: Options(
          headers: _buildHeaders(provider),
          validateStatus: (status) => status != null && status < 500,
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200) {
        return ProviderHealthStatus.healthy;
      }
      if (response.statusCode == 401 || response.statusCode == 403) {
        return ProviderHealthStatus.degraded;
      }
      return ProviderHealthStatus.degraded;
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.connectionError) {
        return ProviderHealthStatus.unreachable;
      }
      return ProviderHealthStatus.degraded;
    } catch (e) {
      return ProviderHealthStatus.degraded;
    }
  }

  @override
  Stream<ChatStreamEvent> streamChat(
      ChatRequest request, String apiKey, {CancelToken? cancelToken}) async* {
    try {
      final response = await _dio.post<ResponseBody>(
        '${request.baseUrl}/chat/completions',
        data: {
          'model': request.modelId,
          'messages': request.messages.map((m) => m.toJson()).toList(),
          'stream': true,
          ..._buildParameters(request.parameters),
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          responseType: ResponseType.stream,
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 5),
        ),
        cancelToken: cancelToken,
      );

      final stream = response.data?.stream;
      if (stream == null) {
        yield ChatStreamEvent.error('No response stream');
        return;
      }

      Map<String, dynamic>? finalMetadata;

      await for (final chunk in stream.map((bytes) => utf8.decode(bytes))) {
        // Check cancellation between chunks
        if (cancelToken?.isCancelled ?? false) {
          yield ChatStreamEvent.error('Cancelled by user');
          return;
        }

        final lines = chunk.split('\n').where((l) => l.trim().isNotEmpty);

        for (final line in lines) {
          // Skip "data: " prefix and "[DONE]" marker
          if (!line.startsWith('data: ')) continue;

          final jsonStr = line.substring(6).trim();
          if (jsonStr == '[DONE]') {
            yield ChatStreamEvent.done(metadata: finalMetadata);
            return;
          }

          try {
            final data = jsonDecode(jsonStr) as Map<String, dynamic>;

            // Extract usage from final chunk if available
            final usage = data['usage'] as Map<String, dynamic>?;
            if (usage != null) {
              finalMetadata = {
                'prompt_tokens': usage['prompt_tokens'],
                'completion_tokens': usage['completion_tokens'],
                'total_tokens': usage['total_tokens'],
              };
            }

            final choices = data['choices'] as List<dynamic>?;
            if (choices != null && choices.isNotEmpty) {
              final delta = choices[0]['delta'] as Map<String, dynamic>?;
              final content = delta?['content'] as String?;

              if (content != null && content.isNotEmpty) {
                yield ChatStreamEvent.delta(content);
              }
            }
          } catch (e) {
            // Skip malformed lines
            continue;
          }
        }
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        yield ChatStreamEvent.error('Cancelled by user');
        return;
      }
      if (e.response?.statusCode == 401) {
        yield ChatStreamEvent.error('Invalid API key');
      } else {
        yield ChatStreamEvent.error('Stream error: ${e.message}');
      }
    } catch (e) {
      yield ChatStreamEvent.error('Unexpected error: $e');
    }
  }

  @override
  Future<ChatCompletionResult> completeChat(
    ChatRequest request,
    String apiKey,
  ) async {
    try {
      final response = await _dio.post(
        '${request.baseUrl}/chat/completions',
        data: {
          'model': request.modelId,
          'messages': request.messages.map((m) => m.toJson()).toList(),
          'stream': false,
          ..._buildParameters(request.parameters),
        },
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 2),
        ),
      );

      final data = response.data as Map<String, dynamic>;
      final choices = data['choices'] as List<dynamic>?;
      final message = choices?.firstOrNull?['message'] as Map<String, dynamic>?;
      final content = message?['content'] as String? ?? '';

      final usage = data['usage'] as Map<String, dynamic>?;

      return ChatCompletionResult(
        content: content,
        metadata: data,
        inputTokens: usage?['prompt_tokens'] as int?,
        outputTokens: usage?['completion_tokens'] as int?,
      );
    } catch (e) {
      throw Exception('Completion failed: $e');
    }
  }

  Map<String, String> _buildHeaders(Provider provider) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    // Note: API key should be passed separately, not stored in provider
    // This is for headers defined in provider config
    if (provider.headers.isNotEmpty) {
      headers.addAll(provider.headers);
    }

    return headers;
  }

  Map<String, dynamic> _buildParameters(Map<String, dynamic>? params) {
    final result = <String, dynamic>{};

    if (params != null) {
      // Include common parameters
      if (params.containsKey('temperature')) {
        result['temperature'] = params['temperature'];
      }
      if (params.containsKey('max_tokens')) {
        result['max_tokens'] = params['max_tokens'];
      }
      if (params.containsKey('top_p')) {
        result['top_p'] = params['top_p'];
      }
    }

    return result;
  }

  int? _extractContextWindow(Map<String, dynamic> model) {
    // Try to extract from various provider-specific fields
    final contextWindow = model['context_window'] ?? model['context_length'];
    if (contextWindow is int) return contextWindow;

    // Extract from model ID hints
    final id = model['id'] as String? ?? '';
    if (id.contains('128k') || id.contains('128000')) return 128000;
    if (id.contains('32k') || id.contains('32000')) return 32000;
    if (id.contains('16k') || id.contains('16000')) return 16000;
    if (id.contains('8k') || id.contains('8000')) return 8000;
    if (id.contains('4k') || id.contains('4000')) return 4000;

    return null;
  }
}
