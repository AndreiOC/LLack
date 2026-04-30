import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for securely storing sensitive data
class SecureStorageService {
  final FlutterSecureStorage _storage;

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                encryptedSharedPreferences: true,
              ),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  /// Store a secret value
  Future<void> write(String key, String value) async {
    await _storage.write(key: key, value: value);
  }

  /// Read a secret value
  Future<String?> read(String key) async {
    return await _storage.read(key: key);
  }

  /// Delete a secret value
  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }

  /// Store a provider's API key
  Future<void> storeProviderApiKey(String providerId, String apiKey) async {
    await write('provider_api_key_$providerId', apiKey);
  }

  /// Read a provider's API key
  Future<String?> getProviderApiKey(String providerId) async {
    return await read('provider_api_key_$providerId');
  }

  /// Delete a provider's API key
  Future<void> deleteProviderApiKey(String providerId) async {
    await delete('provider_api_key_$providerId');
  }

  /// Check whether a provider has a stored API key
  Future<bool> hasProviderApiKey(String providerId) async {
    final key = await getProviderApiKey(providerId);
    return key != null && key.isNotEmpty;
  }

  /// Generate the storage key reference for a provider's API key
  String generateProviderKeyRef(String providerId) {
    return 'provider_api_key_$providerId';
  }

  // ---- Provider Header Secrets ----

  static final _secretHeaderKeyPattern = RegExp(
    r'^(authorization|x-api-key|api-key|api_key|apikey|token|access_token|secret|password|key)$',
    caseSensitive: false,
  );

  /// Whether a header key looks like it contains a secret.
  static bool isSecretHeaderKey(String key) {
    return _secretHeaderKeyPattern.hasMatch(key.trim());
  }

  static String _headerStorageKey(String providerId, String headerKey) {
    return 'provider_header_${providerId}_${headerKey.trim().toLowerCase()}';
  }

  /// Store a single secret header value for a provider.
  Future<void> storeProviderHeaderSecret(
    String providerId,
    String headerKey,
    String value,
  ) async {
    await write(_headerStorageKey(providerId, headerKey), value);
  }

  /// Read a single secret header value for a provider.
  Future<String?> getProviderHeaderSecret(
    String providerId,
    String headerKey,
  ) async {
    return await read(_headerStorageKey(providerId, headerKey));
  }

  /// Delete a single secret header value for a provider.
  Future<void> deleteProviderHeaderSecret(
    String providerId,
    String headerKey,
  ) async {
    await delete(_headerStorageKey(providerId, headerKey));
  }

  /// Delete all stored header secrets for a provider.
  Future<void> deleteAllProviderHeaderSecrets(String providerId) async {
    final allEntries = await _storage.readAll();
    final prefix = 'provider_header_${providerId}_';
    final matchingKeys = allEntries.keys
        .where((key) => key.startsWith(prefix))
        .toList(growable: false);

    for (final key in matchingKeys) {
      await delete(key);
    }
  }
}
