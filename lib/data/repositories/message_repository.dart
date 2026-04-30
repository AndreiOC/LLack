import '../../data/db/dao/dao.dart';
import '../../domain/entities/entities.dart';
import 'package:uuid/uuid.dart';

/// Repository for Message operations
class MessageRepository {
  final MessageDao _dao;
  static const Uuid _uuid = Uuid();

  MessageRepository(this._dao);

  /// Get messages for a conversation
  Future<List<Message>> getByConversationId(String conversationId) {
    return _dao.getByConversationId(conversationId);
  }

  /// Get paginated messages
  Future<List<Message>> getPaginated(
    String conversationId, {
    int limit = 50,
    int offset = 0,
  }) {
    return _dao.getByConversationIdPaginated(
      conversationId,
      limit: limit,
      offset: offset,
    );
  }

  /// Get message by ID
  Future<Message?> getById(String id) => _dao.getById(id);

  /// Send user message and create assistant placeholder
  Future<(Message userMessage, Message assistantMessage)> sendMessage({
    required String conversationId,
    required String content,
    String? providerId,
    String? modelId,
  }) async {
    return _dao.transaction((txnDao) async {
      final nextSeq = await txnDao.getNextSequenceNo(conversationId);

      // Create user message
      final userMessage = Message.user(
        id: _generateId(),
        conversationId: conversationId,
        content: content,
        sequenceNo: nextSeq,
      );

      // Create assistant placeholder
      final assistantMessage = Message.assistantPlaceholder(
        id: _generateId(),
        conversationId: conversationId,
        sequenceNo: nextSeq + 1,
        providerId: providerId,
        modelId: modelId,
      );

      await txnDao.insertBatch([userMessage, assistantMessage]);
      return (userMessage, assistantMessage);
    });
  }

  /// Update streaming content
  Future<void> updateStreamingContent(String id, String content) {
    return _dao.updateStreamingContent(id, content);
  }

  /// Finalize streaming message
  Future<void> finalizeStreaming({
    required String id,
    required String content,
    required MessageStatus status,
    Map<String, dynamic>? metadata,
    int? inputTokens,
    int? outputTokens,
    int? estimatedCostMicros,
    bool isEstimated = false,
  }) {
    return _dao.finalizeStreaming(
      id,
      content,
      status,
      metadata,
      inputTokens,
      outputTokens,
      estimatedCostMicros,
      isEstimated,
    );
  }

  /// Update message status
  Future<void> updateStatus(String id, MessageStatus status) {
    return _dao.updateStatus(id, status);
  }

  /// Mark as cancelled
  Future<void> cancel(String id) =>
      _dao.updateStatus(id, MessageStatus.cancelled);

  /// Search messages
  Future<List<Message>> search(String query) => _dao.searchByContent(query);

  /// Delete message
  Future<void> delete(String id) => _dao.delete(id);

  /// Edit a user message and create a new assistant placeholder for the branch.
  /// Supersedes the original message and all subsequent messages (spec FR-CHT-7).
  Future<(Message editedUserMessage, Message assistantMessage)> editMessage({
    required String conversationId,
    required String originalMessageId,
    required int originalSequenceNo,
    required String newContent,
    String? providerId,
    String? modelId,
  }) async {
    return _dao.transaction((txnDao) async {
      await txnDao.supersedeFromMessage(
        originalMessageId,
        conversationId,
        originalSequenceNo,
      );

      final nextSeq = await txnDao.getNextSequenceNo(conversationId);
      final groupId = _generateId();

      // Create edited user message
      final editedMessage = Message.user(
        id: _generateId(),
        conversationId: conversationId,
        content: newContent,
        sequenceNo: nextSeq,
      ).copyWith(
        editedFromMessageId: originalMessageId,
        generationGroupId: groupId,
      );

      // Create assistant placeholder
      final assistantMessage = Message.assistantPlaceholder(
        id: _generateId(),
        conversationId: conversationId,
        sequenceNo: nextSeq + 1,
        providerId: providerId,
        modelId: modelId,
      ).copyWith(
        generationGroupId: groupId,
      );

      await txnDao.insertBatch([editedMessage, assistantMessage]);
      return (editedMessage, assistantMessage);
    });
  }

  String _generateId() {
    return _uuid.v4();
  }
}
