import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/frappe_client.dart';
import 'settings_preferences.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final frappeClient = ref.watch(frappeClientProvider);

  return SettingsRepository(frappeClient: frappeClient);
});

final settingsPreferencesProvider = FutureProvider<SettingsPreferences?>((
  ref,
) async {
  final repository = ref.watch(settingsRepositoryProvider);

  return repository.fetchPreferences();
});

class SettingsRepository {
  const SettingsRepository({required this.frappeClient});

  final FrappeClient frappeClient;

  Future<SettingsPreferences?> fetchPreferences() async {
    try {
      final response = await frappeClient.getMethod(
        ApiConfig.settingsPreferencesMethod,
      );

      return _mapPreferencesResponse(response);
    } on ApiError {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> savePreferences(SettingsPreferences preferences) async {
    try {
      await frappeClient.postMethod(
        ApiConfig.updateSettingsPreferencesMethod,
        data: preferences.toJson(),
      );

      return true;
    } on ApiError {
      return false;
    } catch (_) {
      return false;
    }
  }

  SettingsPreferences? _mapPreferencesResponse(Map<String, dynamic>? data) {
    if (data == null) return null;

    final message = data['message'];
    final rawPreferences = message is Map<String, dynamic>
        ? message['preferences'] ??
              message['settings'] ??
              message['data'] ??
              message
        : data['preferences'] ?? data['settings'] ?? data['data'] ?? data;

    if (rawPreferences is! Map<String, dynamic>) return null;

    return SettingsPreferences(
      serviceUpdatesEnabled: _boolValue(
        rawPreferences['service_updates_enabled'] ??
            rawPreferences['service_updates'],
        fallback: true,
      ),
      documentRemindersEnabled: _boolValue(
        rawPreferences['document_reminders_enabled'] ??
            rawPreferences['document_reminders'],
        fallback: true,
      ),
      paymentAlertsEnabled: _boolValue(
        rawPreferences['payment_alerts_enabled'] ??
            rawPreferences['payment_alerts'],
        fallback: true,
      ),
      taxAlertsEnabled: _boolValue(
        rawPreferences['tax_alerts_enabled'] ?? rawPreferences['tax_alerts'],
        fallback: true,
      ),
      emailNotificationsEnabled: _boolValue(
        rawPreferences['email_notifications_enabled'] ??
            rawPreferences['email_notifications'],
        fallback: true,
      ),
      whatsAppNotificationsEnabled: _boolValue(
        rawPreferences['whatsapp_notifications_enabled'] ??
            rawPreferences['whatsapp_notifications'] ??
            rawPreferences['whats_app_notifications'],
        fallback: true,
      ),
    );
  }

  bool _boolValue(dynamic value, {required bool fallback}) {
    if (value is bool) return value;
    if (value is num) return value != 0;

    final text = value?.toString().trim().toLowerCase();
    if (text == null || text.isEmpty) return fallback;

    return text == '1' ||
        text == 'true' ||
        text == 'yes' ||
        text == 'enabled' ||
        text == 'on';
  }
}
