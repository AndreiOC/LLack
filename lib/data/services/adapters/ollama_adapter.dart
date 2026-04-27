import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import '../../../domain/entities/entities.dart';
import '../../../domain/errors/chat_errors.dart';
import '../../../domain/interfaces/chat_provider_adapter.dart';
import '../../../data/repositories/provider_model_repository.dart';

/// Adapter for Ollama API
/// https://github.com/ollama/ollama/blob/main/docs/api.md
class OllamaAdapter implements ChatProviderAdapter {
  final Dio _dio;
  final ProviderModelRepository? _modelRepo;

  /// Cache TTL for model list (5 minutes)
  static const Duration _modelCacheTtl = Duration(minutes: 5);

  OllamaAdapter({Dio? dio, ProviderModelRepository? modelRepo})
      : _dio = dio ?? Dio(),
        _modelRepo = modelRepo;

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
          metadata: {
            'models_available': (response.data['models'] as List?)?.length ?? 0
          },
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
    // Check cache first if repository is available
    final modelRepo = _modelRepo;
    if (modelRepo != null) {
      try {
        final cached = await modelRepo.getByProviderId(provider.id);
        if (cached.isNotEmpty && _isCacheFresh(cached)) {
          return cached;
        }
      } catch (_) {
        // Ignore cache errors, fetch from provider
      }
    }

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
        throw _mapDioStatusCode(response.statusCode!);
      }

      final models = response.data['models'] as List<dynamic>? ?? [];
      final results = models.map((m) {
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

      // Persist to cache
      if (modelRepo != null) {
        try {
          await modelRepo.cacheModels(provider.id, results);
        } catch (_) {
          // Non-fatal: cache failure shouldn't break fetch
        }
      }

      return results;
    } on DioException catch (e) {
      throw _mapDioException(e);
    } catch (e) {
      if (e is ChatError) rethrow;
      throw ProviderError('Failed to fetch models: $e', originalError: e);
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
  Stream<ChatStreamEvent> streamChat(ChatRequest request, String apiKey,
      {CancelToken? cancelToken}) async* {
    try {
      final response = await _dio.post<ResponseBody>(
        '${request.baseUrl}/api/chat',
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
          throw const CancellationError();
        }

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
              yield ChatStreamEvent.delta(content);
            }
          } on FormatException catch (e) {
            // Malformed JSON line — report as parse error per spec §7.4
            throw StreamParseError(
              'Malformed response from provider',
              code: 'STREAM_PARSE_ERROR',
              originalError: e,
              rawChunk: line,
            );
          } catch (e) {
            // Skip other malformed lines but log
            continue;
          }
        }
      }
    } on DioException catch (e) {
      if (e.type == DioExceptionType.cancel) {
        throw const CancellationError();
      }
      throw _mapDioException(e);
    } catch (e) {
      if (e is ChatError) rethrow;
      throw ProviderError('Stream error: $e', originalError: e);
    }
  }

  @override
  Future<ChatCompletionResult> completeChat(
    ChatRequest request,
    String apiKey,
  ) async {
    try {
      final response = await _dio.post(
        '${request.baseUrl}/api/chat',
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
    } on DioException catch (e) {
      throw _mapDioException(e);
    } catch (e) {
      if (e is ChatError) rethrow;
      throw ProviderError('Completion failed: $e', originalError: e);
    }
  }

  /// Maps DioException to typed ChatError.
  ChatError _mapDioException(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return NetworkError(
        'Connection timed out. Check your connection.',
        code: 'TIMEOUT',
        originalError: e,
      );
    }
    if (e.type == DioExceptionType.connectionError) {
      return NetworkError(
        'Could not connect to server.',
        code: 'CONNECTION_ERROR',
        originalError: e,
      );
    }
    if (e.response != null) {
      final status = e.response!.statusCode;
      if (status != null) {
        if (status == 401 || status == 403) {
          return AuthError(
            'Authentication failed. Check your API key.',
            code: 'AUTH_$status',
            originalError: e,
          );
        }
        if (status == 429) {
          return RateLimitError(
            'Rate limit exceeded. Retry later.',
            code: 'RATE_LIMIT',
            originalError: e,
          );
        }
        if (status >= 400 && status < 500) {
          return ClientError(
            'Invalid request: ${e.response!.statusMessage}',
            code: 'CLIENT_$status',
            originalError: e,
          );
        }
        if (status >= 500) {
          return ProviderError(
            'Provider server error ($status). Retry later.',
            code: 'SERVER_$status',
            originalError: e,
            isRetryable: true,
          );
        }
      }
    }
    if (e.type == DioExceptionType.cancel) {
      return const CancellationError();
    }
    return NetworkError(
      'Network error: ${e.message}',
      code: 'NETWORK_ERROR',
      originalError: e,
    );
  }

  /// Maps an HTTP status code to typed ChatError (for non-Dio errors).
  ChatError _mapDioStatusCode(int status) {
    if (status == 401 || status == 403) {
      return AuthError(
        'Authentication failed. Check your API key.',
        code: 'AUTH_$status',
      );
    }
    if (status == 429) {
      return const RateLimitError(
        'Rate limit exceeded. Retry later.',
        code: 'RATE_LIMIT',
      );
    }
    if (status >= 400 && status < 500) {
      return ClientError(
        'Invalid request ($status).',
        code: 'CLIENT_$status',
      );
    }
    if (status >= 500) {
      return ProviderError(
        'Provider server error ($status). Retry later.',
        code: 'SERVER_$status',
        isRetryable: true,
      );
    }
    return ProviderError(
      'Unexpected response: $status',
      code: 'HTTP_$status',
    );
  }

  /// Check if cached models are still fresh (within TTL).
  bool _isCacheFresh(List<ProviderModel> cached) {
    if (cached.isEmpty) return false;
    // Use the most recently updated model as proxy for cache age
    final newest =
        cached.map((m) => m.updatedAt).reduce((a, b) => a.isAfter(b) ? a : b);
    return DateTime.now().difference(newest) < _modelCacheTtl;
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
