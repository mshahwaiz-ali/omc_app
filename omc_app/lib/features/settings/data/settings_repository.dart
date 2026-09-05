import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/frappe_client.dart';
import '../../auth/application/auth_controller.dart';
import 'settings_preferences.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  ref.watch(sessionEpochProvider);
  final frappeClient = ref.watch(frappeClientProvider);

  return SettingsRepository(frappeClient: frappeClient);
});

final settingsPreferencesProvider =
    FutureProvider.autoDispose<SettingsPreferences?>((ref) async {
      final authState = ref.watch(authControllerProvider);

      // Internal OMC users do not have a customer profile, so customer-specific
      // notification preferences are not applicable. Resolve immediately
      // instead of leaving the Settings screen waiting on a customer endpoint.
      if (authState.capabilities.isInternal ||
          authState.canAccessInternalWorkspace) {
        return const SettingsPreferences();
      }

      final repository = ref.watch(settingsRepositoryProvider);
      return repository.fetchPreferences();
    });

class SettingsRepository {
  const SettingsRepository({required this.frappeClient});

  final FrappeClient frappeClient;

  Future<SettingsPreferences?> fetchPreferences() async {
    final response = await frappeClient.getMethod(
      ApiConfig.settingsPreferencesMethod,
    );

    return _mapPreferencesResponse(response);
  }

  Future<void> savePreferences(SettingsPreferences preferences) async {
    await frappeClient.postMethod(
      ApiConfig.updateSettingsPreferencesMethod,
      data: preferences.toJson(),
    );
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
      inAppNotificationsEnabled: _boolValue(
        rawPreferences['in_app_notifications_enabled'],
        fallback: true,
      ),
      pushNotificationsEnabled: _boolValue(
        rawPreferences['push_notifications_enabled'],
        fallback: true,
      ),
      pushProviderOperational: _boolValue(
        rawPreferences['push_provider_operational'],
        fallback: false,
      ),
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
