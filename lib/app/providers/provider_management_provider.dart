import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;

import '../../data/repositories/provider_repository.dart';
import '../../data/services/chat_service.dart';
import '../../domain/entities/entities.dart';
import '../../domain/interfaces/chat_provider_adapter.dart';
import 'chat_service_provider.dart';
import 'repository_providers.dart';

final providerManagementProvider =
    AsyncNotifierProvider<ProviderManagementNotifier, List<Provider>>(
  ProviderManagementNotifier.new,
);

class ProviderManagementNotifier extends AsyncNotifier<List<Provider>> {
  late final ProviderRepository _providerRepo;
  late final ChatService _chatService;

  @override
  Future<List<Provider>> build() async {
    _providerRepo = await ref.watch(providerRepositoryProvider.future);
    _chatService = await ref.watch(chatServiceProvider.future);
    return _providerRepo.getAll();
  }

  Future<void> load() async {
    state = const AsyncLoading<List<Provider>>();
    state = await AsyncValue.guard(_providerRepo.getAll);
  }

  Future<Provider> addProvider(Provider provider, {String? apiKey}) async {
    final created = await _providerRepo.create(
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

  Future<Provider> updateProvider(Provider provider, {String? apiKey}) async {
    final updated = await _providerRepo.update(
      provider,
      newApiKey: apiKey != null && apiKey.isNotEmpty ? apiKey : null,
    );
    await load();
    return updated;
  }

  Future<void> deleteProvider(String id) async {
    await _providerRepo.delete(id);
    await load();
  }

  Future<ProviderValidationResult> validateProvider(String id) async {
    final provider = await _providerRepo.getById(id);
    if (provider == null) {
      throw Exception('Provider not found');
    }

    final apiKey =
        provider.requiresApiKey ? await _providerRepo.getApiKey(id) : null;
    final result = await validateDraft(provider, apiKey: apiKey);
    await _providerRepo.updateHealthStatus(
      id,
      result.isValid
          ? ProviderHealthStatus.healthy
          : ProviderHealthStatus.degraded,
    );
    await load();
    return result;
  }

  Future<List<ProviderModel>> fetchModels(String id) async {
    final provider = await _providerRepo.getById(id);
    if (provider == null) {
      throw Exception('Provider not found');
    }

    final apiKey =
        provider.requiresApiKey ? await _providerRepo.getApiKey(id) : null;
    return fetchModelsForDraft(provider, apiKey: apiKey);
  }

  Future<ProviderValidationResult> validateDraft(
    Provider provider, {
    String? apiKey,
  }) async {
    final draftProvider = _providerWithValidationHeaders(provider, apiKey);
    return _chatService.validateProvider(draftProvider);
  }

  Future<List<ProviderModel>> fetchModelsForDraft(
    Provider provider, {
    String? apiKey,
  }) async {
    final draftProvider = _providerWithValidationHeaders(provider, apiKey);
    return _chatService.fetchModels(draftProvider);
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
}
