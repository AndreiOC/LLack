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
  Future<List<Provider>> getAll({bool includeDeleted = false}) async {
    final providers = await _dao.getAll(includeDeleted: includeDeleted);
    return Future.wait(
      providers.map((p) => _mergeSecretHeaders(p)),
    );
  }

  /// Get soft-deleted providers
  Future<List<Provider>> getDeleted() => _dao.getDeleted();

  /// Get provider by ID
  Future<Provider?> getById(String id) async {
    final provider = await _dao.getActiveById(id);
    if (provider == null) return null;
    return _mergeSecretHeaders(provider);
  }

  /// Get provider by ID including deleted providers
  Future<Provider?> getAnyById(String id) async {
    final provider = await _dao.getById(id);
    if (provider == null) return null;
    return _mergeSecretHeaders(provider);
  }

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

    String? apiKeyRef;
    final hasApiKey = apiKey != null && apiKey.isNotEmpty;
    final (publicHeaders, secretHeaders) = _splitHeaders(id, headers);

    try {
      // Spec FR-ONB-2: if secure storage succeeds but metadata persistence
      // fails, roll back the secret write so provider creation remains atomic.
      if (hasApiKey) {
        await _secureStorage.storeProviderApiKey(id, apiKey);
        apiKeyRef = _secureStorage.generateProviderKeyRef(id);
      }

      for (final entry in secretHeaders.entries) {
        await _secureStorage.storeProviderHeaderSecret(id, entry.key, entry.value);
      }

      final provider = Provider(
        id: id,
        kind: kind,
        displayName: displayName,
        baseUrl: baseUrl,
        apiKeyRef: apiKeyRef,
        defaultModelId: defaultModelId,
        headers: publicHeaders,
        settings: settings,
        healthStatus: ProviderHealthStatus.neverChecked,
        createdAt: now,
        updatedAt: now,
      );

      await _dao.insert(provider);
      return provider;
    } catch (_) {
      if (hasApiKey) {
        await _secureStorage.deleteProviderApiKey(id);
      }
      for (final key in secretHeaders.keys) {
        await _secureStorage.deleteProviderHeaderSecret(id, key);
      }
      rethrow;
    }
  }

  /// Update provider
  Future<Provider> update(
    Provider provider, {
    String? newApiKey,
    bool clearApiKey = false,
    Map<String, String>? newHeaders,
  }) async {
    final trimmedApiKey = newApiKey?.trim();
    final shouldClearApiKey = clearApiKey || trimmedApiKey == '';
    final previousApiKey = await _secureStorage.getProviderApiKey(provider.id);

    final previousSecretHeaders = <String, String?>{};
    for (final key in provider.headers.keys) {
      if (SecureStorageService.isSecretHeaderKey(key)) {
        previousSecretHeaders[key] =
            await _secureStorage.getProviderHeaderSecret(provider.id, key);
      }
    }

    final (publicHeaders, secretHeaders) = newHeaders != null
        ? _splitHeaders(provider.id, newHeaders)
        : (provider.headers, <String, String>{});

    try {
      // Spec FR-ONB-2: keep provider metadata and secure storage updates in
      // sync, restoring the previous secret state if the metadata write fails.
      if (shouldClearApiKey) {
        await _secureStorage.deleteProviderApiKey(provider.id);
      } else if (trimmedApiKey != null) {
        await _secureStorage.storeProviderApiKey(provider.id, trimmedApiKey);
      }

      // Clear old secret headers that are no longer present.
      for (final oldKey in previousSecretHeaders.keys) {
        if (!secretHeaders.containsKey(oldKey)) {
          await _secureStorage.deleteProviderHeaderSecret(provider.id, oldKey);
        }
      }
      // Store new secret headers.
      for (final entry in secretHeaders.entries) {
        await _secureStorage.storeProviderHeaderSecret(
            provider.id, entry.key, entry.value);
      }

      final updated = provider.copyWith(
        apiKeyRef: shouldClearApiKey
            ? null
            : (trimmedApiKey != null
                ? _secureStorage.generateProviderKeyRef(provider.id)
                : provider.apiKeyRef),
        headers: publicHeaders,
        updatedAt: DateTime.now(),
      );

      await _dao.update(updated);
      return updated;
    } catch (_) {
      if (previousApiKey != null && previousApiKey.isNotEmpty) {
        await _secureStorage.storeProviderApiKey(provider.id, previousApiKey);
      } else {
        await _secureStorage.deleteProviderApiKey(provider.id);
      }
      for (final entry in previousSecretHeaders.entries) {
        if (entry.value != null) {
          await _secureStorage.storeProviderHeaderSecret(
              provider.id, entry.key, entry.value!);
        } else {
          await _secureStorage.deleteProviderHeaderSecret(provider.id, entry.key);
        }
      }
      rethrow;
    }
  }

  /// Insert or update a provider
  Future<Provider> upsert(
    Provider provider, {
    String? apiKey,
    bool clearApiKey = false,
    Map<String, String>? headers,
  }) async {
    final existing = await _dao.getById(provider.id);
    if (existing == null) {
      final trimmedApiKey = apiKey?.trim();
      final hasApiKey = trimmedApiKey != null && trimmedApiKey.isNotEmpty;

      try {
        if (hasApiKey) {
          await _secureStorage.storeProviderApiKey(provider.id, trimmedApiKey);
        }

        final created = provider.copyWith(
          apiKeyRef: hasApiKey
              ? _secureStorage.generateProviderKeyRef(provider.id)
              : provider.apiKeyRef,
        );
        await _dao.insert(created);
        return created;
      } catch (_) {
        if (hasApiKey) {
          await _secureStorage.deleteProviderApiKey(provider.id);
        }
        rethrow;
      }
    }

    return update(
      provider.copyWith(createdAt: existing.createdAt),
      newApiKey: apiKey,
      clearApiKey: clearApiKey,
      newHeaders: headers,
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

  // ---- Header Secret Helpers ----

  (Map<String, String> public, Map<String, String> secret) _splitHeaders(
    String providerId,
    Map<String, String> headers,
  ) {
    final public = <String, String>{};
    final secret = <String, String>{};
    for (final entry in headers.entries) {
      if (SecureStorageService.isSecretHeaderKey(entry.key)) {
        secret[entry.key] = entry.value;
      } else {
        public[entry.key] = entry.value;
      }
    }
    return (public, secret);
  }

  Future<Provider> _mergeSecretHeaders(Provider provider) async {
    final merged = Map<String, String>.from(provider.headers);
    for (final key in provider.headers.keys) {
      if (SecureStorageService.isSecretHeaderKey(key)) {
        final secret = await _secureStorage.getProviderHeaderSecret(provider.id, key);
        if (secret != null) {
          merged[key] = secret;
        }
      }
    }
    // Also check for secret headers that exist in secure storage but not in SQLite
    // (this handles the case where headers were previously saved with secrets).
    // Since we can't list secure storage keys, we check common secret header names.
    const commonSecretKeys = [
      'Authorization',
      'X-API-Key',
      'API-Key',
      'API_Key',
      'APIKey',
      'Token',
      'Access-Token',
      'Secret',
      'Password',
      'Key',
    ];
    for (final key in commonSecretKeys) {
      if (!merged.containsKey(key)) {
        final secret = await _secureStorage.getProviderHeaderSecret(provider.id, key);
        if (secret != null) {
          merged[key] = secret;
        }
      }
    }
    return provider.copyWith(headers: merged);
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

    final previousApiKey = await _secureStorage.getProviderApiKey(providerId);
    try {
      await _secureStorage.deleteProviderApiKey(providerId);
      final updated = provider.copyWith(
        apiKeyRef: null,
        updatedAt: DateTime.now(),
      );
      await _dao.update(updated);
      return updated;
    } catch (_) {
      if (previousApiKey != null && previousApiKey.isNotEmpty) {
        await _secureStorage.storeProviderApiKey(providerId, previousApiKey);
      }
      rethrow;
    }
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
