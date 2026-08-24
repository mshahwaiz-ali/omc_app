import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/app/route_access_policy.dart';
import 'package:omc_app/features/auth/application/auth_state.dart';

void main() {
  test('internal notification capability opens notification routes', () {
    final capabilities = AuthCapabilities.fromJson({
      'access_state': 'internal',
      'can_view_internal_notifications': true,
      'can_view_customer_notifications': false,
    });

    expect(canAccessRoute('/notifications', capabilities), isTrue);
    expect(
      canAccessRoute('/notifications/OMC-NOTIF-00001', capabilities),
      isTrue,
    );
  });

  test('auth model exposes canonical internal notification capability', () {
    final source = File(
      'lib/features/auth/application/auth_state.dart',
    ).readAsStringSync();

    expect(source, contains('canViewInternalNotifications'));
    expect(source, contains("json['can_view_internal_notifications']"));
    expect(source, contains('canViewNotifications'));
    expect(
      source,
      contains('canViewCustomerNotifications || canViewInternalNotifications'),
    );
  });

  test(
    'notification providers use customer-or-internal notification access',
    () {
      final source = File(
        'lib/features/notifications/data/notifications_repository.dart',
      ).readAsStringSync();

      expect(source, contains('capabilities.canViewNotifications'));
      expect(
        source,
        isNot(contains('capabilities.canViewCustomerNotifications')),
      );
    },
  );

  test('navigation exposes alerts using canonical notification access', () {
    final source = File(
      'lib/app/navigation/omc_navigation_ia.dart',
    ).readAsStringSync();

    expect(source, contains('capabilities.canViewNotifications'));
  });

  test('Task notifications decode as a first-class notification type', () {
    final itemSource = File(
      'lib/features/notifications/data/notification_item.dart',
    ).readAsStringSync();

    final repositorySource = File(
      'lib/features/notifications/data/notifications_repository.dart',
    ).readAsStringSync();

    expect(itemSource, contains('taskUpdate'));
    expect(repositorySource, contains("type.contains('task')"));
    expect(repositorySource, contains('AppNotificationType.taskUpdate'));
  });
}
