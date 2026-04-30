import 'package:flutter_test/flutter_test.dart';
import 'package:foss_chat/features/chat/export_service.dart';
import 'package:foss_chat/domain/entities/entities.dart';

void main() {
  group('ExportService', () {
    final conversation = Conversation(
      id: 'conv-1',
      title: 'Test Chat',
      createdAt: DateTime(2026, 4, 30, 10, 0),
      updatedAt: DateTime(2026, 4, 30, 10, 5),
    );

    final messages = <Message>[
      Message.user(
        id: 'msg-1',
        conversationId: 'conv-1',
        content: 'Hello',
        sequenceNo: 1,
      ),
      Message.assistantPlaceholder(
        id: 'msg-2',
        conversationId: 'conv-1',
        sequenceNo: 2,
        providerId: 'p1',
        modelId: 'gpt-4',
      ).copyWith(
        contentMarkdown: 'Hi there!',
        status: MessageStatus.completed,
      ),
    ];

    test('toMarkdown includes title and messages', () async {
      final md = await ExportService.toMarkdown(conversation, messages);
      expect(md, contains('# Test Chat'));
      expect(md, contains('## User'));
      expect(md, contains('Hello'));
      expect(md, contains('## Assistant'));
      expect(md, contains('Hi there!'));
      expect(md, contains('_Model: gpt-4_'));
    });

    test('toJson includes structured data', () async {
      final json = await ExportService.toJson(conversation, messages);
      expect(json, contains('"version": 1'));
      expect(json, contains('"title": "Test Chat"'));
      expect(json, contains('"role": "user"'));
      expect(json, contains('"role": "assistant"'));
    });
  });
}
