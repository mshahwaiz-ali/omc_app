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

final notificationDetailProvider =
    FutureProvider.family<NotificationItem?, String>((ref, notificationId) {
      final repository = ref.watch(notificationsRepositoryProvider);

      return repository.fetchNotificationDetail(notificationId);
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
      rethrow;
    } catch (error) {
      throw ApiError(
        message:
            'OMC notifications could not be loaded from the server right now.',
        code: 'notifications_unavailable',
        details: error,
      );
    }
  }

  Future<void> markNotificationAsRead(String notificationId) async {
    final cleanNotificationId = notificationId.trim();
    if (cleanNotificationId.isEmpty) {
      throw const ApiError(message: 'Missing backend notification reference.');
    }

    await _frappeClient.postMethod(
      ApiConfig.markNotificationReadMethod,
      data: {
        'notification_id': cleanNotificationId,
        'name': cleanNotificationId,
      },
    );
  }

  Future<void> markAllNotificationsAsRead() async {
    await _frappeClient.postMethod(ApiConfig.markAllNotificationsReadMethod);
  }

  Future<NotificationItem?> fetchNotificationDetail(
    String notificationId,
  ) async {
    final cleanNotificationId = notificationId.trim();
    if (cleanNotificationId.isEmpty) return null;

    try {
      final response = await _frappeClient.getMethod(
        ApiConfig.notificationDetailMethod,
        queryParameters: {
          'notification_id': cleanNotificationId,
          'name': cleanNotificationId,
        },
      );

      return _mapNotificationDetailResponse(response);
    } on ApiError {
      rethrow;
    } catch (error) {
      throw ApiError(
        message:
            'This OMC notification could not be loaded from the server right now.',
        code: 'notification_detail_unavailable',
        details: error,
      );
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

  NotificationItem? _mapNotificationDetailResponse(Map<String, dynamic>? data) {
    if (data == null) return null;

    final message = data['message'];
    final rawNotification = message is Map<String, dynamic>
        ? message['notification'] ??
              message['data'] ??
              message['item'] ??
              message
        : data['notification'] ?? data['data'] ?? data['item'];

    if (rawNotification is! Map<String, dynamic>) return null;

    return _mapNotification(rawNotification);
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
      reference: _nullableString(
        json['reference'] ??
            json['case_reference'] ??
            json['reference_name'] ??
            json['reference_id'],
      ),
      actionUrl: _nullableString(
        json['mobile_route'] ??
            json['action_url'] ??
            json['link'] ??
            json['route'] ??
            json['url'],
      ),
      isRead: _boolValue(json['is_read'] ?? json['read'] ?? json['seen']),
    );
  }

  bool _boolValue(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;

    final text = value?.toString().trim().toLowerCase() ?? '';
    return text == '1' || text == 'true' || text == 'yes' || text == 'read';
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
