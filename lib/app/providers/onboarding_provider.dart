import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/db/dao/app_setting_dao.dart';
import '../../data/repositories/conversation_repository.dart';
import '../../data/repositories/provider_repository.dart';
import '../../domain/entities/app_setting.dart';
import 'repository_providers.dart';

final onboardingProvider =
    AsyncNotifierProvider<OnboardingNotifier, OnboardingState>(
  OnboardingNotifier.new,
);

class OnboardingState {
  final bool isComplete;
  final bool localOnlyMode;
  final String? lastOllamaEndpoint;
  final int providerCount;
  final int conversationCount;

  const OnboardingState({
    required this.isComplete,
    required this.localOnlyMode,
    required this.lastOllamaEndpoint,
    required this.providerCount,
    required this.conversationCount,
  });

  bool get shouldShowOnboarding =>
      !isComplete && providerCount == 0 && conversationCount == 0;
}

class OnboardingNotifier extends AsyncNotifier<OnboardingState> {
  @override
  Future<OnboardingState> build() async {
    return _loadState(
      appSettingDao: await ref.watch(appSettingDaoProvider.future),
      providerRepository: await ref.watch(providerRepositoryProvider.future),
      conversationRepository:
          await ref.watch(conversationRepositoryProvider.future),
    );
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_readState);
  }

  Future<void> setLocalOnlyMode(bool value) async {
    final appSettingDao = await ref.read(appSettingDaoProvider.future);
    await appSettingDao.setLocalOnlyMode(value);
    await refresh();
  }

  Future<void> rememberOllamaEndpoint(String endpoint) async {
    if (endpoint.trim().isEmpty) {
      return;
    }
    final appSettingDao = await ref.read(appSettingDaoProvider.future);
    await appSettingDao.setLastOllamaEndpoint(endpoint.trim());
    await refresh();
  }

  Future<void> complete({
    required bool localOnlyMode,
    String? lastOllamaEndpoint,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final appSettingDao = await ref.read(appSettingDaoProvider.future);
    await prefs.setBool('has_completed_onboarding', true);
    await appSettingDao.setLocalOnlyMode(localOnlyMode);
    if (lastOllamaEndpoint != null && lastOllamaEndpoint.trim().isNotEmpty) {
      await appSettingDao.setLastOllamaEndpoint(lastOllamaEndpoint.trim());
    }
    await appSettingDao.completeOnboarding();
    await refresh();
  }

  Future<void> reopen() async {
    final prefs = await SharedPreferences.getInstance();
    final appSettingDao = await ref.read(appSettingDaoProvider.future);
    await prefs.setBool('has_completed_onboarding', false);
    await appSettingDao.setBool(AppSettingKeys.hasCompletedOnboarding, false);
    await refresh();
  }

  Future<OnboardingState> _readState() async {
    return _loadState(
      appSettingDao: await ref.read(appSettingDaoProvider.future),
      providerRepository: await ref.read(providerRepositoryProvider.future),
      conversationRepository:
          await ref.read(conversationRepositoryProvider.future),
    );
  }

  Future<OnboardingState> _loadState({
    required AppSettingDao appSettingDao,
    required ProviderRepository providerRepository,
    required ConversationRepository conversationRepository,
  }) async {
    final providers = await providerRepository.getAll();
    final conversationCount = await conversationRepository.getExistingCount();
    final prefs = await SharedPreferences.getInstance();
    final prefsComplete = prefs.getBool('has_completed_onboarding');
    final isComplete =
        prefsComplete ?? await appSettingDao.isOnboardingComplete();
    return OnboardingState(
      isComplete: isComplete,
      localOnlyMode: await appSettingDao.isLocalOnlyMode(),
      lastOllamaEndpoint: await appSettingDao.getLastOllamaEndpoint(),
      providerCount: providers.length,
      conversationCount: conversationCount,
    );
  }
}
