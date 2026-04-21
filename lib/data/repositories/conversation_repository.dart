import '../../data/db/dao/dao.dart';
import '../../domain/entities/entities.dart';
import 'package:uuid/uuid.dart';

/// Repository for Conversation operations
class ConversationRepository {
  final ConversationDao _dao;
  static const Uuid _uuid = Uuid();

  ConversationRepository(this._dao);

  /// Get all active conversations
  Future<List<Conversation>> getAll() => _dao.getAllActive();

  /// Get paginated conversations
  Future<List<Conversation>> getPaginated({int limit = 20, int offset = 0}) {
    return _dao.getPaginated(limit: limit, offset: offset);
  }

  /// Get conversation by ID
  Future<Conversation?> getById(String id) => _dao.getById(id);

  /// Create new conversation
  Future<Conversation> create({
    String title = 'New Conversation',
    String? providerId,
    String? modelId,
  }) async {
    final id = _generateId();
    final conversation = Conversation.create(
      id: id,
      title: title,
      providerId: providerId,
      modelId: modelId,
    );
    await _dao.insert(conversation);
    return conversation;
  }

  /// Update conversation
  Future<void> update(Conversation conversation) {
    return _dao.update(conversation);
  }

  /// Update title
  Future<void> updateTitle(String id, String title) {
    return _dao.updateTitle(id, title);
  }

  /// Soft delete
  Future<void> delete(String id) => _dao.softDelete(id);

  /// Archive conversation
  Future<void> archive(String id) => _dao.archive(id);

  /// Toggle archive state
  Future<void> toggleArchive(String id) async {
    final conversation = await _dao.getById(id);
    if (conversation == null) {
      return;
    }

    if (conversation.isArchived) {
      await _dao.unarchive(id);
      return;
    }

    await _dao.archive(id);
  }

  /// Pin conversation
  Future<void> pin(String id) => _dao.pin(id);

  /// Unpin conversation
  Future<void> unpin(String id) => _dao.unpin(id);

  /// Toggle pin state
  Future<void> togglePin(String id) async {
    final conversation = await _dao.getById(id);
    if (conversation == null) {
      return;
    }

    if (conversation.isPinned) {
      await _dao.unpin(id);
      return;
    }

    await _dao.pin(id);
  }

  /// Update selected provider/model
  Future<void> setProviderModel(String id, String providerId, String modelId) {
    return _dao.updateProviderModel(id, providerId, modelId);
  }

  /// Search by title
  Future<List<Conversation>> search(String query) => _dao.searchByTitle(query);

  /// Get active count
  Future<int> getCount() => _dao.getActiveCount();

  String _generateId() {
    return _uuid.v4();
  }
}
