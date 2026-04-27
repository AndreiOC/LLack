import 'package:sqflite/sqflite.dart';
import '../../../domain/entities/usage_snapshot.dart';

/// Data Access Object for UsageSnapshot operations
class UsageSnapshotDao {
  final Database _db;

  UsageSnapshotDao(this._db);

  /// Insert a new usage snapshot
  Future<void> insert(UsageSnapshot snapshot) async {
    await upsert(snapshot);
  }

  /// Insert or replace a usage snapshot.
  Future<void> upsert(UsageSnapshot snapshot) async {
    await _db.insert(
      'usage_snapshots',
      snapshot.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get snapshot by ID
  Future<UsageSnapshot?> getById(String id) async {
    final maps = await _db.query(
      'usage_snapshots',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return UsageSnapshot.fromJson(maps.first);
  }

  /// Get snapshots for a provider within a period range
  Future<List<UsageSnapshot>> getByProviderAndPeriod({
    required String providerId,
    required String periodType,
    required DateTime start,
    required DateTime end,
  }) async {
    final maps = await _db.query(
      'usage_snapshots',
      where:
          'provider_id = ? AND period_type = ? AND period_start >= ? AND period_start <= ?',
      whereArgs: [
        providerId,
        periodType,
        start.millisecondsSinceEpoch,
        end.millisecondsSinceEpoch,
      ],
      orderBy: 'period_start DESC',
    );
    return maps.map((m) => UsageSnapshot.fromJson(m)).toList();
  }

  /// Get snapshots for a conversation
  Future<List<UsageSnapshot>> getByConversationId(String conversationId) async {
    final maps = await _db.query(
      'usage_snapshots',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => UsageSnapshot.fromJson(m)).toList();
  }

  /// Get snapshots for a specific period window.
  Future<List<UsageSnapshot>> getByPeriod({
    required String periodType,
    required DateTime periodStart,
  }) async {
    final maps = await _db.query(
      'usage_snapshots',
      where: 'period_type = ? AND period_start = ?',
      whereArgs: [periodType, periodStart.millisecondsSinceEpoch],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => UsageSnapshot.fromJson(m)).toList();
  }

  /// Get all snapshots, optionally filtered by period type
  Future<List<UsageSnapshot>> getAll({String? periodType}) async {
    final where = periodType != null ? 'period_type = ?' : null;
    final whereArgs = periodType != null ? [periodType] : null;
    final maps = await _db.query(
      'usage_snapshots',
      where: where,
      whereArgs: whereArgs,
      orderBy: 'period_start DESC',
    );
    return maps.map((m) => UsageSnapshot.fromJson(m)).toList();
  }

  /// Delete a snapshot by ID
  Future<void> delete(String id) async {
    await _db.delete(
      'usage_snapshots',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete old snapshots before a cutoff date
  Future<int> purgeBefore(DateTime cutoff) async {
    return await _db.delete(
      'usage_snapshots',
      where: 'created_at < ?',
      whereArgs: [cutoff.millisecondsSinceEpoch],
    );
  }
}
