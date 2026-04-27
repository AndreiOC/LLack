import 'package:sqflite/sqflite.dart';
import '../../../domain/entities/entities.dart';

/// Data Access Object for ProviderModel operations
/// Caches available models from providers locally per Section 5.3 of the spec.
class ProviderModelDao {
  final Database _db;

  ProviderModelDao(this._db);

  /// Get all cached models for a provider
  Future<List<ProviderModel>> getByProviderId(String providerId) async {
    final maps = await _db.query(
      'provider_models',
      where: 'provider_id = ?',
      whereArgs: [providerId],
      orderBy: 'last_used_at DESC, display_name ASC',
    );
    return maps.map((m) => ProviderModel.fromJson(m)).toList();
  }

  /// Get a specific cached model by its remote ID
  Future<ProviderModel?> getByRemoteModelId(
    String providerId,
    String remoteModelId,
  ) async {
    final maps = await _db.query(
      'provider_models',
      where: 'provider_id = ? AND remote_model_id = ?',
      whereArgs: [providerId, remoteModelId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return ProviderModel.fromJson(maps.first);
  }

  /// Insert or update a cached model
  Future<void> upsert(ProviderModel model) async {
    await _db.insert(
      'provider_models',
      model.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Batch insert/replace models for a provider (used after fetchModels)
  Future<void> upsertBatch(
      String providerId, List<ProviderModel> models) async {
    final batch = _db.batch();
    for (final model in models) {
      batch.insert(
        'provider_models',
        model.toJson(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  /// Update last_used_at for a model
  Future<void> touchLastUsed(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      'provider_models',
      {'last_used_at': now, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Update last_used_at using the provider-scoped remote model ID.
  Future<void> touchLastUsedByRemoteModelId(
    String providerId,
    String remoteModelId,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      'provider_models',
      {'last_used_at': now, 'updated_at': now},
      where: 'provider_id = ? AND remote_model_id = ?',
      whereArgs: [providerId, remoteModelId],
    );
  }

  /// Delete all cached models for a provider
  Future<void> deleteByProviderId(String providerId) async {
    await _db.delete(
      'provider_models',
      where: 'provider_id = ?',
      whereArgs: [providerId],
    );
  }

  /// Delete a specific cached model
  Future<void> delete(String id) async {
    await _db.delete(
      'provider_models',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get count of cached models for a provider
  Future<int> countByProviderId(String providerId) async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) as count FROM provider_models WHERE provider_id = ?',
      [providerId],
    );
    return result.first['count'] as int? ?? 0;
  }
}
