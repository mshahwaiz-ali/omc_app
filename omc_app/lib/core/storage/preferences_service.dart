import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  PreferencesService(this._preferences);

  final SharedPreferences _preferences;

  static const String _hasCompletedOnboardingKey = 'has_completed_onboarding';
  static const String _lastSelectedLanguageKey = 'last_selected_language';
  static const String _lastKnownUserNameKey = 'last_known_user_name';

  static Future<PreferencesService> create() async {
    final preferences = await SharedPreferences.getInstance();
    return PreferencesService(preferences);
  }

  bool get hasCompletedOnboarding {
    return _preferences.getBool(_hasCompletedOnboardingKey) ?? false;
  }

  Future<void> setHasCompletedOnboarding(bool value) {
    return _preferences.setBool(_hasCompletedOnboardingKey, value);
  }

  String get lastSelectedLanguage {
    return _preferences.getString(_lastSelectedLanguageKey) ?? 'en';
  }

  Future<void> setLastSelectedLanguage(String value) {
    return _preferences.setString(_lastSelectedLanguageKey, value);
  }

  String? get lastKnownUserName {
    return _preferences.getString(_lastKnownUserNameKey);
  }

  Future<void> setLastKnownUserName(String value) {
    return _preferences.setString(_lastKnownUserNameKey, value);
  }

  Future<void> clearNonSensitivePreferences() async {
    await _preferences.remove(_hasCompletedOnboardingKey);
    await _preferences.remove(_lastSelectedLanguageKey);
    await _preferences.remove(_lastKnownUserNameKey);
  }
}
