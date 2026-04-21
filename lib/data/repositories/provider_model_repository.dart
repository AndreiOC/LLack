import '../../data/db/dao/dao.dart';
import '../../domain/entities/entities.dart';

/// Repository for ProviderModel operations
/// Caches available models fetched from providers.
class ProviderModelRepository {
  final ProviderModelDao _dao;

  ProviderModelRepository(this._dao);

  /// Get all cached models for a provider
  Future<List<ProviderModel>> getByProviderId(String providerId) {
    return _dao.getByProviderId(providerId);
  }

  /// Get a specific model by remote ID
  Future<ProviderModel?> getByRemoteModelId(
    String providerId,
    String remoteModelId,
  ) {
    return _dao.getByRemoteModelId(providerId, remoteModelId);
  }

  /// Cache models fetched from a provider, replacing existing cache
  Future<void> cacheModels(String providerId, List<ProviderModel> models) async {
    await _dao.deleteByProviderId(providerId);
    await _dao.upsertBatch(providerId, models);
  }

  /// Mark a model as recently used
  Future<void> touchLastUsed(String modelId) {
    return _dao.touchLastUsed(modelId);
  }

  /// Clear all cached models for a provider
  Future<void> clearCache(String providerId) {
    return _dao.deleteByProviderId(providerId);
  }

  /// Get count of cached models
  Future<int> getCount(String providerId) {
    return _dao.countByProviderId(providerId);
  }
}
