import 'package:flutter_test/flutter_test.dart';
import 'package:foss_chat/domain/errors/chat_errors.dart';

void main() {
  group('SecurityError', () {
    test('is a ChatError with correct message', () {
      const error = SecurityError('Insecure endpoint', code: 'INSECURE_ENDPOINT');
      expect(error.message, 'Insecure endpoint');
      expect(error.code, 'INSECURE_ENDPOINT');
      expect(error, isA<ChatError>());
    });
  });
}
