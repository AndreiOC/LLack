import 'package:sqflite/sqflite.dart';
import '../../../domain/entities/entities.dart';

/// Result row from an FTS5 conversation search.
class ConversationSearchResult {
  final Conversation conversation;
  final String snippet;

  const ConversationSearchResult({required this.conversation, required this.snippet});
}

/// Result row from an FTS5 message search.
class MessageSearchResult {
  final String messageId;
  final String conversationId;
  final String snippet;

  const MessageSearchResult({
    required this.messageId,
    required this.conversationId,
    required this.snippet,
  });
}

/// Data Access Object for FTS5 full-text search.
///
/// Falls back to LIKE queries when FTS5 is unavailable (e.g. very old SQLite).
class SearchDao {
  final Database _db;
  bool? _fts5Available;

  SearchDao(this._db);

  /// Check whether FTS5 is supported by the SQLite build.
  Future<bool> get isFts5Available async {
    if (_fts5Available != null) return _fts5Available!;
    try {
      final result = await _db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='conversations_fts'",
      );
      _fts5Available = result.isNotEmpty;
      return _fts5Available!;
    } catch (_) {
      _fts5Available = false;
      return false;
    }
  }

  /// Search conversations by title using FTS5 with snippet highlighting.
  /// Falls back to LIKE if FTS5 tables don't exist.
  Future<List<ConversationSearchResult>> searchConversations(String query, {int limit = 50}) async {
    if (query.trim().isEmpty) return const [];

    if (await isFts5Available) {
      return _searchConversationsFts(query.trim(), limit: limit);
    }
    return _searchConversationsLike(query.trim(), limit: limit);
  }

  /// Search messages by content using FTS5 with snippet highlighting.
  /// Falls back to LIKE if FTS5 tables don't exist.
  Future<List<MessageSearchResult>> searchMessages(String query, {int limit = 50}) async {
    if (query.trim().isEmpty) return const [];

    if (await isFts5Available) {
      return _searchMessagesFts(query.trim(), limit: limit);
    }
    return _searchMessagesLike(query.trim(), limit: limit);
  }

  /// Unified search across conversations and messages.
  /// Returns conversation results enriched with message hits.
  Future<List<ConversationSearchResult>> searchAll(String query, {int limit = 50}) async {
    if (query.trim().isEmpty) return const [];
    final trimmed = query.trim();

    if (await isFts5Available) {
      // Use a UNION to get distinct conversations that match either title or message content
      final maps = await _db.rawQuery('''
        SELECT
          c.*,
          COALESCE(fts_conversations.snippet, fts_messages.snippet, '') AS snippet
        FROM conversations c
        LEFT JOIN (
          SELECT doc.rowid, snippet(conversations_fts, 0, '<mark>', '</mark>', '…', 32) AS snippet
          FROM conversations_fts
          JOIN conversations doc ON doc.rowid = conversations_fts.rowid
          WHERE conversations_fts MATCH ?
        ) fts_conversations ON fts_conversations.rowid = c.rowid
        LEFT JOIN (
          SELECT DISTINCT m.conversation_id,
            snippet(messages_fts, 0, '<mark>', '</mark>', '…', 32) AS snippet
          FROM messages_fts
          JOIN messages m ON m.rowid = messages_fts.rowid
          WHERE messages_fts MATCH ?
        ) fts_messages ON fts_messages.conversation_id = c.id
        WHERE c.deleted_at IS NULL
          AND (fts_conversations.rowid IS NOT NULL OR fts_messages.conversation_id IS NOT NULL)
        ORDER BY c.updated_at DESC
        LIMIT ?
      ''', [trimmed, trimmed, limit]);

      return maps.map((m) {
        final snippet = (m['snippet'] as String?) ?? '';
        // Remove snippet column before parsing conversation
        final json = Map<String, dynamic>.from(m)..remove('snippet');
        return ConversationSearchResult(
          conversation: Conversation.fromJson(json),
          snippet: snippet,
        );
      }).toList();
    }

    // Fallback: LIKE-only search
    return _searchConversationsLike(trimmed, limit: limit);
  }

  Future<List<ConversationSearchResult>> _searchConversationsFts(String query, {required int limit}) async {
    final maps = await _db.rawQuery('''
      SELECT c.*,
        snippet(conversations_fts, 0, '<mark>', '</mark>', '…', 32) AS snippet
      FROM conversations_fts
      JOIN conversations c ON c.rowid = conversations_fts.rowid
      WHERE conversations_fts MATCH ? AND c.deleted_at IS NULL
      ORDER BY rank
      LIMIT ?
    ''', [query, limit]);

    return maps.map((m) {
      final snippet = (m['snippet'] as String?) ?? '';
      final json = Map<String, dynamic>.from(m)..remove('snippet');
      return ConversationSearchResult(
        conversation: Conversation.fromJson(json),
        snippet: snippet,
      );
    }).toList();
  }

  Future<List<ConversationSearchResult>> _searchConversationsLike(String query, {required int limit}) async {
    final maps = await _db.query(
      'conversations',
      where: 'deleted_at IS NULL AND title LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'updated_at DESC',
      limit: limit,
    );
    return maps.map((m) {
      final title = m['title'] as String;
      return ConversationSearchResult(
        conversation: Conversation.fromJson(m),
        snippet: title,
      );
    }).toList();
  }

  Future<List<MessageSearchResult>> _searchMessagesFts(String query, {required int limit}) async {
    final maps = await _db.rawQuery('''
      SELECT m.id, m.conversation_id,
        snippet(messages_fts, 0, '<mark>', '</mark>', '…', 32) AS snippet
      FROM messages_fts
      JOIN messages m ON m.rowid = messages_fts.rowid
      WHERE messages_fts MATCH ?
      ORDER BY rank
      LIMIT ?
    ''', [query, limit]);

    return maps.map((m) => MessageSearchResult(
      messageId: m['id'] as String,
      conversationId: m['conversation_id'] as String,
      snippet: (m['snippet'] as String?) ?? '',
    )).toList();
  }

  Future<List<MessageSearchResult>> _searchMessagesLike(String query, {required int limit}) async {
    final maps = await _db.query(
      'messages',
      where: 'content_markdown LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return maps.map((m) => MessageSearchResult(
      messageId: m['id'] as String,
      conversationId: m['conversation_id'] as String,
      snippet: m['content_markdown'] as String,
    )).toList();
  }
}
