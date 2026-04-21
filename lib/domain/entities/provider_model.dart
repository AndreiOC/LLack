/// Provider model entity representing an available model from a provider
class ProviderModel {
  final String id;
  final String providerId;
  final String remoteModelId;
  final String displayName;
  final int? contextWindow;
  final bool supportsStreaming;
  final bool supportsTools;
  final DateTime? lastUsedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProviderModel({
    required this.id,
    required this.providerId,
    required this.remoteModelId,
    required this.displayName,
    this.contextWindow,
    this.supportsStreaming = true,
    this.supportsTools = false,
    this.lastUsedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProviderModel.fromJson(Map<String, dynamic> json) => ProviderModel(
        id: json['id'] as String,
        providerId: json['provider_id'] as String,
        remoteModelId: json['remote_model_id'] as String,
        displayName: json['display_name'] as String,
        contextWindow: json['context_window'] as int?,
        supportsStreaming: (json['supports_streaming'] as int? ?? 1) == 1,
        supportsTools: (json['supports_tools'] as int? ?? 0) == 1,
        lastUsedAt: json['last_used_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(json['last_used_at'] as int)
            : null,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'provider_id': providerId,
        'remote_model_id': remoteModelId,
        'display_name': displayName,
        'context_window': contextWindow,
        'supports_streaming': supportsStreaming ? 1 : 0,
        'supports_tools': supportsTools ? 1 : 0,
        'last_used_at': lastUsedAt?.millisecondsSinceEpoch,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory ProviderModel.fromProviderResponse({
    required String id,
    required String providerId,
    required String remoteModelId,
    required String displayName,
    int? contextWindow,
    bool supportsStreaming = true,
    bool supportsTools = false,
  }) =>
      ProviderModel(
        id: id,
        providerId: providerId,
        remoteModelId: remoteModelId,
        displayName: displayName,
        contextWindow: contextWindow,
        supportsStreaming: supportsStreaming,
        supportsTools: supportsTools,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  ProviderModel copyWith({
    String? id,
    String? providerId,
    String? remoteModelId,
    String? displayName,
    int? contextWindow,
    bool? supportsStreaming,
    bool? supportsTools,
    DateTime? lastUsedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      ProviderModel(
        id: id ?? this.id,
        providerId: providerId ?? this.providerId,
        remoteModelId: remoteModelId ?? this.remoteModelId,
        displayName: displayName ?? this.displayName,
        contextWindow: contextWindow ?? this.contextWindow,
        supportsStreaming: supportsStreaming ?? this.supportsStreaming,
        supportsTools: supportsTools ?? this.supportsTools,
        lastUsedAt: lastUsedAt ?? this.lastUsedAt,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  String get shortName => displayName.length > 30
      ? '${displayName.substring(0, 27)}...'
      : displayName;
}
