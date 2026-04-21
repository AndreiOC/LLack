import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/providers/providers.dart';
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

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboardingAsync = ref.watch(onboardingProvider);
    final providersAsync = ref.watch(providerManagementProvider);

    return onboardingAsync.when(
      data: (onboardingState) {
        if (providersAsync.hasError) {
          return ErrorScreen(error: providersAsync.error.toString());
        }

        final providerList = providersAsync.valueOrNull;
        final shouldShowOnboarding = onboardingState.shouldShowOnboarding ||
            (providerList != null && providerList.isEmpty);

        if (shouldShowOnboarding) {
          return const OnboardingFlow();
        }

        return const ChatWorkspace();
      },
      loading: () => const SplashScreen(),
      error: (error, _) => ErrorScreen(error: error.toString()),
    );
  }
}
