enum AppNotificationType {
  serviceUpdate,
  documentRequest,
  paymentAlert,
  general,
}

class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.isRead,
    this.reference,
    this.actionUrl,
    this.createdAtLabel,
  });

  final String id;
  final String title;
  final String message;
  final AppNotificationType type;
  final bool isRead;
  final String? reference;
  final String? actionUrl;
  final String? createdAtLabel;
}

extension AppNotificationTypeLabel on AppNotificationType {
  String get label {
    switch (this) {
      case AppNotificationType.serviceUpdate:
        return 'Service Update';
      case AppNotificationType.documentRequest:
        return 'Document Request';
      case AppNotificationType.paymentAlert:
        return 'Payment Alert';
      case AppNotificationType.general:
        return 'General';
    }
  }
}
