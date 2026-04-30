import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/providers/providers.dart';
import 'data/services/logging_service.dart';
import 'data/services/notification_service.dart';
import 'data/services/outbox_service.dart';
import 'data/services/usage_service.dart';
import 'features/chat/chat_workspace.dart';
import 'features/onboarding/onboarding_flow.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: FossChatApp(),
    ),
  );
}

class FossChatApp extends ConsumerWidget {
  const FossChatApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch database initialization
    final databaseAsync = ref.watch(databaseProvider);

    return MaterialApp(
      title: 'FOSS Chat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB85C38),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFFFBF7),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: Color(0xFFE6D7C8)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: Color(0xFFE6D7C8)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: Color(0xFFB85C38)),
          ),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFB85C38),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: databaseAsync.when(
        data: (_) => const AppShell(),
        loading: () => const SplashScreen(),
        error: (err, stack) => ErrorScreen(error: err.toString()),
      ),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Initializing FOSS Chat...'),
          ],
        ),
      ),
    );
  }
}

class ErrorScreen extends StatelessWidget {
  final String error;

  const ErrorScreen({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Failed to initialize app',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(error, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with WidgetsBindingObserver {
  OutboxService? _outboxService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeServices();
  }

  Future<void> _initializeServices() async {
    await _initializeNotifications();
    await _initializeOutbox();
    await _runRetentionPurge();
  }

  Future<void> _initializeNotifications() async {
    try {
      await NotificationService().initialize();
    } catch (e, stack) {
      LoggingService.instance.warning('Failed to initialize notifications', error: e, stackTrace: stack);
    }
  }

  Future<void> _initializeOutbox() async {
    try {
      final service = await ref.read(outboxServiceProvider.future);
      _outboxService = service;
      service.startPolling();
    } catch (e, stack) {
      // Outbox is optional; don't block app launch on failure.
      LoggingService.instance.warning('Failed to initialize outbox', error: e, stackTrace: stack);
    }
  }

  /// Purge conversations soft-deleted more than 30 days ago (spec FR-CNV-3).
  Future<void> _runRetentionPurge() async {
    try {
      final repo = await ref.read(conversationRepositoryProvider.future);
      final deleted = await repo.purgeOldDeleted(const Duration(days: 30));
      if (deleted > 0) {
        LoggingService.instance.info('Retention purge: removed $deleted old deleted conversations');
      }
    } catch (e, stack) {
      LoggingService.instance.warning('Retention purge failed', error: e, stackTrace: stack);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _outboxService?.stopPolling();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _outboxService?.didChangeAppLifecycleState(state);
  }

  @override
  Widget build(BuildContext context) {
    final onboardingAsync = ref.watch(onboardingProvider);
    final providersAsync = ref.watch(providerManagementProvider);

    // Listen for spending threshold changes and show local notifications
    ref.listen<AsyncValue<UsageOverview>>(usageOverviewProvider, (previous, next) {
      final prevState = previous?.valueOrNull?.thresholdState;
      final nextState = next.valueOrNull?.thresholdState;
      if (nextState != null && nextState != UsageThresholdState.none && nextState != prevState) {
        final title = nextState == UsageThresholdState.exceeded
            ? 'Monthly spend threshold exceeded'
            : 'Monthly spend threshold approaching';
        final body = nextState == UsageThresholdState.exceeded
            ? 'Your cloud provider spending has crossed the monthly limit.'
            : 'You are at 80% of your monthly spend threshold.';
        NotificationService().showSpendingAlert(title: title, body: body);
      }
    });

    return onboardingAsync.when(
      data: (onboardingState) {
        if (providersAsync.hasError) {
          return ErrorScreen(error: providersAsync.error.toString());
        }

        // Spec FR-ONB-1: returning users must never see onboarding again
        // unless manually reset from settings.
        if (onboardingState.shouldShowOnboarding) {
          return const OnboardingFlow();
        }

        return const ChatWorkspace();
      },
      loading: () => const SplashScreen(),
      error: (error, _) => ErrorScreen(error: error.toString()),
    );
  }
}
