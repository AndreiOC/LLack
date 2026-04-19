import 'package:sqflite/sqflite.dart';
import '../../domain/entities/entities.dart';

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
      'SELECT COUNT(*) as count FROM conversations WHERE deleted_at IS NULL',
    );
    return result.first['count'] as int? ?? 0;
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
