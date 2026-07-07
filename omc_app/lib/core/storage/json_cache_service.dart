import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class JsonCacheService {
  JsonCacheService(this._preferences);

  final SharedPreferences _preferences;

  static Future<JsonCacheService> create() async {
    final preferences = await SharedPreferences.getInstance();
    return JsonCacheService(preferences);
  }

  Future<void> saveMap(String key, Map<String, dynamic> value) {
    return _preferences.setString(key, jsonEncode(value));
  }

  Map<String, dynamic>? readMap(String key) {
    final rawValue = _preferences.getString(key);
    if (rawValue == null || rawValue.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<void> remove(String key) {
    return _preferences.remove(key);
  }
}
