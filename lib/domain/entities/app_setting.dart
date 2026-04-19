/// App setting entity for application configuration
class AppSetting {
  final String key;
  final dynamic value;
  final DateTime updatedAt;

  AppSetting({
    required this.key,
    required this.value,
    required this.updatedAt,
  });

  factory AppSetting.fromJson(Map<String, dynamic> json) => AppSetting(
        key: json['key'] as String,
        value: json['value_json'],
        updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int),
      );

  Map<String, dynamic> toJson() => {
        'key': key,
        'value_json': value,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  factory AppSetting.bool({
    required String key,
    required bool value,
  }) => AppSetting(
        key: key,
        value: value,
        updatedAt: DateTime.now(),
      );

  factory AppSetting.string({
    required String key,
    required String? value,
  }) => AppSetting(
        key: key,
        value: value,
        updatedAt: DateTime.now(),
      );

  factory AppSetting.int({
    required String key,
    required int? value,
  }) => AppSetting(
        key: key,
        value: value,
        updatedAt: DateTime.now(),
      );

  AppSetting copyWith({
    String? key,
    dynamic value,
    DateTime? updatedAt,
  }) => AppSetting(
        key: key ?? this.key,
        value: value ?? this.value,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  bool get asBool => value == true || value == 'true';
  String? get asString => value?.toString();
  int? get asInt => value is int ? value : int.tryParse(value?.toString() ?? '');
}

/// Predefined app setting keys
class AppSettingKeys {
  static const String hasCompletedOnboarding = 'has_completed_onboarding';
  static const String skipCloudProviders = 'skip_cloud_providers';
  static const String monthlySpendThreshold = 'monthly_spend_threshold';
  static const String showCodeLineNumbers = 'show_code_line_numbers';
  static const String lastSuccessfulOllamaEndpoint = 'last_successful_ollama_endpoint';
}