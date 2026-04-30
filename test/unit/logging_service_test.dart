import 'package:flutter_test/flutter_test.dart';
import 'package:foss_chat/data/services/logging_service.dart';

void main() {
  group('LoggingService.redact', () {
    test('redacts API keys in JSON', () {
      const input = '{"api_key": "sk-abc123secret", "name": "test"}';
      final result = LoggingService.redact(input);
      expect(result, contains('[REDACTED]'));
      expect(result, isNot(contains('sk-abc123secret')));
    });

    test('redacts Authorization header', () {
      const input = 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9';
      final result = LoggingService.redact(input);
      expect(result, contains('[REDACTED'));
      expect(result, isNot(contains('eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9')));
    });

    test('redacts sk- prefixed tokens', () {
      const input = 'Token: sk-abcdefghijklmnopqrstuvwxyz';
      final result = LoggingService.redact(input);
      expect(result, contains('[REDACTED'));
      expect(result, isNot(contains('sk-abcdefghijklmnopqrstuvwxyz')));
    });

    test('leaves non-sensitive data intact', () {
      const input = '{"model": "gpt-4", "temperature": 0.7}';
      final result = LoggingService.redact(input);
      expect(result, equals(input));
    });
  });
}
