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
  static const String _deviceLockEnabledKey = 'device_lock_enabled';
  static const String _biometricLoginEnabledKey = 'biometric_login_enabled';
  static const String _biometricLoginIdentifierKey =
      'biometric_login_identifier';
  static const String _biometricLoginPasswordKey = 'biometric_login_password';

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

  Future<void> saveDeviceLockEnabled(bool enabled) {
    return _storage.write(
      key: _deviceLockEnabledKey,
      value: enabled ? '1' : '0',
    );
  }

  Future<bool> readDeviceLockEnabled() async {
    return await _storage.read(key: _deviceLockEnabledKey) == '1';
  }

  Future<void> saveBiometricLoginCredentials({
    required String identifier,
    required String password,
  }) async {
    await _storage.write(key: _biometricLoginIdentifierKey, value: identifier);
    await _storage.write(key: _biometricLoginPasswordKey, value: password);
    await _storage.write(key: _biometricLoginEnabledKey, value: '1');
  }

  Future<bool> readBiometricLoginEnabled() async {
    return await _storage.read(key: _biometricLoginEnabledKey) == '1';
  }

  Future<String?> readBiometricLoginIdentifier() {
    return _storage.read(key: _biometricLoginIdentifierKey);
  }

  Future<String?> readBiometricLoginPassword() {
    return _storage.read(key: _biometricLoginPasswordKey);
  }

  Future<void> clearBiometricLogin() async {
    await _storage.delete(key: _biometricLoginEnabledKey);
    await _storage.delete(key: _biometricLoginIdentifierKey);
    await _storage.delete(key: _biometricLoginPasswordKey);
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
