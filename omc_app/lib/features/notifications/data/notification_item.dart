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
    this.createdAtLabel,
    this.reference,
    this.isRead = false,
  });

  final String id;
  final String title;
  final String message;
  final AppNotificationType type;
  final String? createdAtLabel;
  final String? reference;
  final bool isRead;
}

extension AppNotificationTypeLabel on AppNotificationType {
  String get label {
    switch (this) {
      case AppNotificationType.serviceUpdate:
        return 'Service';
      case AppNotificationType.documentRequest:
        return 'Document';
      case AppNotificationType.paymentAlert:
        return 'Payment';
      case AppNotificationType.general:
        return 'General';
    }
  }
}
