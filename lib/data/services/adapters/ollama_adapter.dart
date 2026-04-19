import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../../domain/entities/entities.dart';
import '../../domain/interfaces/chat_provider_adapter.dart';

/// Adapter for Ollama API
/// https://github.com/ollama/ollama/blob/main/docs/api.md
class OllamaAdapter implements ChatProviderAdapter {
  final Dio _dio;

  OllamaAdapter({Dio? dio}) : _dio = dio ?? Dio();

  @override
  Future<ProviderValidationResult> validateConfig(Provider provider) async {
    try {
      final response = await _dio.get(
        '${provider.baseUrl}/api/tags',
        options: Options(
          validateStatus: (status) => status != null && status < 500,
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200) {
        return ProviderValidationResult.success(
          metadata: {'models_available': (response.data['models'] as List?)?.length ?? 0},
        );
      }
      return ProviderValidationResult.failure(
        'Invalid response: ${response.statusCode}',
      );
    } on DioException catch (e) {
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
        '${provider.baseUrl}/api/tags',
        options: Options(
          validateStatus: (status) => status != null && status < 500,
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to fetch models: ${response.statusCode}');
      }

      final models = response.data['models'] as List<dynamic>? ?? [];
      return models.map((m) {
        final name = m['name'] as String;
        return ProviderModel.fromProviderResponse(
          id: '${provider.id}_$name',
          providerId: provider.id,
          remoteModelId: name,
          displayName: name,
          contextWindow: _extractContextWindow(m['details']),
          supportsStreaming: true,
          supportsTools: false,
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
        '${provider.baseUrl}/api/tags',
        options: Options(
          validateStatus: (status) => status != null && status < 500,
          sendTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

      if (response.statusCode == 200) {
        return ProviderHealthStatus.healthy;
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
  Stream<ChatStreamEvent> streamChat(ChatRequest request, String apiKey) async* {
    try {
      final response = await _dio.post<ResponseBody>(
        '${request.providerId}/api/chat',
        data: {
          'model': request.modelId,
          'messages': request.messages.map((m) => m.toJson()).toList(),
          'stream': true,
          'options': request.parameters ?? {},
        },
        options: Options(
          responseType: ResponseType.stream,
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 5),
        ),
      );

      final stream = response.data?.stream;
      if (stream == null) {
        yield ChatStreamEvent.error('No response stream');
        return;
      }

      String accumulatedContent = '';
      Map<String, dynamic>? finalMetadata;

      await for (final chunk in stream.transform(utf8.decoder)) {
        final lines = chunk.split('\n').where((l) => l.trim().isNotEmpty);
        
        for (final line in lines) {
          try {
            final data = jsonDecode(line) as Map<String, dynamic>;
            
            if (data['done'] == true) {
              finalMetadata = {
                'total_duration': data['total_duration'],
                'load_duration': data['load_duration'],
                'prompt_eval_count': data['prompt_eval_count'],
                'eval_count': data['eval_count'],
              };
              yield ChatStreamEvent.done(metadata: finalMetadata);
              return;
            }
            
            final message = data['message'] as Map<String, dynamic>?;
            final content = message?['content'] as String?;
            
            if (content != null && content.isNotEmpty) {
              accumulatedContent += content;
              yield ChatStreamEvent.delta(content);
            }
          } catch (e) {
            // Skip malformed lines
            continue;
          }
        }
      }
    } on DioException catch (e) {
      yield ChatStreamEvent.error('Stream error: ${e.message}');
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
        '${request.providerId}/api/chat',
        data: {
          'model': request.modelId,
          'messages': request.messages.map((m) => m.toJson()).toList(),
          'stream': false,
          'options': request.parameters ?? {},
        },
        options: Options(
          sendTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(minutes: 2),
        ),
      );

      final data = response.data as Map<String, dynamic>;
      final message = data['message'] as Map<String, dynamic>?;
      final content = message?['content'] as String? ?? '';

      return ChatCompletionResult(
        content: content,
        metadata: {
          'total_duration': data['total_duration'],
          'load_duration': data['load_duration'],
        },
        inputTokens: data['prompt_eval_count'] as int?,
        outputTokens: data['eval_count'] as int?,
      );
    } catch (e) {
      throw Exception('Completion failed: $e');
    }
  }

  int? _extractContextWindow(Map<String, dynamic>? details) {
    if (details == null) return null;
    final params = details['parameter_size'] as String?;
    if (params != null) {
      // Try to extract context window from parameter info
      final match = RegExp(r'(\d+)b').firstMatch(params.toLowerCase());
      if (match != null) {
        final billions = int.tryParse(match.group(1) ?? '');
        if (billions != null) {
          // Rough estimate: 2K-128K based on model size
          if (billions >= 70) return 128000;
          if (billions >= 30) return 32000;
          if (billions >= 13) return 16000;
          if (billions >= 7) return 8000;
          return 4000;
        }
      }
    }
    return null;
  }
}
