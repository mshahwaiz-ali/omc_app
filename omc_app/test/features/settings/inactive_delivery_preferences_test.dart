import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('inactive delivery preferences are not exposed as working switches', () {
    final settings = File(
      'lib/features/settings/presentation/settings_screen.dart',
    ).readAsStringSync();

    expect(settings, isNot(contains("title: 'Email notifications'")));
    expect(settings, isNot(contains("title: 'WhatsApp notifications'")));
  });

  test('active in-app notification preferences remain available', () {
    final settings = File(
      'lib/features/settings/presentation/settings_screen.dart',
    ).readAsStringSync();

    expect(settings, contains("title: 'Service updates'"));
    expect(settings, contains("title: 'Document reminders'"));
    expect(settings, contains("title: 'Payment alerts'"));
    expect(settings, contains("title: 'Tax alerts'"));
  });

  test('backend compatibility fields remain in the preference model', () {
    final model = File(
      'lib/features/settings/data/settings_preferences.dart',
    ).readAsStringSync();

    expect(model, contains('emailNotificationsEnabled'));
    expect(model, contains('whatsAppNotificationsEnabled'));
    expect(model, contains("'email_notifications_enabled'"));
    expect(model, contains("'whatsapp_notifications_enabled'"));
  });
}
