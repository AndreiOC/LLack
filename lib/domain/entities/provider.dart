/// Provider entity representing an LLM provider configuration
class Provider {
  final String id;
  final ProviderKind kind;
  final String displayName;
  final String baseUrl;
  final String? apiKeyRef;
  final String? defaultModelId;
  final Map<String, String> headers;
  final Map<String, dynamic> settings;
  final ProviderHealthStatus? healthStatus;
  final DateTime? healthCheckedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  Provider({
    required this.id,
    required this.kind,
    required this.displayName,
    required this.baseUrl,
    this.apiKeyRef,
    this.defaultModelId,
    this.headers = const {},
    this.settings = const {},
    this.healthStatus,
    this.healthCheckedAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory Provider.fromJson(Map<String, dynamic> json) => Provider(
        id: json['id'] as String,
        kind: ProviderKind.values.firstWhere(
          (e) => e.name == json['kind'],
          orElse: () => ProviderKind.openaiCompatible,
        ),
        displayName: json['display_name'] as String,
        baseUrl: json['base_url'] as String,
        apiKeyRef: json['api_key_ref'] as String?,
        defaultModelId: json['default_model_id'] as String?,
        headers: json['headers_json'] != null
            ? Map<String, String>.from(json['headers_json'] as Map)
            : {},
        settings: json['settings_json'] != null
            ? Map<String, dynamic>.from(json['settings_json'] as Map)
            : {},
        healthStatus: json['health_status'] != null
            ? ProviderHealthStatus.values.firstWhere(
                (e) => e.name == json['health_status'],
                orElse: () => ProviderHealthStatus.neverChecked,
              )
            : null,
        healthCheckedAt: json['health_checked_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(json['health_checked_at'] as int)
            : null,
        createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
        updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int),
        deletedAt: json['deleted_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(json['deleted_at'] as int)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'display_name': displayName,
        'base_url': baseUrl,
        'api_key_ref': apiKeyRef,
        'default_model_id': defaultModelId,
        'headers_json': headers,
        'settings_json': settings,
        'health_status': healthStatus?.name,
        'health_checked_at': healthCheckedAt?.millisecondsSinceEpoch,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
        'deleted_at': deletedAt?.millisecondsSinceEpoch,
      };

  factory Provider.empty() => Provider(
        id: '',
        kind: ProviderKind.openaiCompatible,
        displayName: '',
        baseUrl: '',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  Provider copyWith({
    String? id,
    ProviderKind? kind,
    String? displayName,
    String? baseUrl,
    String? apiKeyRef,
    String? defaultModelId,
    Map<String, String>? headers,
    Map<String, dynamic>? settings,
    ProviderHealthStatus? healthStatus,
    DateTime? healthCheckedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? deletedAt,
  }) => Provider(
        id: id ?? this.id,
        kind: kind ?? this.kind,
        displayName: displayName ?? this.displayName,
        baseUrl: baseUrl ?? this.baseUrl,
        apiKeyRef: apiKeyRef ?? this.apiKeyRef,
        defaultModelId: defaultModelId ?? this.defaultModelId,
        headers: headers ?? this.headers,
        settings: settings ?? this.settings,
        healthStatus: healthStatus ?? this.healthStatus,
        healthCheckedAt: healthCheckedAt ?? this.healthCheckedAt,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: deletedAt ?? this.deletedAt,
      );

  bool get isDeleted => deletedAt != null;
  bool get isHealthy => healthStatus == ProviderHealthStatus.healthy;
  bool get requiresApiKey => kind == ProviderKind.openaiCompatible;
  bool get isOllama => kind == ProviderKind.ollama;
}

/// Provider kind enum
enum ProviderKind {
  ollama,
  openaiCompatible,
}

/// Provider health status enum
enum ProviderHealthStatus {
  healthy,
  degraded,
  unreachable,
  neverChecked,
}