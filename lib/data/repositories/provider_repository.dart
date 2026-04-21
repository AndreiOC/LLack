import '../../data/db/dao/dao.dart';
import '../../domain/entities/entities.dart';
import '../../platform/secure_storage/secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Repository for Provider operations
/// Combines ProviderDao (metadata) + SecureStorage (API keys)
class ProviderRepository {
  final ProviderDao _dao;
  final SecureStorageService _secureStorage;
  static const Uuid _uuid = Uuid();

  ProviderRepository(this._dao, this._secureStorage);

  /// Get all active providers
  Future<List<Provider>> getAll({bool includeDeleted = false}) {
    return _dao.getAll(includeDeleted: includeDeleted);
  }

  /// Get soft-deleted providers
  Future<List<Provider>> getDeleted() => _dao.getDeleted();

  /// Get provider by ID
  Future<Provider?> getById(String id) => _dao.getActiveById(id);

  /// Get provider by ID including deleted providers
  Future<Provider?> getAnyById(String id) => _dao.getById(id);

  /// Check whether a provider exists
  Future<bool> exists(String id) async => (await _dao.getById(id)) != null;

  /// Create new provider
  Future<Provider> create({
    required String displayName,
    required ProviderKind kind,
    required String baseUrl,
    String? apiKey,
    String? defaultModelId,
    Map<String, String> headers = const {},
    Map<String, dynamic> settings = const {},
  }) async {
    final id = _generateId();
    final now = DateTime.now();

    // Store API key in secure storage if provided
    String? apiKeyRef;
    if (apiKey != null && apiKey.isNotEmpty) {
      await _secureStorage.storeProviderApiKey(id, apiKey);
      apiKeyRef = _secureStorage.generateProviderKeyRef(id);
    }

    final provider = Provider(
      id: id,
      kind: kind,
      displayName: displayName,
      baseUrl: baseUrl,
      apiKeyRef: apiKeyRef,
      defaultModelId: defaultModelId,
      headers: headers,
      settings: settings,
      healthStatus: ProviderHealthStatus.neverChecked,
      createdAt: now,
      updatedAt: now,
    );

    await _dao.insert(provider);
    return provider;
  }

  /// Update provider
  Future<Provider> update(
    Provider provider, {
    String? newApiKey,
    bool clearApiKey = false,
  }) async {
    final trimmedApiKey = newApiKey?.trim();
    final shouldClearApiKey = clearApiKey || trimmedApiKey == '';

    if (shouldClearApiKey) {
      await _secureStorage.deleteProviderApiKey(provider.id);
    } else if (trimmedApiKey != null) {
      await _secureStorage.storeProviderApiKey(provider.id, trimmedApiKey);
    }

    final updated = provider.copyWith(
      apiKeyRef: shouldClearApiKey
          ? null
          : (trimmedApiKey != null
              ? _secureStorage.generateProviderKeyRef(provider.id)
              : provider.apiKeyRef),
      updatedAt: DateTime.now(),
    );

    await _dao.update(updated);
    return updated;
  }

  /// Insert or update a provider
  Future<Provider> upsert(
    Provider provider, {
    String? apiKey,
    bool clearApiKey = false,
  }) async {
    final existing = await _dao.getById(provider.id);
    if (existing == null) {
      if (apiKey != null && apiKey.trim().isNotEmpty) {
        await _secureStorage.storeProviderApiKey(provider.id, apiKey.trim());
      }

      final created = provider.copyWith(
        apiKeyRef: apiKey != null && apiKey.trim().isNotEmpty
            ? _secureStorage.generateProviderKeyRef(provider.id)
            : provider.apiKeyRef,
      );
      await _dao.insert(created);
      return created;
    }

    return update(
      provider.copyWith(createdAt: existing.createdAt),
      newApiKey: apiKey,
      clearApiKey: clearApiKey,
    );
  }

  /// Soft delete provider
  Future<void> delete(String id, {bool permanently = false}) async {
    if (permanently) {
      await deletePermanently(id);
      return;
    }
    await _dao.softDelete(id);
  }

  /// Restore soft-deleted provider
  Future<void> restore(String id) => _dao.restore(id);

  /// Permanently delete provider and its API key
  Future<void> deletePermanently(String id) async {
    await _secureStorage.deleteProviderApiKey(id);
    await _dao.deletePermanently(id);
  }

  /// Get provider's API key
  Future<String?> getApiKey(String providerId) {
    return _secureStorage.getProviderApiKey(providerId);
  }

  /// Check whether a provider has a stored API key
  Future<bool> hasApiKey(String providerId) {
    return _secureStorage.hasProviderApiKey(providerId);
  }

  /// Remove a stored API key without deleting the provider
  Future<Provider?> clearApiKey(String providerId) async {
    final provider = await _dao.getById(providerId);
    if (provider == null) {
      return null;
    }

    await _secureStorage.deleteProviderApiKey(providerId);
    final updated = provider.copyWith(
      apiKeyRef: null,
      updatedAt: DateTime.now(),
    );
    await _dao.update(updated);
    return updated;
  }

  /// Update health status
  Future<void> updateHealthStatus(String id, ProviderHealthStatus status) {
    return _dao.updateHealthStatus(id, status);
  }

  /// Get Ollama providers
  Future<List<Provider>> getOllamaProviders() => _dao.getOllamaProviders();

  String _generateId() {
    return _uuid.v4();
  }
}
