import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/core/diagnostics/omc_widget_keys.dart';

import '../support/e2e_waits.dart';

class CustomerNotificationRobot {
  CustomerNotificationRobot(this.tester, this.waits);

  final WidgetTester tester;
  final E2eWaits waits;

  Future<void> verifyAcceptedReceiptNotification() async {
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

    await waits.waitFor(
      find.text('Payment Receipt Accepted'),
      description: 'Payment receipt accepted customer notification',
      timeout: const Duration(seconds: 20),
    );
    waits.assertHealthy('Customer settlement notification');

    await tester.pageBack();
    await tester.pump();
    final homeNav = find.byKey(OmcWidgetKeys.navHome);
    if (homeNav.evaluate().isEmpty) {
      await tester.pageBack();
      await tester.pump();
    }
    await waits.waitFor(homeNav, description: 'Return to protected shell');
  }
}
