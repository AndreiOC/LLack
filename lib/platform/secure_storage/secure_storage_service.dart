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
}
