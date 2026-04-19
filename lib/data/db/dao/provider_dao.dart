import 'package:sqflite/sqflite.dart';
import '../../domain/entities/entities.dart';

/// Data Access Object for Provider operations
class ProviderDao {
  final Database _db;

  ProviderDao(this._db);

  /// Get all non-deleted providers ordered by last updated
  Future<List<Provider>> getAll() async {
    final maps = await _db.query(
      'providers',
      where: 'deleted_at IS NULL',
      orderBy: 'updated_at DESC',
    );
    return maps.map((m) => Provider.fromJson(m)).toList();
  }

  /// Get provider by ID (including deleted)
  Future<Provider?> getById(String id) async {
    final maps = await _db.query(
      'providers',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Provider.fromJson(maps.first);
  }

  /// Get provider by ID (active only)
  Future<Provider?> getActiveById(String id) async {
    final maps = await _db.query(
      'providers',
      where: 'id = ? AND deleted_at IS NULL',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Provider.fromJson(maps.first);
  }

  /// Insert new provider
  Future<void> insert(Provider provider) async {
    await _db.insert('providers', provider.toJson());
  }

  /// Update provider
  Future<void> update(Provider provider) async {
    await _db.update(
      'providers',
      provider.toJson(),
      where: 'id = ?',
      whereArgs: [provider.id],
    );
  }

  /// Soft delete provider
  Future<void> softDelete(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      'providers',
      {'deleted_at': now, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Restore soft-deleted provider
  Future<void> restore(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      'providers',
      {'deleted_at': null, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Permanently delete provider
  Future<void> deletePermanently(String id) async {
    await _db.delete(
      'providers',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Update health status
  Future<void> updateHealthStatus(
    String id,
    ProviderHealthStatus status,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      'providers',
      {
        'health_status': status.name,
        'health_checked_at': now,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get Ollama providers (for auto-discovery fallback)
  Future<List<Provider>> getOllamaProviders() async {
    final maps = await _db.query(
      'providers',
      where: 'kind = ? AND deleted_at IS NULL',
      whereArgs: [ProviderKind.ollama.name],
    );
    return maps.map((m) => Provider.fromJson(m)).toList();
  }
}
