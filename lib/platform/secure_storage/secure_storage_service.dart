import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Service for securely storing sensitive data like API keys
/// Uses flutter_secure_storage which delegates to OS keychain/keystore
class SecureStorageService {
  static const _storage = FlutterSecureStorage(
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

  /// Delete a secret
  Future<void> delete(String key) async {
    await _storage.delete(key: key);
  }

  /// Delete all secrets
  Future<void> deleteAll() async {
    await _storage.deleteAll();
  }

  /// Check if a key exists
  Future<bool> containsKey(String key) async {
    return await _storage.containsKey(key: key);
  }

  /// Generate a secure storage key reference for a provider
  String generateProviderKeyRef(String providerId) {
    return 'provider_api_key_$providerId';
  }

  /// Store provider API key
  Future<void> storeProviderApiKey(String providerId, String apiKey) async {
    final keyRef = generateProviderKeyRef(providerId);
    await write(keyRef, apiKey);
  }

  /// Retrieve provider API key
  Future<String?> getProviderApiKey(String providerId) async {
    final keyRef = generateProviderKeyRef(providerId);
    return await read(keyRef);
  }

  /// Delete provider API key
  Future<void> deleteProviderApiKey(String providerId) async {
    final keyRef = generateProviderKeyRef(providerId);
    await delete(keyRef);
  }

  /// Check if provider has an API key stored
  Future<bool> hasProviderApiKey(String providerId) async {
    final keyRef = generateProviderKeyRef(providerId);
    return await containsKey(keyRef);
  }
}
