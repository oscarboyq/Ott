import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:video/core/exceptions/app_exception.dart';

class SecureStorageService {
  static const String _prefix = 'ott_';
  late FlutterSecureStorage _storage;

  SecureStorageService() {
    _storage = const FlutterSecureStorage(
      aOptions: AndroidOptions(
        keyCipherAlgorithm:
            KeyCipherAlgorithm.RSA_ECB_OAEPwithSHA_256andMGF1Padding,
        storageCipherAlgorithm: StorageCipherAlgorithm.AES_GCM_NoPadding,
        resetOnError: true,
      ),
      iOptions: const IOSOptions(),
    );
  }

  Future<void> saveString(String key, String value) async {
    try {
      await _storage.write(key: _prefix + key, value: value);
    } catch (e) {
      throw CacheException('Failed to save to secure storage: $e');
    }
  }

  Future<String?> getString(String key) async {
    try {
      return await _storage.read(key: _prefix + key);
    } catch (e) {
      throw CacheException('Failed to read from secure storage: $e');
    }
  }

  Future<void> deleteString(String key) async {
    try {
      await _storage.delete(key: _prefix + key);
    } catch (e) {
      throw CacheException('Failed to delete from secure storage: $e');
    }
  }

  Future<void> deleteAll() async {
    try {
      await _storage.deleteAll();
    } catch (e) {
      throw CacheException('Failed to clear secure storage: $e');
    }
  }

  Future<void> saveAccessToken(String token) =>
      saveString('access_token', token);

  Future<String?> getAccessToken() => getString('access_token');

  Future<void> deleteAccessToken() => deleteString('access_token');

  Future<void> saveRefreshToken(String token) =>
      saveString('refresh_token', token);

  Future<String?> getRefreshToken() => getString('refresh_token');

  Future<void> deleteRefreshToken() => deleteString('refresh_token');
}
