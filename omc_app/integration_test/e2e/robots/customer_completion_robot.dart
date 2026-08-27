import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/core/diagnostics/omc_widget_keys.dart';

import '../support/e2e_waits.dart';

class CustomerCompletionRobot {
  CustomerCompletionRobot(this.tester, this.waits);

  final WidgetTester tester;
  final E2eWaits waits;

  Future<void> verifyCompletedRequest(String requestId) async {
    await waits.tapAndWait(
      target: find.byKey(OmcWidgetKeys.navTrack),
      destination: find.byKey(OmcWidgetKeys.trackScreen),
      description: 'Customer completion -> Track',
    );

    final search = find.byType(TextField);
    await waits.waitFor(search, description: 'Customer completion search');
    await tester.enterText(search.first, requestId.trim());
    await tester.pump(const Duration(milliseconds: 500));
    await waits.waitForNetworkIdle(description: 'Filtered completed request');

    final reference = find.text(requestId.trim());
    await waits.waitFor(
      reference,
      description: 'Completed request $requestId',
      timeout: const Duration(seconds: 20),
    );
    expect(
      find.text('Completed'),
      findsWidgets,
      reason: 'ERP Task completion must propagate to customer tracking.',
    );

    final viewDetails = find.text('View details');
    await waits.waitFor(viewDetails, description: 'Open completed request detail');
    await tester.ensureVisible(viewDetails.first);
    await tester.tap(viewDetails.first.hitTestable());
    await tester.pump();

    await waits.waitFor(
      find.text('Service journey'),
      description: 'Completed request detail',
      timeout: const Duration(seconds: 20),
    );
    await waits.waitForNetworkIdle(description: 'Completed request detail');
    expect(find.text(requestId.trim()), findsWidgets);
    expect(find.text('Completed'), findsWidgets);
    expect(
      find.text('Paid'),
      findsWidgets,
      reason: 'Completing work must not lose authoritative settlement state.',
    );
    waits.assertHealthy('Customer completed request projection');
  }
}
