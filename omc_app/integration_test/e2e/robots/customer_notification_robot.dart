import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/core/diagnostics/omc_widget_keys.dart';

import '../support/e2e_waits.dart';

class CustomerNotificationRobot {
  CustomerNotificationRobot(this.tester, this.waits);

  final WidgetTester tester;
  final E2eWaits waits;

  Future<void> verifyAcceptedReceiptNotification(String paymentId) async {
    final cleanPaymentId = paymentId.trim();
    if (cleanPaymentId.isEmpty) {
      fail('Payment notification verification requires the current payment ID.');
    }

    await tester.pageBack();
    await tester.pump();
    await waits.waitFor(
      find.byKey(OmcWidgetKeys.trackScreen),
      description: 'Return to Track after request verification',
    );

    await waits.tapAndWait(
      target: find.byKey(OmcWidgetKeys.navMore),
      destination: find.byKey(OmcWidgetKeys.moreScreen),
      description: 'Open More for customer notifications',
    );

    final alerts = find.byKey(OmcWidgetKeys.moreAction('alerts'));
    await waits.waitFor(
      alerts,
      description: 'Approved customer Alerts destination',
    );
    await waits.tapAndWait(
      target: alerts,
      destination: find.byKey(OmcWidgetKeys.notificationsScreen),
      description: 'Open customer notifications',
    );

    final paymentNotificationRow = await _findPaymentNotificationRow(
      cleanPaymentId,
    );

    expect(
      find.descendant(
        of: paymentNotificationRow.first,
        matching: find.text('Payment Receipt Accepted'),
      ),
      findsOneWidget,
      reason: 'The current E2E payment must own the accepted-receipt notification.',
    );
    waits.assertHealthy('Current customer settlement notification');

    await tester.pageBack();
    await tester.pump();
    final homeNav = find.byKey(OmcWidgetKeys.navHome);
    if (homeNav.evaluate().isEmpty) {
      await tester.pageBack();
      await tester.pump();
    }
    await waits.waitFor(homeNav, description: 'Return to protected shell');
  }

  Future<Finder> _findPaymentNotificationRow(String paymentId) async {
    for (var page = 0; page < 5; page++) {
      final row = find.ancestor(
        of: find.textContaining(paymentId),
        matching: find.byType(InkWell),
      );
      if (row.evaluate().isNotEmpty) return row;

      final loadMore = find.text('Load more');
      if (loadMore.evaluate().isEmpty) break;

      await tester.ensureVisible(loadMore.first);
      final tappableLoadMore = loadMore.hitTestable();
      if (tappableLoadMore.evaluate().isEmpty) {
        fail('Notifications has more pages but the Load more action is not tappable.');
      }
      await tester.tap(tappableLoadMore.first);
      await tester.pump();
      await waits.waitForNetworkIdle(
        description: 'Load more notifications page ${page + 2}',
        timeout: const Duration(seconds: 20),
      );
      await tester.pump(const Duration(milliseconds: 250));
    }

    fail(
      'Current payment notification for $paymentId was not found in the '
      'loaded customer notification pages.',
    );
  }
}
