import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foss_chat/features/onboarding/onboarding_flow.dart';

void main() {
  group('Onboarding flow widget tests', () {
    testWidgets('welcome page renders with header and next button', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: OnboardingFlow(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('FOSS Chat'), findsOneWidget);
      expect(find.text('Bring your models online without surrendering the app.'), findsOneWidget);
      expect(find.byType(FilledButton), findsWidgets);
    });

    testWidgets('tapping next advances to second page', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: OnboardingFlow(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find and tap the primary "Next" button
      final nextButton = find.widgetWithText(FilledButton, 'Next');
      expect(nextButton, findsOneWidget);
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      // After advancing, the privacy page should appear
      expect(find.text('Keep the app private by default, then opt into remote providers deliberately.'), findsOneWidget);
    });
  });
}
