import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/features/settings/data/settings_preferences.dart';

void main() {
  test('inactive delivery preferences are not exposed as working switches', () {
    final settings = File(
      'lib/features/settings/presentation/settings_screen.dart',
    ).readAsStringSync();

    expect(settings, isNot(contains("title: 'Email notifications'")));
    expect(settings, isNot(contains("title: 'WhatsApp notifications'")));
    // Tax compatibility is retained below, but there is no accepted active
    // producer. The UI must not advertise it as a working delivery channel.
    expect(settings, isNot(contains("title: 'Tax alerts'")));
  });

  test('active in-app notification preferences remain available', () {
    final settings = File(
      'lib/features/settings/presentation/settings_screen.dart',
    ).readAsStringSync();

    expect(settings, contains("title: 'Service updates'"));
    expect(settings, contains("title: 'Document reminders'"));
    expect(settings, contains("title: 'Payment alerts'"));
  });

  test('backend compatibility fields remain in the preference model', () {
    final preferences = const SettingsPreferences().copyWith(
      taxAlertsEnabled: false,
      emailNotificationsEnabled: false,
      whatsAppNotificationsEnabled: false,
    );
    final data = preferences.toJson();
    expect(preferences.taxAlertsEnabled, isFalse);
    expect(preferences.emailNotificationsEnabled, isFalse);
    expect(preferences.whatsAppNotificationsEnabled, isFalse);
    expect(data['tax_alerts_enabled'], isFalse);
    expect(data['email_notifications_enabled'], isFalse);
    expect(data['whatsapp_notifications_enabled'], isFalse);
  });

  test(
    'in-app and push masters remain independent of category compatibility',
    () {
      final inAppOff = const SettingsPreferences().copyWith(
        inAppNotificationsEnabled: false,
      );
      expect(inAppOff.inAppNotificationsEnabled, isFalse);
      expect(inAppOff.pushNotificationsEnabled, isTrue);
      expect(inAppOff.serviceUpdatesEnabled, isTrue);
      expect(inAppOff.taxAlertsEnabled, isTrue);

      final pushOff = const SettingsPreferences().copyWith(
        pushNotificationsEnabled: false,
      );
      expect(pushOff.inAppNotificationsEnabled, isTrue);
      expect(pushOff.pushNotificationsEnabled, isFalse);
      expect(pushOff.toJson()['push_notifications_enabled'], isFalse);
    },
  );
}
