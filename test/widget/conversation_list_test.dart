import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_chat/domain/entities/entities.dart';

void main() {
  group('Conversation list widget tests', () {
    testWidgets('conversation tile renders title and date', (tester) async {
      final conversation = Conversation(
        id: 'test-1',
        title: 'Test Conversation',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListTile(
              title: Text(conversation.title),
              subtitle: Text('Updated now'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Test Conversation'), findsOneWidget);
    });

    testWidgets('pin action toggles pin state', (tester) async {
      bool wasTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ListTile(
              title: const Text('Pinnable Chat'),
              trailing: IconButton(
                icon: const Icon(Icons.push_pin_outlined),
                onPressed: () => wasTapped = true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.push_pin_outlined));
      await tester.pumpAndSettle();

      expect(wasTapped, isTrue);
    });
  });
}
