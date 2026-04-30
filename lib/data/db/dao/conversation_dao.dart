import 'package:sqflite/sqflite.dart';
import '../../../domain/entities/entities.dart';

/// Data Access Object for Conversation operations
class ConversationDao {
  final Database _db;

  ConversationDao(this._db);

  /// Get all active conversations ordered by pinned first, then updated
  Future<List<Conversation>> getAllActive() async {
    final maps = await _db.query(
      'conversations',
      where: 'deleted_at IS NULL AND archived_at IS NULL',
      orderBy: 'pinned_at DESC, updated_at DESC',
    );
    return maps.map((m) => Conversation.fromJson(m)).toList();
  }

  /// Get conversations with pagination
  Future<List<Conversation>> getPaginated({
    int limit = 20,
    int offset = 0,
  }) async {
    final maps = await _db.query(
      'conversations',
      where: 'deleted_at IS NULL AND archived_at IS NULL',
      orderBy: 'pinned_at DESC, updated_at DESC',
      limit: limit,
      offset: offset,
    );
    return maps.map((m) => Conversation.fromJson(m)).toList();
  }

  /// Get conversation by ID
  Future<Conversation?> getById(String id) async {
    final maps = await _db.query(
      'conversations',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Conversation.fromJson(maps.first);
  }

  /// Insert new conversation
  Future<void> insert(Conversation conversation) async {
    await _db.insert('conversations', conversation.toJson());
  }

  /// Update conversation
  Future<void> update(Conversation conversation) async {
    await _db.update(
      'conversations',
      conversation.toJson(),
      where: 'id = ?',
      whereArgs: [conversation.id],
    );
  }

  /// Soft delete conversation
  Future<void> softDelete(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      'conversations',
      {'deleted_at': now, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Restore a soft-deleted conversation
  Future<void> restore(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      'conversations',
      {'deleted_at': null, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Purge conversations that have been soft-deleted for longer than the retention threshold.
  Future<int> purgeOldDeleted(Duration threshold) async {
    final cutoff = DateTime.now().subtract(threshold).millisecondsSinceEpoch;
    final result = await _db.delete(
      'conversations',
      where: 'deleted_at IS NOT NULL AND deleted_at < ?',
      whereArgs: [cutoff],
    );
    return result;
  }

  /// Archive conversation
  Future<void> archive(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      'conversations',
      {'archived_at': now, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Restore archived conversation
  Future<void> unarchive(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      'conversations',
      {'archived_at': null, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Pin conversation
  Future<void> pin(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      'conversations',
      {'pinned_at': now, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Unpin conversation
  Future<void> unpin(String id) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      'conversations',
      {'pinned_at': null, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Update conversation title
  Future<void> updateTitle(String id, String title) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      'conversations',
      {'title': title, 'updated_at': now},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Update selected provider/model
  Future<void> updateProviderModel(
    String id,
    String providerId,
    String modelId,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      'conversations',
      {
        'selected_provider_id': providerId,
        'selected_model_id': modelId,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get count of active conversations
  Future<int> getActiveCount() async {
    final result = await _db.rawQuery(
      "SELECT COUNT(*) as count FROM conversations WHERE deleted_at IS NULL AND archived_at IS NULL",
    );
    return result.first['count'] as int? ?? 0;
  }

  /// Count all non-deleted conversations, including archived ones.
  Future<int> getExistingCount() async {
    final result = await _db.rawQuery(
      "SELECT COUNT(*) as count FROM conversations WHERE deleted_at IS NULL",
    );
    return result.first['count'] as int? ?? 0;
  }

  /// Count conversations currently assigned to a provider.
  Future<int> countUsingProvider(String providerId) async {
    final result = await _db.rawQuery(
      'SELECT COUNT(*) as count FROM conversations WHERE selected_provider_id = ? AND deleted_at IS NULL',
      [providerId],
    );
    return result.first['count'] as int? ?? 0;
  }

  /// Spec FR-PRV-1: deleting a provider in use must offer a fallback behavior
  /// for existing conversations instead of leaving them in a broken state.
  Future<void> reassignProvider(
    String providerId, {
    String? fallbackProviderId,
    String? fallbackModelId,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      'conversations',
      {
        'selected_provider_id': fallbackProviderId,
        'selected_model_id': fallbackProviderId == null ? null : fallbackModelId,
        'updated_at': now,
      },
      where: 'selected_provider_id = ? AND deleted_at IS NULL',
      whereArgs: [providerId],
    );
  }

  /// Search conversations by title
  Future<List<Conversation>> searchByTitle(String query) async {
    final maps = await _db.query(
      'conversations',
      where: 'deleted_at IS NULL AND title LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'updated_at DESC',
    );
    return maps.map((m) => Conversation.fromJson(m)).toList();
  }
}
