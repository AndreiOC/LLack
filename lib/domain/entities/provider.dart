import 'dart:convert';

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

/// Provider entity representing an LLM provider configuration
class Provider {
  static const Object _sentinel = Object();

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
        kind: _providerKindFromStorage(json['kind'] as String?),
        displayName: json['display_name'] as String,
        baseUrl: json['base_url'] as String,
        apiKeyRef: json['api_key_ref'] as String?,
        defaultModelId: json['default_model_id'] as String?,
        headers: json['headers_json'] != null
            ? Map<String, String>.from(_decodeJsonMap(json['headers_json']))
            : {},
        settings: json['settings_json'] != null
            ? Map<String, dynamic>.from(_decodeJsonMap(json['settings_json']))
            : {},
        healthStatus: json['health_status'] != null
            ? _providerHealthStatusFromStorage(json['health_status'] as String?)
            : null,
        healthCheckedAt: json['health_checked_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(
                json['health_checked_at'] as int)
            : null,
        createdAt:
            DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int),
        deletedAt: json['deleted_at'] != null
            ? DateTime.fromMillisecondsSinceEpoch(json['deleted_at'] as int)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': _providerKindToStorage(kind),
        'display_name': displayName,
        'base_url': baseUrl,
        'api_key_ref': apiKeyRef,
        'default_model_id': defaultModelId,
        'headers_json': headers.isEmpty ? null : _encodeJsonMap(headers),
        'settings_json': settings.isEmpty ? null : _encodeJsonMap(settings),
        'health_status': healthStatus != null
            ? _providerHealthStatusToStorage(healthStatus!)
            : null,
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
    Object? apiKeyRef = _sentinel,
    Object? defaultModelId = _sentinel,
    Map<String, String>? headers,
    Map<String, dynamic>? settings,
    Object? healthStatus = _sentinel,
    Object? healthCheckedAt = _sentinel,
    DateTime? createdAt,
    DateTime? updatedAt,
    Object? deletedAt = _sentinel,
  }) =>
      Provider(
        id: id ?? this.id,
        kind: kind ?? this.kind,
        displayName: displayName ?? this.displayName,
        baseUrl: baseUrl ?? this.baseUrl,
        apiKeyRef: identical(apiKeyRef, _sentinel)
            ? this.apiKeyRef
            : apiKeyRef as String?,
        defaultModelId: identical(defaultModelId, _sentinel)
            ? this.defaultModelId
            : defaultModelId as String?,
        headers: headers ?? this.headers,
        settings: settings ?? this.settings,
        healthStatus: identical(healthStatus, _sentinel)
            ? this.healthStatus
            : healthStatus as ProviderHealthStatus?,
        healthCheckedAt: identical(healthCheckedAt, _sentinel)
            ? this.healthCheckedAt
            : healthCheckedAt as DateTime?,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        deletedAt: identical(deletedAt, _sentinel)
            ? this.deletedAt
            : deletedAt as DateTime?,
      );

  bool get isDeleted => deletedAt != null;
  bool get isHealthy => healthStatus == ProviderHealthStatus.healthy;
  bool get requiresApiKey => kind == ProviderKind.openaiCompatible;
  bool get isOllama => kind == ProviderKind.ollama;
}

Map<String, dynamic> _decodeJsonMap(Object value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  if (value is String && value.isNotEmpty) {
    final decoded = jsonDecode(value);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
  }
  return const {};
}

String _encodeJsonMap(Map<String, dynamic> value) {
  return jsonEncode(value);
}

ProviderKind _providerKindFromStorage(String? value) {
  switch (value) {
    case 'ollama':
      return ProviderKind.ollama;
    case 'openai_compatible':
    case 'openaiCompatible':
      return ProviderKind.openaiCompatible;
    default:
      return ProviderKind.openaiCompatible;
  }
}

String _providerKindToStorage(ProviderKind value) {
  switch (value) {
    case ProviderKind.ollama:
      return 'ollama';
    case ProviderKind.openaiCompatible:
      return 'openai_compatible';
  }
}

ProviderHealthStatus _providerHealthStatusFromStorage(String? value) {
  switch (value) {
    case 'healthy':
      return ProviderHealthStatus.healthy;
    case 'degraded':
      return ProviderHealthStatus.degraded;
    case 'unreachable':
      return ProviderHealthStatus.unreachable;
    case 'never_checked':
    case 'neverChecked':
    default:
      return ProviderHealthStatus.neverChecked;
  }
}

String _providerHealthStatusToStorage(ProviderHealthStatus value) {
  switch (value) {
    case ProviderHealthStatus.healthy:
      return 'healthy';
    case ProviderHealthStatus.degraded:
      return 'degraded';
    case ProviderHealthStatus.unreachable:
      return 'unreachable';
    case ProviderHealthStatus.neverChecked:
      return 'never_checked';
  }
}
