import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import '../../../domain/entities/entities.dart';

/// Data Access Object for Message operations
class MessageDao {
  final Database _db;

  MessageDao(this._db);

  /// Get messages for a conversation ordered by sequence
  Future<List<Message>> getByConversationId(String conversationId) async {
    final maps = await _db.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'sequence_no ASC',
    );
    return maps.map((m) => Message.fromJson(m)).toList();
  }

  /// Get messages for a conversation with pagination
  Future<List<Message>> getByConversationIdPaginated(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) async {
    final maps = await _db.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'sequence_no ASC',
      limit: limit,
      offset: offset,
    );
    return maps.map((m) => Message.fromJson(m)).toList();
  }

  /// Get message by ID
  Future<Message?> getById(String id) async {
    final maps = await _db.query(
      'messages',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Message.fromJson(maps.first);
  }

  /// Insert new message
  Future<void> insert(Message message) async {
    await _db.insert('messages', message.toJson());
  }

  /// Insert multiple messages in a transaction
  Future<void> insertBatch(List<Message> messages) async {
    final batch = _db.batch();
    for (final message in messages) {
      batch.insert('messages', message.toJson());
    }
    await batch.commit(noResult: true);
  }

  /// Update message
  Future<void> update(Message message) async {
    await _db.update(
      'messages',
      message.toJson(),
      where: 'id = ?',
      whereArgs: [message.id],
    );
  }

  /// Update message content (for streaming)
  Future<void> updateContent(
      String id, String content, MessageStatus status) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      'messages',
      {
        'content_markdown': content,
        'status': status.name,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Update message status
  Future<void> updateStatus(String id, MessageStatus status) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      'messages',
      {
        'status': status.name,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Update streaming message with partial content
  Future<void> updateStreamingContent(String id, String content) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      'messages',
      {
        'content_markdown': content,
        'updated_at': now,
      },
      where: 'id = ? AND status = ?',
      whereArgs: [id, MessageStatus.streaming.name],
    );
  }

  /// Finalize streaming message
  Future<void> finalizeStreaming(
    String id,
    String content,
    MessageStatus status,
    Map<String, dynamic>? metadata,
    int? inputTokens,
    int? outputTokens,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.update(
      'messages',
      {
        'content_markdown': content,
        'status': status.name,
        'response_metadata_json':
            metadata != null ? jsonEncode(metadata) : null,
        'input_tokens': inputTokens,
        'output_tokens': outputTokens,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Get next sequence number for a conversation
  Future<int> getNextSequenceNo(String conversationId) async {
    final result = await _db.rawQuery(
      'SELECT MAX(sequence_no) as max_seq FROM messages WHERE conversation_id = ?',
      [conversationId],
    );
    final maxSeq = result.first['max_seq'] as int?;
    return (maxSeq ?? 0) + 1;
  }

  /// Delete messages for a conversation
  Future<void> deleteByConversationId(String conversationId) async {
    await _db.delete(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
    );
  }

  /// Delete single message
  Future<void> delete(String id) async {
    await _db.delete(
      'messages',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Search messages by content
  Future<List<Message>> searchByContent(String query) async {
    final maps = await _db.query(
      'messages',
      where: 'content_markdown LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => Message.fromJson(m)).toList();
  }

  /// Get messages in generation group (for edit branching)
  Future<List<Message>> getByGenerationGroup(String groupId) async {
    final maps = await _db.query(
      'messages',
      where: 'generation_group_id = ?',
      whereArgs: [groupId],
      orderBy: 'sequence_no ASC',
    );
    return maps.map((m) => Message.fromJson(m)).toList();
  }
}
