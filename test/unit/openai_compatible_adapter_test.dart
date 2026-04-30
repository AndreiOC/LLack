import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_chat/data/services/adapters/openai_compatible_adapter.dart';
import 'package:foss_chat/domain/interfaces/chat_provider_adapter.dart';

void main() {
  test('streamChat parses SSE delta and usage chunks', () async {
    final dio = Dio()
      ..httpClientAdapter = _FakeStreamHttpClientAdapter(
        <String>[
          'data: {"choices":[{"delta":{"content":"Hello"}}]}\n',
          'data: {"usage":{"prompt_tokens":3,"completion_tokens":1,"total_tokens":4}}\n',
          'data: [DONE]\n',
        ],
      );
    final adapter = OpenAiCompatibleAdapter(dio: dio);

    final events = await adapter
        .streamChat(
          ChatRequest(
            baseUrl: 'https://api.example.com',
            modelId: 'test-model',
            messages: <ChatMessage>[
              ChatMessage(role: 'user', content: 'Hi'),
            ],
          ),
          'test-key',
        )
        .toList();

    expect(
      events.where((event) => event.contentDelta != null).map((event) => event.contentDelta).join(),
      'Hello',
    );
    expect(events.last.isDone, isTrue);
    expect(events.last.metadata?['total_tokens'], 4);
  });

  test('streamChat parses NDJSON chunks without the SSE prefix', () async {
    final dio = Dio()
      ..httpClientAdapter = _FakeStreamHttpClientAdapter(
        <String>[
          '{"choices":[{"delta":{"content":"Hel',
          'lo"}}]}\n{"choices":[{"delta":{"content":" there"}}]}\n',
          '{"usage":{"prompt_tokens":5,"completion_tokens":2,"total_tokens":7}}\n',
          '[DONE]\n',
        ],
      );
    final adapter = OpenAiCompatibleAdapter(dio: dio);

    final events = await adapter
        .streamChat(
          ChatRequest(
            baseUrl: 'https://api.example.com',
            modelId: 'test-model',
            messages: <ChatMessage>[
              ChatMessage(role: 'user', content: 'Hi'),
            ],
          ),
          'test-key',
        )
        .toList();

    expect(
      events.where((event) => event.contentDelta != null).map((event) => event.contentDelta).join(),
      'Hello there',
    );
    expect(events.last.isDone, isTrue);
    expect(events.last.metadata?['prompt_tokens'], 5);
  });
}

class _FakeStreamHttpClientAdapter implements HttpClientAdapter {
  _FakeStreamHttpClientAdapter(this._chunks);

  final List<String> _chunks;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return ResponseBody(
      Stream<Uint8List>.fromIterable(
        _chunks.map((chunk) => Uint8List.fromList(utf8.encode(chunk))),
      ),
      200,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['text/event-stream'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
