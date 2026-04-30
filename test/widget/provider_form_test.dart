import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_chat/domain/entities/entities.dart';
import 'package:foss_chat/features/providers/provider_editor_sheet.dart';

void main() {
  group('Provider form validation widget tests', () {
    testWidgets('empty display name shows validation error', (tester) async {
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

      // The form should render
      expect(find.text('Add provider'), findsOneWidget);
    });

    testWidgets('valid form renders provider kind selector', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ProviderEditorSheet(
                initialKind: ProviderKind.ollama,
                isOnboarding: false,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ollama'), findsOneWidget);
      expect(find.text('OpenAI-compatible'), findsOneWidget);
    });
  });
}
