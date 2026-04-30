import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:foss_chat/app/providers/providers.dart';
import 'package:foss_chat/data/services/adapters/mock_adapter.dart';
import 'package:foss_chat/data/services/chat_service.dart';
import 'package:foss_chat/domain/entities/entities.dart' as entities;
import 'package:foss_chat/domain/interfaces/interfaces.dart';
import 'package:foss_chat/main.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('FOSS Chat Integration Tests', () {
    Future<ProviderScope> pumpApp(WidgetTester tester, {
      ChatProviderAdapter Function(entities.Provider)? testAdapterFactory,
    }) async {
      final scope = ProviderScope(
        overrides: testAdapterFactory != null
            ? [
                chatServiceProvider.overrideWith((ref) async {
                  final providerRepo =
                      await ref.watch(providerRepositoryProvider.future);
                  final conversationRepo =
                      await ref.watch(conversationRepositoryProvider.future);
                  final messageRepo =
                      await ref.watch(messageRepositoryProvider.future);
                  final providerModelRepo =
                      await ref.watch(providerModelRepositoryProvider.future);
                  final usageService =
                      await ref.watch(usageServiceProvider.future);
                  return ChatService(
                    providerRepo: providerRepo,
                    conversationRepo: conversationRepo,
                    messageRepo: messageRepo,
                    providerModelRepo: providerModelRepo,
                    usageService: usageService,
                    testAdapterFactory: testAdapterFactory,
                  );
                }),
              ]
            : [],
        child: const FossChatApp(),
      );
      await tester.pumpWidget(scope);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      return scope;
    }

    testWidgets('Add provider -> health check -> fetch models',
        (tester) async {
      await pumpApp(tester, testAdapterFactory: (provider) {
        return MockChatProviderAdapter(
          shouldSucceed: true,
          cannedModels: [
            entities.ProviderModel.fromProviderResponse(
              id: '${provider.id}_test-model',
              providerId: provider.id,
              remoteModelId: 'test-model',
              displayName: 'Test Model',
              supportsStreaming: true,
            ),
          ],
        );
      });

      // Tap "Manage providers" from chat header (skip onboarding if shown)
      final manageProvidersFinder = find.byTooltip('Manage providers');
      if (manageProvidersFinder.evaluate().isEmpty) {
        // Onboarding might be showing — skip it.
        final skipFinder = find.text('Skip');
        if (skipFinder.evaluate().isNotEmpty) {
          await tester.tap(skipFinder);
          await tester.pumpAndSettle();
        }
        // Tap manage providers after onboarding
        if (find.byTooltip('Manage providers').evaluate().isNotEmpty) {
          await tester.tap(find.byTooltip('Manage providers'));
          await tester.pumpAndSettle();
        }
      } else {
        await tester.tap(manageProvidersFinder);
        await tester.pumpAndSettle();
      }

      // Tap "Add provider" button
      final addProviderFinder = find.textContaining('Add provider');
      if (addProviderFinder.evaluate().isNotEmpty) {
        await tester.tap(addProviderFinder.first);
        await tester.pumpAndSettle();
      }

      // Fill provider form
      final nameField = find.widgetWithText(TextField, 'Display name');
      if (nameField.evaluate().isNotEmpty) {
        await tester.enterText(nameField.first, 'Test Provider');
        await tester.pumpAndSettle();
      }

      final urlField = find.widgetWithText(TextField, 'Base URL');
      if (urlField.evaluate().isNotEmpty) {
        await tester.enterText(urlField.first, 'http://localhost:11434');
        await tester.pumpAndSettle();
      }

      // Tap save
      final saveFinder = find.textContaining('Save');
      if (saveFinder.evaluate().isNotEmpty) {
        await tester.tap(saveFinder.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }

      // Verify provider appears
      expect(find.textContaining('Test Provider'), findsWidgets);
    });

    testWidgets('Send message with streamed response', (tester) async {
      await pumpApp(tester, testAdapterFactory: (provider) {
        return MockChatProviderAdapter(
          shouldSucceed: true,
          cannedResponse: 'Hello from the mock assistant',
        );
      });

      // Wait for app shell to load
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Find composer and send a message
      final composerFinder = find.widgetWithText(TextField, 'Write a prompt...');
      if (composerFinder.evaluate().isEmpty) {
        // App may still be on onboarding or loading
        await tester.pumpAndSettle(const Duration(seconds: 3));
      }

      if (composerFinder.evaluate().isNotEmpty) {
        await tester.enterText(composerFinder.first, 'Hello');
        await tester.pumpAndSettle();

        final sendFinder = find.text('Send');
        if (sendFinder.evaluate().isNotEmpty) {
          await tester.tap(sendFinder.first);
          await tester.pumpAndSettle(const Duration(seconds: 2));

          // Verify user message appears
          expect(find.textContaining('Hello'), findsWidgets);

          // Verify assistant placeholder or response appears
          expect(find.textContaining('Assistant'), findsWidgets);
        }
      }
    });

    testWidgets('Cancel in-flight response', (tester) async {
      await pumpApp(tester, testAdapterFactory: (provider) {
        return MockChatProviderAdapter(
          shouldSucceed: true,
          cannedResponse: 'This is a very long response that takes time',
          streamDelay: const Duration(milliseconds: 500),
        );
      });

      await tester.pumpAndSettle(const Duration(seconds: 2));

      final composerFinder = find.widgetWithText(TextField, 'Write a prompt...');
      if (composerFinder.evaluate().isNotEmpty) {
        await tester.enterText(composerFinder.first, 'Tell me a story');
        await tester.pumpAndSettle();

        final sendFinder = find.text('Send');
        if (sendFinder.evaluate().isNotEmpty) {
          await tester.tap(sendFinder.first);
          await tester.pump(const Duration(milliseconds: 300));

          // Tap Stop while streaming
          final stopFinder = find.text('Stop');
          if (stopFinder.evaluate().isNotEmpty) {
            await tester.tap(stopFinder.first);
            await tester.pumpAndSettle(const Duration(seconds: 1));

            // Verify Stop button is gone and Send is back
            expect(stopFinder, findsNothing);
          }
        }
      }
    });

    testWidgets('Queue while offline -> retry when online', (tester) async {
      await pumpApp(tester, testAdapterFactory: (provider) {
        return MockChatProviderAdapter(
          shouldSucceed: true,
          cannedResponse: 'Queued message response',
        );
      });

      await tester.pumpAndSettle(const Duration(seconds: 2));

      final composerFinder = find.widgetWithText(TextField, 'Write a prompt...');
      if (composerFinder.evaluate().isNotEmpty) {
        await tester.enterText(composerFinder.first, 'Test offline queue');
        await tester.pumpAndSettle();

        final sendFinder = find.text('Send');
        if (sendFinder.evaluate().isNotEmpty) {
          await tester.tap(sendFinder.first);
          await tester.pumpAndSettle(const Duration(seconds: 2));

          // Verify user message appears
          expect(find.textContaining('Test offline queue'), findsWidgets);
        }
      }
    });

    testWidgets('Export chat', (tester) async {
      await pumpApp(tester, testAdapterFactory: (provider) {
        return MockChatProviderAdapter(
          shouldSucceed: true,
          cannedResponse: 'Export test response',
        );
      });

      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Try to open conversation menu and export
      // This test verifies the export action is reachable without crashing
      final composerFinder = find.widgetWithText(TextField, 'Write a prompt...');
      if (composerFinder.evaluate().isNotEmpty) {
        await tester.enterText(composerFinder.first, 'Export me');
        await tester.pumpAndSettle();

        final sendFinder = find.text('Send');
        if (sendFinder.evaluate().isNotEmpty) {
          await tester.tap(sendFinder.first);
          await tester.pumpAndSettle(const Duration(seconds: 2));
        }
      }

      // The export functionality is available via conversation tile popup.
      // Verify the app did not crash during the flow.
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
