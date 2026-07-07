import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorageService {
  SecureStorageService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _sessionCookieKey = 'session_cookie';
  static const String _apiKeyKey = 'api_key';
  static const String _apiSecretKey = 'api_secret';
  static const String _userIdKey = 'user_id';
  static const String _guestDeviceIdKey = 'guest_device_id';
  static const String _guestSessionIdKey = 'guest_session_id';

  Future<void> saveSessionCookie(String value) {
    return _storage.write(key: _sessionCookieKey, value: value);
  }

  Future<String?> readSessionCookie() {
    return _storage.read(key: _sessionCookieKey);
  }

  Future<void> saveApiCredentials({
    required String apiKey,
    required String apiSecret,
  }) async {
    await _storage.write(key: _apiKeyKey, value: apiKey);
    await _storage.write(key: _apiSecretKey, value: apiSecret);
  }

  Future<String?> readApiKey() {
    return _storage.read(key: _apiKeyKey);
  }

  Future<String?> readApiSecret() {
    return _storage.read(key: _apiSecretKey);
  }

  Future<void> saveUserId(String value) {
    return _storage.write(key: _userIdKey, value: value);
  }

  Future<String?> readUserId() {
    return _storage.read(key: _userIdKey);
  }

  Future<void> saveGuestDeviceId(String value) {
    return _storage.write(key: _guestDeviceIdKey, value: value);
  }

  Future<String?> readGuestDeviceId() {
    return _storage.read(key: _guestDeviceIdKey);
  }

  Future<void> saveGuestSessionId(String value) {
    return _storage.write(key: _guestSessionIdKey, value: value);
  }

  Future<String?> readGuestSessionId() {
    return _storage.read(key: _guestSessionIdKey);
  }

  Future<void> clearSession() async {
    await _storage.delete(key: _sessionCookieKey);
    await _storage.delete(key: _apiKeyKey);
    await _storage.delete(key: _apiSecretKey);
    await _storage.delete(key: _userIdKey);
  }

  Future<void> clearAll() {
    return _storage.deleteAll();
  }
}
