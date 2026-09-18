import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class StorageService {
  // General Storage (SharedPreferences)
  Future<void> saveString(String key, String value);
  Future<String?> getString(String key);
  Future<void> saveBool(String key, bool value);
  Future<bool?> getBool(String key);
  Future<void> saveInt(String key, int value);
  Future<int?> getInt(String key);
  Future<void> remove(String key);
  Future<void> clear();

  // Secure Storage (FlutterSecureStorage for Tokens, PINs, Passwords)
  Future<void> saveSecure(String key, String value);
  Future<String?> getSecure(String key);
  Future<void> deleteSecure(String key);
  Future<void> clearSecure();

  // Unified Clean Wipe
  Future<void> clearAll();
}

/// Global Provider for SharedPreferences to be overridden in main.dart
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in ProviderScope');
});

class AppStorageService implements StorageService {
  final SharedPreferences _prefs;
  final FlutterSecureStorage _secureStorage;

  AppStorageService(
    this._prefs, {
    FlutterSecureStorage? secureStorage,
  }) : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(
                resetOnError: true,
              ),
              iOptions: IOSOptions(
                accessibility:
                    KeychainAccessibility.first_unlock_this_device,
              ),
            );



  // ---------------------------------------------------------------------------
  // General Key-Value Storage (SharedPreferences)
  // ---------------------------------------------------------------------------
  @override
  Future<void> saveString(String key, String value) async {
    await _prefs.setString(key, value);
  }

  @override
  Future<String?> getString(String key) async {
    return _prefs.getString(key);
  }

  @override
  Future<void> saveBool(String key, bool value) async {
    await _prefs.setBool(key, value);
  }

  @override
  Future<bool?> getBool(String key) async {
    return _prefs.getBool(key);
  }

  @override
  Future<void> saveInt(String key, int value) async {
    await _prefs.setInt(key, value);
  }

  @override
  Future<int?> getInt(String key) async {
    return _prefs.getInt(key);
  }

  @override
  Future<void> remove(String key) async {
    await _prefs.remove(key);
  }

  @override
  Future<void> clear() async {
    await _prefs.clear();
  }

  // ---------------------------------------------------------------------------
  // Secure Storage (FlutterSecureStorage)
  // ---------------------------------------------------------------------------
  @override
  Future<void> saveSecure(String key, String value) async {
    await _secureStorage.write(key: key, value: value);
  }

  @override
  Future<String?> getSecure(String key) async {
    return await _secureStorage.read(key: key);
  }

  @override
  Future<void> deleteSecure(String key) async {
    await _secureStorage.delete(key: key);
  }

  @override
  Future<void> clearSecure() async {
    await _secureStorage.deleteAll();
  }

  // ---------------------------------------------------------------------------
  // Unified Reset
  // ---------------------------------------------------------------------------
  @override
  Future<void> clearAll() async {
    await clear();
    await clearSecure();
  }
}

/// Global Riverpod Provider for StorageService
final storageServiceProvider = Provider<StorageService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AppStorageService(prefs);
});
