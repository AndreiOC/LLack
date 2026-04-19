import 'package:sqflite/sqflite.dart';
import '../../domain/entities/entities.dart';

/// Data Access Object for AppSetting operations
class AppSettingDao {
  final Database _db;

  AppSettingDao(this._db);

  /// Get setting by key
  Future<AppSetting?> getByKey(String key) async {
    final maps = await _db.query(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return AppSetting.fromJson(maps.first);
  }

  /// Get boolean setting value
  Future<bool> getBool(String key, bool defaultValue) async {
    final setting = await getByKey(key);
    if (setting == null) return defaultValue;
    return setting.asBool;
  }

  /// Get string setting value
  Future<String?> getString(String key) async {
    final setting = await getByKey(key);
    return setting?.asString;
  }

  /// Get int setting value
  Future<int?> getInt(String key) async {
    final setting = await getByKey(key);
    return setting?.asInt;
  }

  /// Set boolean value
  Future<void> setBool(String key, bool value) async {
    await _setValue(key, value);
  }

  /// Set string value
  Future<void> setString(String key, String? value) async {
    await _setValue(key, value);
  }

  /// Set int value
  Future<void> setInt(String key, int? value) async {
    await _setValue(key, value);
  }

  /// Internal method to set any value
  Future<void> _setValue(String key, dynamic value) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.insert(
      'app_settings',
      {
        'key': key,
        'value_json': value,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Insert or update setting
  Future<void> upsert(AppSetting setting) async {
    await _db.insert(
      'app_settings',
      setting.toJson(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Delete setting
  Future<void> delete(String key) async {
    await _db.delete(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
    );
  }

  /// Get all settings
  Future<List<AppSetting>> getAll() async {
    final maps = await _db.query('app_settings');
    return maps.map((m) => AppSetting.fromJson(m)).toList();
  }

  /// Check if onboarding is complete
  Future<bool> isOnboardingComplete() async {
    return await getBool(AppSettingKeys.hasCompletedOnboarding, false);
  }

  /// Mark onboarding as complete
  Future<void> completeOnboarding() async {
    await setBool(AppSettingKeys.hasCompletedOnboarding, true);
  }

  /// Check if local-only mode is enabled
  Future<bool> isLocalOnlyMode() async {
    return await getBool(AppSettingKeys.skipCloudProviders, false);
  }

  /// Set local-only mode
  Future<void> setLocalOnlyMode(bool value) async {
    await setBool(AppSettingKeys.skipCloudProviders, value);
  }

  /// Get last successful Ollama endpoint
  Future<String?> getLastOllamaEndpoint() async {
    return await getString(AppSettingKeys.lastSuccessfulOllamaEndpoint);
  }

  /// Save last successful Ollama endpoint
  Future<void> setLastOllamaEndpoint(String endpoint) async {
    await setString(AppSettingKeys.lastSuccessfulOllamaEndpoint, endpoint);
  }
}
