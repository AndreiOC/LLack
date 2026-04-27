import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/db/dao/app_setting_dao.dart';
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

  const OnboardingState({
    required this.isComplete,
    required this.localOnlyMode,
    required this.lastOllamaEndpoint,
    required this.providerCount,
  });

  bool get shouldShowOnboarding => !isComplete && providerCount == 0;
}

class OnboardingNotifier extends AsyncNotifier<OnboardingState> {
  late final AppSettingDao _appSettingDao;
  late final ProviderRepository _providerRepository;

  @override
  Future<OnboardingState> build() async {
    _appSettingDao = await ref.watch(appSettingDaoProvider.future);
    _providerRepository = await ref.watch(providerRepositoryProvider.future);
    return _loadState();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_loadState);
  }

  Future<void> setLocalOnlyMode(bool value) async {
    await _appSettingDao.setLocalOnlyMode(value);
    await refresh();
  }

  Future<void> rememberOllamaEndpoint(String endpoint) async {
    if (endpoint.trim().isEmpty) {
      return;
    }
    await _appSettingDao.setLastOllamaEndpoint(endpoint.trim());
    await refresh();
  }

  Future<void> complete({
    required bool localOnlyMode,
    String? lastOllamaEndpoint,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_onboarding', true);
    await _appSettingDao.setLocalOnlyMode(localOnlyMode);
    if (lastOllamaEndpoint != null && lastOllamaEndpoint.trim().isNotEmpty) {
      await _appSettingDao.setLastOllamaEndpoint(lastOllamaEndpoint.trim());
    }
    await _appSettingDao.completeOnboarding();
    await refresh();
  }

  Future<void> reopen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_onboarding', false);
    await _appSettingDao.setBool(AppSettingKeys.hasCompletedOnboarding, false);
    await refresh();
  }

  Future<OnboardingState> _loadState() async {
    final providers = await _providerRepository.getAll();
    final prefs = await SharedPreferences.getInstance();
    final prefsComplete = prefs.getBool('has_completed_onboarding');
    final isComplete = prefsComplete ?? await _appSettingDao.isOnboardingComplete();
    return OnboardingState(
      isComplete: isComplete,
      localOnlyMode: await _appSettingDao.isLocalOnlyMode(),
      lastOllamaEndpoint: await _appSettingDao.getLastOllamaEndpoint(),
      providerCount: providers.length,
    );
  }
}
