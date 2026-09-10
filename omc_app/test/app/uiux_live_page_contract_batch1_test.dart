import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test(
    'V2 responsive page primitive implements C2 insets and bounded width',
    () {
      final source = read('lib/core/widgets/omc_premium.dart');
      final start = source.indexOf('class OmcPageListView');
      final end = source.indexOf('class OmcSurface', start);
      expect(start, greaterThanOrEqualTo(0));
      expect(end, greaterThan(start));
      final block = source.substring(start, end);
      expect(block, contains('AppLayout.pageInsetFor(constraints.maxWidth)'));
      expect(block, contains('maxWidth = AppLayout.generalMaxWidth'));
      expect(block, contains('(constraints.maxWidth - maxWidth) / 2'));
    },
  );

  test('live Home owners use responsive page primitive', () {
    final dispatcher = read(
      'lib/features/home/presentation/home_screen_dispatcher.dart',
    );
    final roleAware = read(
      'lib/features/home/presentation/home_screen_role_aware.dart',
    );
    final guest = read(
      'lib/features/home/presentation/customer_guest_home_view.dart',
    );
    final internal = read(
      'lib/features/home/presentation/internal_home_view.dart',
    );
    expect(dispatcher, contains("'home_screen_role_aware.dart' as legacy"));
    expect(roleAware, contains('CustomerGuestHomeView('));
    expect(roleAware, contains('InternalHomeView('));
    expect(guest, contains('child: OmcPageListView('));
    expect(internal, contains('child: OmcPageListView('));
    expect(
      guest,
      isNot(
        contains(
          'padding: const EdgeInsets.fromLTRB(20, 18, 20, AppSpacing.xl)',
        ),
      ),
    );
    expect(
      internal,
      isNot(
        contains(
          'padding: const EdgeInsets.fromLTRB(20, 18, 20, AppSpacing.xl)',
        ),
      ),
    );
  });

  test('live Dashboard page states use C2 primitive', () {
    final router = read('lib/app/router.dart');
    final dashboard = read(
      'lib/features/dashboard/presentation/dashboard_screen.dart',
    );
    expect(router, contains('const DashboardScreen()'));
    expect(
      'OmcPageListView('.allMatches(dashboard).length,
      greaterThanOrEqualTo(2),
    );
    expect(
      dashboard,
      isNot(contains('padding: const EdgeInsets.fromLTRB(20, 18, 20, 32)')),
    );
  });

  test('live Payments page states use C2 primitive', () {
    final router = read('lib/app/router.dart');
    final payments = read(
      'lib/features/payments/presentation/payments_screen.dart',
    );
    expect(router, contains('const PaymentsScreen()'));
    expect(
      'OmcPageListView('.allMatches(payments).length,
      greaterThanOrEqualTo(4),
    );
    expect(
      payments,
      isNot(
        contains(
          'padding: const EdgeInsets.fromLTRB(20, 16, 20, AppSpacing.xl)',
        ),
      ),
    );
  });

  test('live Notifications page states use C2 primitive', () {
    final router = read('lib/app/router.dart');
    final notifications = read(
      'lib/features/notifications/presentation/notifications_screen.dart',
    );
    expect(router, contains('const NotificationsScreen()'));
    expect(
      'OmcPageListView('.allMatches(notifications).length,
      greaterThanOrEqualTo(3),
    );
    expect(
      notifications,
      isNot(
        contains(
          'padding: const EdgeInsets.fromLTRB(20, 16, 20, AppSpacing.xl)',
        ),
      ),
    );
  });

  test('meaningful operational statuses do not use caption typography', () {
    final internal = read(
      'lib/features/home/presentation/internal_home_view.dart',
    );
    final notifications = read(
      'lib/features/notifications/presentation/notifications_screen.dart',
    );
    expect(internal, contains('textTheme.labelMedium'));
    expect(internal, contains('textTheme.bodyMedium'));
    expect(notifications, contains('item.type.label'));
    expect(notifications, contains('textTheme.labelMedium'));
  });
}
