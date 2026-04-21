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
}
