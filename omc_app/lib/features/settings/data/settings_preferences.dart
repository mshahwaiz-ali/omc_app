class SettingsPreferences {
  const SettingsPreferences({
    this.inAppNotificationsEnabled = true,
    this.pushNotificationsEnabled = true,
    this.pushProviderOperational = false,
    this.serviceUpdatesEnabled = true,
    this.documentRemindersEnabled = true,
    this.paymentAlertsEnabled = true,
    this.taxAlertsEnabled = true,
    this.emailNotificationsEnabled = true,
    this.whatsAppNotificationsEnabled = true,
  });

  final bool inAppNotificationsEnabled;
  final bool pushNotificationsEnabled;
  final bool pushProviderOperational;

  final bool serviceUpdatesEnabled;
  final bool documentRemindersEnabled;
  final bool paymentAlertsEnabled;
  final bool taxAlertsEnabled;
  final bool emailNotificationsEnabled;
  final bool whatsAppNotificationsEnabled;

  SettingsPreferences copyWith({
    bool? inAppNotificationsEnabled,
    bool? pushNotificationsEnabled,
    bool? serviceUpdatesEnabled,
    bool? documentRemindersEnabled,
    bool? paymentAlertsEnabled,
    bool? taxAlertsEnabled,
    bool? emailNotificationsEnabled,
    bool? whatsAppNotificationsEnabled,
  }) {
    return SettingsPreferences(
      inAppNotificationsEnabled:
          inAppNotificationsEnabled ?? this.inAppNotificationsEnabled,
      pushNotificationsEnabled:
          pushNotificationsEnabled ?? this.pushNotificationsEnabled,
      pushProviderOperational: pushProviderOperational,
      serviceUpdatesEnabled:
          serviceUpdatesEnabled ?? this.serviceUpdatesEnabled,
      documentRemindersEnabled:
          documentRemindersEnabled ?? this.documentRemindersEnabled,
      paymentAlertsEnabled: paymentAlertsEnabled ?? this.paymentAlertsEnabled,
      taxAlertsEnabled: taxAlertsEnabled ?? this.taxAlertsEnabled,
      emailNotificationsEnabled:
          emailNotificationsEnabled ?? this.emailNotificationsEnabled,
      whatsAppNotificationsEnabled:
          whatsAppNotificationsEnabled ?? this.whatsAppNotificationsEnabled,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'in_app_notifications_enabled': inAppNotificationsEnabled,
      'push_notifications_enabled': pushNotificationsEnabled,
      'service_updates_enabled': serviceUpdatesEnabled,
      'document_reminders_enabled': documentRemindersEnabled,
      'payment_alerts_enabled': paymentAlertsEnabled,
      'tax_alerts_enabled': taxAlertsEnabled,
      'email_notifications_enabled': emailNotificationsEnabled,
      'whatsapp_notifications_enabled': whatsAppNotificationsEnabled,
    };
  }
}
