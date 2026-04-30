import 'dart:math' as math;

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

    return _searchAllLike(trimmed, limit: limit);
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
        snippet: _buildLikeSnippet(title, query),
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
      snippet: _buildLikeSnippet(
        (m['content_markdown'] as String?) ?? '',
        query,
      ),
    )).toList();
  }

  Future<List<ConversationSearchResult>> _searchAllLike(
    String query, {
    required int limit,
  }) async {
    final titleResults = await _searchConversationsLike(query, limit: limit);
    final messageResults = await _searchMessagesLike(query, limit: limit);
    final combined = <String, ConversationSearchResult>{
      for (final result in titleResults) result.conversation.id: result,
    };

    final conversationIds = messageResults
        .map((result) => result.conversationId)
        .where((id) => !combined.containsKey(id))
        .toSet()
        .toList();
    if (conversationIds.isNotEmpty) {
      final conversationsById = await _fetchConversationsByIds(conversationIds);
      for (final result in messageResults) {
        if (combined.containsKey(result.conversationId)) {
          continue;
        }
        final conversation = conversationsById[result.conversationId];
        if (conversation == null) {
          continue;
        }
        combined[conversation.id] = ConversationSearchResult(
          conversation: conversation,
          snippet: result.snippet,
        );
        if (combined.length >= limit) {
          break;
        }
      }
    }

    final results = combined.values.toList()
      ..sort(
        (left, right) => right.conversation.updatedAt.compareTo(
          left.conversation.updatedAt,
        ),
      );
    return results.take(limit).toList();
  }

  Future<Map<String, Conversation>> _fetchConversationsByIds(
    List<String> conversationIds,
  ) async {
    if (conversationIds.isEmpty) {
      return const <String, Conversation>{};
    }

    final placeholders = List.filled(conversationIds.length, '?').join(', ');
    final maps = await _db.rawQuery(
      '''
        SELECT *
        FROM conversations
        WHERE deleted_at IS NULL
          AND id IN ($placeholders)
      ''',
      conversationIds,
    );
    return <String, Conversation>{
      for (final map in maps)
        (map['id'] as String): Conversation.fromJson(map),
    };
  }

  String _buildLikeSnippet(String content, String query) {
    final normalized = content.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) {
      return '';
    }

    final lowerContent = normalized.toLowerCase();
    final lowerQuery = query.toLowerCase();
    final matchIndex = lowerContent.indexOf(lowerQuery);
    if (matchIndex == -1) {
      return normalized.length <= 96
          ? normalized
          : '${normalized.substring(0, 93)}...';
    }

    final start = math.max(0, matchIndex - 36);
    final end = math.min(
      normalized.length,
      matchIndex + query.length + 44,
    );
    final prefix = start > 0 ? '…' : '';
    final suffix = end < normalized.length ? '…' : '';
    final before = normalized.substring(start, matchIndex);
    final match = normalized.substring(matchIndex, matchIndex + query.length);
    final after = normalized.substring(matchIndex + query.length, end);
    return '$prefix$before<mark>$match</mark>$after$suffix';
  }
}
