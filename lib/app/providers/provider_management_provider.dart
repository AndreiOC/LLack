import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../data/repositories/provider_repository.dart';
import '../../domain/entities/entities.dart';
import '../../domain/interfaces/chat_provider_adapter.dart';
import 'chat_service_provider.dart';
import 'repository_providers.dart';

final providerManagementProvider =
    AsyncNotifierProvider<ProviderManagementNotifier, List<Provider>>(
  ProviderManagementNotifier.new,
);

class ProviderManagementNotifier extends AsyncNotifier<List<Provider>> {
  static const Duration _healthCacheTtl = Duration(minutes: 5);

  bool _scheduledInitialHealthRefresh = false;
  bool _isRefreshingHealth = false;

  @override
  Future<List<Provider>> build() async {
    final providers = await _loadProviders(
      providerRepo: await ref.watch(providerRepositoryProvider.future),
    );

    if (!_scheduledInitialHealthRefresh) {
      _scheduledInitialHealthRefresh = true;
      // Spec FR-PRV-3: refresh stale provider health opportunistically on app
      // start without blocking the initial UI load.
      unawaited(_refreshHealthStatusesIfNeeded(providers));
    }

    return providers;
  }

  Future<void> load() async {
    state = const AsyncLoading<List<Provider>>();
    state = await AsyncValue.guard(_readProviders);
  }

  Future<Provider> addProvider(Provider provider, {String? apiKey}) async {
    final providerRepo = await ref.read(providerRepositoryProvider.future);
    final created = await providerRepo.create(
      displayName: provider.displayName,
      kind: provider.kind,
      baseUrl: provider.baseUrl,
      apiKey: apiKey,
      defaultModelId: provider.defaultModelId,
      headers: provider.headers,
      settings: provider.settings,
    );
    await load();
    return created;
  }

  Future<Provider> updateProvider(
    Provider provider, {
    String? apiKey,
    Map<String, String>? headers,
  }) async {
    final providerRepo = await ref.read(providerRepositoryProvider.future);
    final updated = await providerRepo.update(
      provider,
      newApiKey: apiKey != null && apiKey.isNotEmpty ? apiKey : null,
      newHeaders: headers,
    );
    await load();
    return updated;
  }

  Future<Provider> updateProviderSecret(
    Provider provider, {
    String? apiKey,
    bool clearApiKey = false,
    Map<String, String>? headers,
  }) async {
    final providerRepo = await ref.read(providerRepositoryProvider.future);
    final updated = await providerRepo.update(
      provider,
      newApiKey: apiKey != null && apiKey.isNotEmpty ? apiKey : null,
      clearApiKey: clearApiKey,
      newHeaders: headers,
    );
    await load();
    return updated;
  }

  Future<void> deleteProvider(String id) async {
    final providerRepo = await ref.read(providerRepositoryProvider.future);
    await providerRepo.delete(id);
    await load();
  }

  Future<void> deleteProviderWithFallback(
    String id, {
    String? fallbackProviderId,
    String? fallbackModelId,
  }) async {
    final conversationRepo = await ref.read(
      conversationRepositoryProvider.future,
    );
    final providerRepo = await ref.read(providerRepositoryProvider.future);
    await conversationRepo.reassignProvider(
      id,
      fallbackProviderId: fallbackProviderId,
      fallbackModelId: fallbackModelId,
    );
    await providerRepo.delete(id);
    await load();
  }

  Future<void> restoreProvider(String id) async {
    final providerRepo = await ref.read(providerRepositoryProvider.future);
    await providerRepo.restore(id);
    await load();
  }

  Future<ProviderValidationResult> validateProvider(String id) async {
    final providerRepo = await ref.read(providerRepositoryProvider.future);
    final provider = await providerRepo.getById(id);
    if (provider == null) {
      throw Exception('Provider not found');
    }

    final apiKey =
        provider.requiresApiKey ? await providerRepo.getApiKey(id) : null;
    final result = await validateDraft(provider, apiKey: apiKey);
    await providerRepo.updateHealthStatus(
      id,
      result.isValid
          ? ProviderHealthStatus.healthy
          : ProviderHealthStatus.degraded,
    );
    await load();
    return result;
  }

  Future<ProviderHealthStatus> refreshProviderHealth(
    String id, {
    bool force = true,
  }) async {
    final providerRepo = await ref.read(providerRepositoryProvider.future);
    final provider = await providerRepo.getById(id);
    if (provider == null) {
      throw Exception('Provider not found');
    }

    if (!force && !_shouldRefreshHealth(provider)) {
      return provider.healthStatus ?? ProviderHealthStatus.neverChecked;
    }

    final chatService = await ref.read(chatServiceProvider.future);
    final status = await chatService.checkProviderHealth(provider);
    await providerRepo.updateHealthStatus(id, status);
    await load();
    return status;
  }

  Future<List<ProviderModel>> fetchModels(String id) async {
    final providerRepo = await ref.read(providerRepositoryProvider.future);
    final provider = await providerRepo.getById(id);
    if (provider == null) {
      throw Exception('Provider not found');
    }

    final apiKey =
        provider.requiresApiKey ? await providerRepo.getApiKey(id) : null;
    return fetchModelsForDraft(provider, apiKey: apiKey);
  }

  Future<int> getConversationUsageCount(String providerId) async {
    final conversationRepo = await ref.read(
      conversationRepositoryProvider.future,
    );
    return conversationRepo.countUsingProvider(providerId);
  }

  Future<void> refreshHealthStatuses({bool force = false}) async {
    final providerRepo = await ref.read(providerRepositoryProvider.future);
    final providers = state.valueOrNull ?? await providerRepo.getAll();
    await _refreshHealthStatusesIfNeeded(providers, force: force);
  }

  Future<ProviderValidationResult> validateDraft(
    Provider provider, {
    String? apiKey,
  }) async {
    final draftProvider = _providerWithValidationHeaders(provider, apiKey);
    final chatService = await ref.read(chatServiceProvider.future);
    return chatService.validateProvider(draftProvider);
  }

  Future<List<ProviderModel>> fetchModelsForDraft(
    Provider provider, {
    String? apiKey,
  }) async {
    final draftProvider = _providerWithValidationHeaders(provider, apiKey);
    final chatService = await ref.read(chatServiceProvider.future);
    return chatService.fetchModels(draftProvider);
  }

  Provider _providerWithValidationHeaders(Provider provider, String? apiKey) {
    if (!provider.requiresApiKey || apiKey == null || apiKey.isEmpty) {
      return provider;
    }

    return provider.copyWith(
      headers: <String, String>{
        ...provider.headers,
        'Authorization': 'Bearer $apiKey',
      },
    );
  }

  Future<void> _refreshHealthStatusesIfNeeded(
    List<Provider> providers, {
    bool force = false,
  }) async {
    if (_isRefreshingHealth) {
      return;
    }

    final candidates = providers.where((provider) {
      return force || _shouldRefreshHealth(provider);
    }).toList();

    if (candidates.isEmpty) {
      return;
    }

    _isRefreshingHealth = true;
    var changed = false;
    final providerRepo = await ref.read(providerRepositoryProvider.future);
    final chatService = await ref.read(chatServiceProvider.future);

    try {
      for (final provider in candidates) {
        final nextStatus = await chatService.checkProviderHealth(provider);
        if (provider.healthStatus != nextStatus || force) {
          await providerRepo.updateHealthStatus(provider.id, nextStatus);
          changed = true;
        }
      }
    } finally {
      _isRefreshingHealth = false;
    }

    if (changed) {
      await load();
    }
  }

  bool _shouldRefreshHealth(Provider provider) {
    final lastCheckedAt = provider.healthCheckedAt;
    if (lastCheckedAt == null) {
      return true;
    }
    return DateTime.now().difference(lastCheckedAt) >= _healthCacheTtl;
  }

  Future<List<Provider>> _readProviders() async {
    return _loadProviders(
      providerRepo: await ref.read(providerRepositoryProvider.future),
    );
  }

  Future<List<Provider>> _loadProviders({
    required ProviderRepository providerRepo,
  }) {
    return providerRepo.getAll();
  }
}
