import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/frappe_client.dart';
import 'notification_item.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((
  ref,
) {
  final frappeClient = ref.watch(frappeClientProvider);

  return NotificationsRepository(frappeClient: frappeClient);
});

final notificationsProvider = FutureProvider<List<NotificationItem>>((
  ref,
) async {
  final repository = ref.watch(notificationsRepositoryProvider);
  return repository.fetchNotifications();
});

class NotificationsRepository {
  const NotificationsRepository({required this._frappeClient});

  final FrappeClient _frappeClient;

  Future<List<NotificationItem>> fetchNotifications() async {
    try {
      final response = await _frappeClient.getMethod(
        ApiConfig.notificationsMethod,
      );
      return _mapNotificationsResponse(response);
    } on ApiError {
      return const [];
    } catch (_) {
      return const [];
    }
  }

  List<NotificationItem> _mapNotificationsResponse(Map<String, dynamic>? data) {
    if (data == null) return const [];

    final message = data['message'];
    final rawNotifications = message is List
        ? message
        : message is Map<String, dynamic>
        ? message['notifications']
        : data['notifications'];

    if (rawNotifications is! List) return const [];

    return rawNotifications
        .whereType<Map<String, dynamic>>()
        .map(_mapNotification)
        .toList(growable: false);
  }

  NotificationItem _mapNotification(Map<String, dynamic> json) {
    return NotificationItem(
      id: _stringValue(json['id'] ?? json['name'] ?? json['notification_id']),
      title: _stringValue(json['title'] ?? json['subject']),
      message: _stringValue(json['message'] ?? json['description']),
      type: _typeFromValue(json['type'] ?? json['notification_type']),
      createdAtLabel: _nullableString(
        json['created_at_label'] ?? json['creation'] ?? json['created_at'],
      ),
      reference: _nullableString(json['reference'] ?? json['case_reference']),
      isRead: json['is_read'] == true || json['read'] == true,
    );
  }

  AppNotificationType _typeFromValue(dynamic value) {
    final type = value?.toString().trim().toLowerCase() ?? '';

    if (type.contains('document')) {
      return AppNotificationType.documentRequest;
    }
    if (type.contains('payment') ||
        type.contains('invoice') ||
        type.contains('receipt')) {
      return AppNotificationType.paymentAlert;
    }
    if (type.contains('service') ||
        type.contains('case') ||
        type.contains('request')) {
      return AppNotificationType.serviceUpdate;
    }

    return AppNotificationType.general;
  }

  String _stringValue(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? '-' : text;
  }

  String? _nullableString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }
}
