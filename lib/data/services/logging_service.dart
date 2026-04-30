import 'dart:developer' as developer;

/// Log level severity.
enum LogLevel { debug, info, warning, error }

/// Categories for structured logging.
enum LogCategory {
  database,
  network,
  chat,
  provider,
  outbox,
  usage,
  ui,
  general,
}

/// Structured logging service with secret redaction.
///
/// All logs go through [developer.log] so they appear in Dart DevTools.
/// Secrets are redacted by matching common header names and API key patterns.
class LoggingService {
  static const List<String> _secretKeys = [
    'authorization',
    'x-api-key',
    'api-key',
    'api_key',
    'apikey',
    'token',
    'access_token',
    'secret',
    'password',
    'key',
  ];

  static const List<String> _sensitivePatterns = [
    r'sk-[a-zA-Z0-9]{20,}',
    r'Bearer\s+[a-zA-Z0-9_\-]+\.[a-zA-Z0-9_\-]+\.[a-zA-Z0-9_\-]+',
    r'Bearer\s+\S+',
  ];

  static LoggingService? _instance;
  static LoggingService get instance => _instance ??= LoggingService._();

  bool _enabled = true;
  LogLevel _minLevel = LogLevel.debug;

  LoggingService._();

  /// Enable or disable logging globally.
  set enabled(bool value) => _enabled = value;

  /// Set minimum log level.
  set minLevel(LogLevel level) => _minLevel = level;

  void log(
    String message, {
    LogLevel level = LogLevel.info,
    LogCategory category = LogCategory.general,
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? data,
  }) {
    if (!_enabled) return;
    if (level.index < _minLevel.index) return;

    final redactedMessage = redact(message);
    final redactedData = data?.map((k, v) => MapEntry(k, redact('$v')));

    developer.log(
      redactedMessage,
      name: 'foss_chat.${category.name}',
      level: _levelValue(level),
      error: error,
      stackTrace: stackTrace,
      time: DateTime.now(),
    );

    if (redactedData != null && redactedData.isNotEmpty) {
      developer.log(
        'context: $redactedData',
        name: 'foss_chat.${category.name}',
        level: _levelValue(level),
        time: DateTime.now(),
      );
    }
  }

  void debug(String message, {LogCategory category = LogCategory.general, Map<String, Object?>? data}) =>
      log(message, level: LogLevel.debug, category: category, data: data);

  void info(String message, {LogCategory category = LogCategory.general, Map<String, Object?>? data}) =>
      log(message, level: LogLevel.info, category: category, data: data);

  void warning(String message, {LogCategory category = LogCategory.general, Object? error, StackTrace? stackTrace, Map<String, Object?>? data}) =>
      log(message, level: LogLevel.warning, category: category, error: error, stackTrace: stackTrace, data: data);

  void error(String message, {LogCategory category = LogCategory.general, Object? error, StackTrace? stackTrace, Map<String, Object?>? data}) =>
      log(message, level: LogLevel.error, category: category, error: error, stackTrace: stackTrace, data: data);

  /// Redact sensitive header values from a map.
  static Map<String, String> redactHeaders(Map<String, String> headers) {
    final sensitiveKeys = {
      'authorization',
      'api-key',
      'x-api-key',
      'bearer',
      'token',
      'apikey',
      'x-apikey',
      'secret',
      'x-secret',
    };
    return headers.map((key, value) {
      if (sensitiveKeys.contains(key.toLowerCase())) {
        return MapEntry(key, '[REDACTED]');
      }
      return MapEntry(key, value);
    });
  }

  /// Redact secrets from a string.
  static String redact(String input) {
    var result = input;

    // Redact JSON/object-style secrets: "api_key": "secret_value"
    for (final key in _secretKeys) {
      const quoted = r'(["' "'" r']?)';
      const endValue = r'[^"' "'" r'\s,}\]]+(?:\s+[^"' "'" r'\s,}\]]+)*';
      final pattern = RegExp(
        '$quoted${RegExp.escape(key)}$quoted' r'\s*[:=]\s*' '$quoted($endValue)',
        caseSensitive: false,
      );
      result = result.replaceAllMapped(pattern, (match) {
        return '${match.group(1)}$key${match.group(1)}: [REDACTED]';
      });
    }

    // Redact known token patterns
    for (final pattern in _sensitivePatterns) {
      result = result.replaceAllMapped(
        RegExp(pattern, caseSensitive: false),
        (match) => '[REDACTED ${match.group(0)?.substring(0, 6)}...]',
      );
    }

    return result;
  }

  static int _levelValue(LogLevel level) {
    return switch (level) {
      LogLevel.debug => 500,
      LogLevel.info => 800,
      LogLevel.warning => 900,
      LogLevel.error => 1000,
    };
  }
}

/// Extension for convenient logging in any class.
extension Loggable on Object {
  LoggingService get logger => LoggingService.instance;
}
