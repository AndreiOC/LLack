import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_chat/domain/entities/entities.dart';
import 'package:foss_chat/features/providers/provider_editor_sheet.dart';

void main() {
  group('Provider form validation widget tests', () {
    testWidgets('save validates the required fields', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ProviderEditorSheet(
                initialKind: ProviderKind.openaiCompatible,
                isOnboarding: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Save provider'));
      await tester.pump();

      expect(find.text('Enter a provider name.'), findsOneWidget);
      expect(find.text('Enter a base URL.'), findsOneWidget);
    });

    testWidgets('switching to Ollama hides the API key field', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ProviderEditorSheet(
                initialKind: ProviderKind.openaiCompatible,
                isOnboarding: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('API key'), findsOneWidget);

      await tester.tap(find.text('Ollama'));
      await tester.pumpAndSettle();

      expect(find.text('API key'), findsNothing);
    });
  });
}
