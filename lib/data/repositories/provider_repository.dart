import '../../data/db/dao/dao.dart';
import '../../domain/entities/entities.dart';
import '../../platform/secure_storage/secure_storage.dart';

/// Repository for Provider operations
/// Combines ProviderDao (metadata) + SecureStorage (API keys)
class ProviderRepository {
  final ProviderDao _dao;
  final SecureStorageService _secureStorage;

  ProviderRepository(this._dao, this._secureStorage);

  /// Get all active providers
  Future<List<Provider>> getAll() => _dao.getAll();

  /// Get provider by ID
  Future<Provider?> getById(String id) => _dao.getActiveById(id);

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
  Future<Provider> update(Provider provider, {String? newApiKey}) async {
    final updated = provider.copyWith(updatedAt: DateTime.now());
    
    // Update API key if provided
    if (newApiKey != null) {
      await _secureStorage.storeProviderApiKey(provider.id, newApiKey);
    }
    
    await _dao.update(updated);
    return updated;
  }

  /// Soft delete provider
  Future<void> delete(String id) async {
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

  /// Update health status
  Future<void> updateHealthStatus(String id, ProviderHealthStatus status) {
    return _dao.updateHealthStatus(id, status);
  }

  /// Get Ollama providers
  Future<List<Provider>> getOllamaProviders() => _dao.getOllamaProviders();

  String _generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString();
  }
}