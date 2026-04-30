import 'provider.dart';

/// Spec section 6.5: provider forms are driven by local schema definitions
/// instead of hardcoded field-by-field screens.
enum ProviderFieldType {
  text,
  password,
  url,
  integer,
  double,
  dropdown,
  keyValueMap,
  checkbox,
}

class ProviderFieldOption {
  final String value;
  final String label;

  const ProviderFieldOption({
    required this.value,
    required this.label,
  });
}

class ProviderFieldSchema {
  final String id;
  final String label;
  final ProviderFieldType fieldType;
  final bool isRequired;
  final bool isSecure;
  final Object? defaultValue;
  final String? helpText;
  final double? minNumericValue;
  final double? maxNumericValue;
  final List<ProviderFieldOption> options;

  const ProviderFieldSchema({
    required this.id,
    required this.label,
    required this.fieldType,
    this.isRequired = false,
    this.isSecure = false,
    this.defaultValue,
    this.helpText,
    this.minNumericValue,
    this.maxNumericValue,
    this.options = const <ProviderFieldOption>[],
  });
}

class ProviderConfigurationSchema {
  final ProviderKind kind;
  final String title;
  final List<ProviderFieldSchema> fields;

  const ProviderConfigurationSchema({
    required this.kind,
    required this.title,
    required this.fields,
  });
}

class ProviderSchemaFieldIds {
  static const String displayName = 'display_name';
  static const String baseUrl = 'base_url';
  static const String apiKey = 'api_key';
  static const String headers = 'headers_json';
  static const String defaultModelId = 'default_model_id';
  static const String temperature = 'temperature';
  static const String maxTokens = 'max_tokens';
  static const String topP = 'top_p';
}

class ProviderConfigurationSchemas {
  static ProviderConfigurationSchema forKind(ProviderKind kind) {
    switch (kind) {
      case ProviderKind.ollama:
        return const ProviderConfigurationSchema(
          kind: ProviderKind.ollama,
          title: 'Ollama',
          fields: <ProviderFieldSchema>[
            ProviderFieldSchema(
              id: ProviderSchemaFieldIds.displayName,
              label: 'Display name',
              fieldType: ProviderFieldType.text,
              isRequired: true,
              defaultValue: 'Local Ollama',
              helpText: 'A readable label for the local or LAN endpoint.',
            ),
            ProviderFieldSchema(
              id: ProviderSchemaFieldIds.baseUrl,
              label: 'Ollama endpoint',
              fieldType: ProviderFieldType.url,
              isRequired: true,
              defaultValue: 'http://127.0.0.1:11434',
              helpText:
                  'Spec 6.3 default is http://127.0.0.1:11434. HTTP is allowed for local Ollama endpoints.',
            ),
            ProviderFieldSchema(
              id: ProviderSchemaFieldIds.defaultModelId,
              label: 'Default model',
              fieldType: ProviderFieldType.dropdown,
              isRequired: true,
              helpText: 'Used when a new conversation has not overridden the model.',
            ),
            ProviderFieldSchema(
              id: ProviderSchemaFieldIds.temperature,
              label: 'Temperature',
              fieldType: ProviderFieldType.double,
              defaultValue: 0.7,
              minNumericValue: 0,
              maxNumericValue: 2,
              helpText: 'Optional generation default. Spec FR-PRV-6.',
            ),
            ProviderFieldSchema(
              id: ProviderSchemaFieldIds.maxTokens,
              label: 'Max tokens',
              fieldType: ProviderFieldType.integer,
              minNumericValue: 1,
              helpText: 'Optional generation default. Spec FR-PRV-6.',
            ),
            ProviderFieldSchema(
              id: ProviderSchemaFieldIds.topP,
              label: 'Top P',
              fieldType: ProviderFieldType.double,
              defaultValue: 1.0,
              minNumericValue: 0,
              maxNumericValue: 1,
              helpText: 'Optional generation default. Spec FR-PRV-6.',
            ),
            ProviderFieldSchema(
              id: ProviderSchemaFieldIds.headers,
              label: 'Custom headers',
              fieldType: ProviderFieldType.keyValueMap,
              helpText: 'Optional generation default. Spec FR-PRV-6.',
            ),
          ],
        );
      case ProviderKind.openaiCompatible:
        return const ProviderConfigurationSchema(
          kind: ProviderKind.openaiCompatible,
          title: 'OpenAI-compatible',
          fields: <ProviderFieldSchema>[
            ProviderFieldSchema(
              id: ProviderSchemaFieldIds.displayName,
              label: 'Display name',
              fieldType: ProviderFieldType.text,
              isRequired: true,
              defaultValue: 'API Provider',
              helpText: 'A readable label for the remote provider.',
            ),
            ProviderFieldSchema(
              id: ProviderSchemaFieldIds.baseUrl,
              label: 'Base URL',
              fieldType: ProviderFieldType.url,
              isRequired: true,
              defaultValue: 'https://api.openai.com/v1',
              helpText:
                  'Spec 6.4 expects /models and /chat/completions under this base URL.',
            ),
            ProviderFieldSchema(
              id: ProviderSchemaFieldIds.apiKey,
              label: 'API key',
              fieldType: ProviderFieldType.password,
              isRequired: true,
              isSecure: true,
              helpText:
                  'Stored in platform secure storage. Only a reference is persisted in SQLite.',
            ),
            ProviderFieldSchema(
              id: ProviderSchemaFieldIds.defaultModelId,
              label: 'Default model',
              fieldType: ProviderFieldType.dropdown,
              isRequired: true,
              helpText: 'Used when a new conversation has not overridden the model.',
            ),
            ProviderFieldSchema(
              id: ProviderSchemaFieldIds.headers,
              label: 'Custom headers',
              fieldType: ProviderFieldType.keyValueMap,
              helpText:
                  'Optional request headers. Spec FR-PRV-2 requires duplicate-key prevention.',
            ),
            ProviderFieldSchema(
              id: ProviderSchemaFieldIds.temperature,
              label: 'Temperature',
              fieldType: ProviderFieldType.double,
              defaultValue: 0.7,
              minNumericValue: 0,
              maxNumericValue: 2,
              helpText: 'Optional generation default. Spec FR-PRV-6.',
            ),
            ProviderFieldSchema(
              id: ProviderSchemaFieldIds.maxTokens,
              label: 'Max tokens',
              fieldType: ProviderFieldType.integer,
              minNumericValue: 1,
              helpText: 'Optional generation default. Spec FR-PRV-6.',
            ),
            ProviderFieldSchema(
              id: ProviderSchemaFieldIds.topP,
              label: 'Top P',
              fieldType: ProviderFieldType.double,
              defaultValue: 1.0,
              minNumericValue: 0,
              maxNumericValue: 1,
              helpText: 'Optional generation default. Spec FR-PRV-6.',
            ),
          ],
        );
    }
  }
}
