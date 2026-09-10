from pathlib import Path

path = Path('omc_app/test/app/uiux_live_page_contract_batch1_test.dart')
text = path.read_text()
old = r'''  test('live Dashboard, Payments and Notifications page states use C2 primitive', () {
    final router = read('lib/app/router.dart');
    final dashboard = read('lib/features/dashboard/presentation/dashboard_screen.dart');
    final payments = read('lib/features/payments/presentation/payments_screen.dart');
    final notifications = read('lib/features/notifications/presentation/notifications_screen.dart');
    expect(router, contains('const DashboardScreen()'));
    expect(router, contains('const PaymentsScreen()'));
    expect(router, contains('const NotificationsScreen()'));
    expect('OmcPageListView('.allMatches(dashboard).length, greaterThanOrEqualTo(2));
    expect('OmcPageListView('.allMatches(payments).length, greaterThanOrEqualTo(4));
    expect('OmcPageListView('.allMatches(notifications).length, greaterThanOrEqualTo(3));
    expect(dashboard, isNot(contains('padding: const EdgeInsets.fromLTRB(20, 18, 20, 32)')));
    expect(payments, isNot(contains('padding: const EdgeInsets.fromLTRB(20, 16, 20, AppSpacing.xl)')));
    expect(notifications, isNot(contains('padding: const EdgeInsets.fromLTRB(20, 16, 20, AppSpacing.xl)')));
  });
'''
new = r'''  test('live Dashboard page states use C2 primitive', () {
    final router = read('lib/app/router.dart');
    final dashboard = read('lib/features/dashboard/presentation/dashboard_screen.dart');
    expect(router, contains('const DashboardScreen()'));
    expect('OmcPageListView('.allMatches(dashboard).length, greaterThanOrEqualTo(2));
    expect(dashboard, isNot(contains('padding: const EdgeInsets.fromLTRB(20, 18, 20, 32)')));
  });

  test('live Payments page states use C2 primitive', () {
    final router = read('lib/app/router.dart');
    final payments = read('lib/features/payments/presentation/payments_screen.dart');
    expect(router, contains('const PaymentsScreen()'));
    expect('OmcPageListView('.allMatches(payments).length, greaterThanOrEqualTo(4));
    expect(payments, isNot(contains('padding: const EdgeInsets.fromLTRB(20, 16, 20, AppSpacing.xl)')));
  });

  test('live Notifications page states use C2 primitive', () {
    final router = read('lib/app/router.dart');
    final notifications = read('lib/features/notifications/presentation/notifications_screen.dart');
    expect(router, contains('const NotificationsScreen()'));
    expect('OmcPageListView('.allMatches(notifications).length, greaterThanOrEqualTo(3));
    expect(notifications, isNot(contains('padding: const EdgeInsets.fromLTRB(20, 16, 20, AppSpacing.xl)')));
  });
'''
if text.count(old) != 1:
    raise SystemExit('combined contract test anchor mismatch')
path.write_text(text.replace(old, new, 1))
