import 'package:flutter_test/flutter_test.dart';
import 'package:foss_chat/domain/entities/entities.dart';

void main() {
  group('Message', () {
    test('isEditable is true for completed user messages', () {
      final message = Message.user(
        id: '1',
        conversationId: 'c1',
        content: 'Hello',
        sequenceNo: 1,
      );
      expect(message.isEditable, true);
    });

    test('isEditable is false for assistant messages', () {
      final message = Message.assistantPlaceholder(
        id: '2',
        conversationId: 'c1',
        sequenceNo: 2,
      );
      expect(message.isEditable, false);
    });

    test('isSuperseded reflects superseded status', () {
      final message = Message.user(
        id: '1',
        conversationId: 'c1',
        content: 'Hello',
        sequenceNo: 1,
      ).copyWith(status: MessageStatus.superseded);
      expect(message.isSuperseded, true);
      expect(message.isFinal, true);
    });

    test('canRetry is true for failed messages', () {
      final message = Message.assistantPlaceholder(
        id: '2',
        conversationId: 'c1',
        sequenceNo: 2,
      ).copyWith(status: MessageStatus.failed);
      expect(message.canRetry, true);
    });

    test('hasTokens is true when input or output tokens present', () {
      final message = Message.assistantPlaceholder(
        id: '2',
        conversationId: 'c1',
        sequenceNo: 2,
      ).copyWith(inputTokens: 10);
      expect(message.hasTokens, true);
    });
  });
}
