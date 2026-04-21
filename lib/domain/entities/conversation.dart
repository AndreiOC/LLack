/// Conversation entity representing a chat session
class Conversation {
  static const Object _sentinel = Object();

  final String id;
  final String title;
  final String? selectedProviderId;
  final String? selectedModelId;
  final DateTime? pinnedAt;
  final DateTime? archivedAt;
  final DateTime? deletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Conversation({
    required this.id,
    required this.title,
    this.selectedProviderId,
    this.selectedModelId,
    this.pinnedAt,
    this.archivedAt,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        id: json['id'] as String,
        title: json['title'] as String,
        selectedProviderId: json['selected_provider_id'] as String?,
        selectedModelId: json['selected_model_id'] as String?,
        pinnedAt: json['pinned_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(json['pinned_at'] as int)
            : null,
        archivedAt: json['archived_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(json['archived_at'] as int)
            : null,
        deletedAt: json['deleted_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(json['deleted_at'] as int)
            : null,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'selected_provider_id': selectedProviderId,
        'selected_model_id': selectedModelId,
        'pinned_at': pinnedAt?.millisecondsSinceEpoch,
        'archived_at': archivedAt?.millisecondsSinceEpoch,
        'deleted_at': deletedAt?.millisecondsSinceEpoch,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory Conversation.create({
    required String id,
    String title = 'New Conversation',
    String? providerId,
    String? modelId,
  }) =>
      Conversation(
        id: id,
        title: title,
        selectedProviderId: providerId,
        selectedModelId: modelId,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  Conversation copyWith({
    String? id,
    String? title,
    Object? selectedProviderId = _sentinel,
    Object? selectedModelId = _sentinel,
    Object? pinnedAt = _sentinel,
    Object? archivedAt = _sentinel,
    Object? deletedAt = _sentinel,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Conversation(
        id: id ?? this.id,
        title: title ?? this.title,
        selectedProviderId: identical(selectedProviderId, _sentinel)
            ? this.selectedProviderId
            : selectedProviderId as String?,
        selectedModelId: identical(selectedModelId, _sentinel)
            ? this.selectedModelId
            : selectedModelId as String?,
        pinnedAt: identical(pinnedAt, _sentinel)
            ? this.pinnedAt
            : pinnedAt as DateTime?,
        archivedAt: identical(archivedAt, _sentinel)
            ? this.archivedAt
            : archivedAt as DateTime?,
        deletedAt: identical(deletedAt, _sentinel)
            ? this.deletedAt
            : deletedAt as DateTime?,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  bool get isPinned => pinnedAt != null;
  bool get isArchived => archivedAt != null;
  bool get isDeleted => deletedAt != null;
  bool get isActive => !isDeleted && !isArchived;
}
