import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  PreferencesService(this._preferences);

  final SharedPreferences _preferences;

  static const int currentOnboardingVersion = 1;

  static const String _hasCompletedOnboardingKey = 'has_completed_onboarding';
  static const String _onboardingVersionKey = 'onboarding_version_seen';
  static const String _lastSelectedLanguageKey = 'last_selected_language';
  static const String _lastKnownUserNameKey = 'last_known_user_name';

  static Future<PreferencesService> create() async {
    final preferences = await SharedPreferences.getInstance();
    return PreferencesService(preferences);
  }

  int get onboardingVersionSeen {
    final storedVersion = _preferences.getInt(_onboardingVersionKey);
    if (storedVersion != null) return storedVersion;

    // Preserve the existing boolean preference for current installations.
    return (_preferences.getBool(_hasCompletedOnboardingKey) ?? false)
        ? currentOnboardingVersion
        : 0;
  }

  bool get hasCompletedOnboarding {
    return onboardingVersionSeen >= currentOnboardingVersion;
  }

  Future<void> setHasCompletedOnboarding(bool value) async {
    await _preferences.setBool(_hasCompletedOnboardingKey, value);
    await _preferences.setInt(
      _onboardingVersionKey,
      value ? currentOnboardingVersion : 0,
    );
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
    await _preferences.remove(_onboardingVersionKey);
    await _preferences.remove(_lastSelectedLanguageKey);
    await _preferences.remove(_lastKnownUserNameKey);
  }
}
