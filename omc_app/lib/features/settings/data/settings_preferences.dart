class SettingsPreferences {
  const SettingsPreferences({
    this.serviceUpdatesEnabled = true,
    this.documentRemindersEnabled = true,
    this.paymentAlertsEnabled = true,
    this.taxAlertsEnabled = true,
    this.emailNotificationsEnabled = true,
    this.whatsAppNotificationsEnabled = true,
  });

  final bool serviceUpdatesEnabled;
  final bool documentRemindersEnabled;
  final bool paymentAlertsEnabled;
  final bool taxAlertsEnabled;
  final bool emailNotificationsEnabled;
  final bool whatsAppNotificationsEnabled;

  SettingsPreferences copyWith({
    bool? serviceUpdatesEnabled,
    bool? documentRemindersEnabled,
    bool? paymentAlertsEnabled,
    bool? taxAlertsEnabled,
    bool? emailNotificationsEnabled,
    bool? whatsAppNotificationsEnabled,
  }) {
    return SettingsPreferences(
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
      'service_updates_enabled': serviceUpdatesEnabled,
      'document_reminders_enabled': documentRemindersEnabled,
      'payment_alerts_enabled': paymentAlertsEnabled,
      'tax_alerts_enabled': taxAlertsEnabled,
      'email_notifications_enabled': emailNotificationsEnabled,
      'whatsapp_notifications_enabled': whatsAppNotificationsEnabled,
    };
  }
}
