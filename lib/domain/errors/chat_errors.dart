/// Error categories for structured error handling per Section 7.4 of the spec.
///
/// Each category carries retry semantics and user-facing messaging.
sealed class ChatError implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const ChatError(this.message, {this.code, this.originalError});

  @override
  String toString() => 'ChatError: $message${code != null ? ' (code: $code)' : ''}';
}

/// Network-level errors: timeouts, DNS failures, no connectivity.
/// Retry: exponential backoff. User message: 'Check your connection'.
class NetworkError extends ChatError {
  final bool isRetryable;

  const NetworkError(super.message, {super.code, super.originalError, this.isRetryable = true});
}

/// Authentication/authorization errors: invalid API key, expired tokens.
/// Retry: never. User message: 'Check your API key'.
class AuthError extends ChatError {
  const AuthError(super.message, {super.code, super.originalError});
}

/// Provider-side errors: rate limits, model not found, server errors.
/// Retry: after backoff for rate limits, never for model-not-found.
class ProviderError extends ChatError {
  final bool isRetryable;

  const ProviderError(super.message, {super.code, super.originalError, this.isRetryable = false});
}

/// Rate limit errors: provider throttling.
/// Retry: after backoff. User message: 'Rate limited, retrying...'.
class RateLimitError extends ChatError {
  final Duration? retryAfter;

  const RateLimitError(super.message, {super.code, super.originalError, this.retryAfter});
}

/// Client-side errors: invalid request format, missing required fields.
/// Retry: never. User message: 'Invalid request'.
class ClientError extends ChatError {
  const ClientError(super.message, {super.code, super.originalError});
}

/// Validation errors: input validation, schema mismatch.
/// Retry: never. User message: 'Check your input'.
class ValidationError extends ChatError {
  const ValidationError(super.message, {super.code, super.originalError});
}

/// Unsupported model errors: model not available on provider.
/// Retry: never. User message: 'Model not available'.
class UnsupportedModelError extends ChatError {
  const UnsupportedModelError(super.message, {super.code, super.originalError});
}

/// Stream parse errors: malformed chunks from provider.
/// Retry: once, then fail. User message: 'Response format error'.
class StreamParseError extends ChatError {
  final String rawChunk;

  const StreamParseError(super.message, {super.code, super.originalError, required this.rawChunk});
}

/// Unexpected internal errors: catch-all for unknown failures.
/// Retry: never (needs investigation). User message: 'Something went wrong'.
class InternalError extends ChatError {
  const InternalError(super.message, {super.code, super.originalError});
}

/// Cancellation: user cancelled the stream.
/// Not really an error, but needs categorization for state management.
class CancellationError extends ChatError {
  const CancellationError() : super('Response cancelled.');
}
