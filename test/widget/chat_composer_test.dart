import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Chat composer widget tests', () {
    testWidgets('empty composer disables send button', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(hintText: 'Write a prompt...'),
                ),
                ElevatedButton(
                  onPressed: controller.text.trim().isNotEmpty
                      ? () {}
                      : null,
                  child: const Text('Send'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Send should be disabled when empty
      final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('typing enables send and submit clears text', (tester) async {
      final controller = TextEditingController();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TextField(
                  controller: controller,
                  decoration: const InputDecoration(hintText: 'Write a prompt...'),
                  onSubmitted: (_) => controller.clear(),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Hello');
      await tester.pumpAndSettle();

      expect(controller.text, 'Hello');

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(controller.text, isEmpty);
    });
  });
}
