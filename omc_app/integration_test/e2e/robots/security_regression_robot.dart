import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/core/diagnostics/e2e_network_audit.dart';
import 'package:omc_app/core/diagnostics/omc_widget_keys.dart';

import '../support/edge_e2e_config.dart';
import '../support/e2e_record_finders.dart';
import '../support/e2e_waits.dart';

class SecurityRegressionRobot {
  SecurityRegressionRobot(this.tester, this.waits);

  final WidgetTester tester;
  final E2eWaits waits;

  Future<void> verifyLoginValidationAndRecovery(EdgeE2eConfig config) async {
    expect(find.byKey(OmcWidgetKeys.loginScreen), findsOneWidget);
    expect(E2eNetworkAudit.pendingRequestCount, 0);
    expect(E2eNetworkAudit.failures, isEmpty);

    await tester.tap(find.byKey(OmcWidgetKeys.loginSubmit));
    await tester.pump();

    expect(
      find.text('Email, username, mobile or CNIC is required.'),
      findsOneWidget,
    );
    expect(find.text('Password is required.'), findsOneWidget);
    expect(find.byKey(OmcWidgetKeys.loginScreen), findsOneWidget);
    expect(E2eNetworkAudit.pendingRequestCount, 0);
    expect(
      E2eNetworkAudit.failures,
      isEmpty,
      reason: 'Client-side required-field validation must not hit the API.',
    );

    await tester.enterText(
      find.byKey(OmcWidgetKeys.loginIdentifier),
      config.primaryUsername,
    );
    await tester.enterText(
      find.byKey(OmcWidgetKeys.loginPassword),
      config.invalidPassword,
    );
    await tester.tap(find.byKey(OmcWidgetKeys.loginSubmit));
    await tester.pump();

    await waits.waitFor(
      find.byKey(OmcWidgetKeys.loginError),
      description: 'Rejected real password login',
      timeout: const Duration(seconds: 20),
    );
    await waits.waitForNetworkIdle(
      description: 'Rejected real password login',
      timeout: const Duration(seconds: 20),
    );

    expect(
      find.text('Wrong login details or password. Please try again.'),
      findsOneWidget,
    );
    expect(find.byKey(OmcWidgetKeys.homeScreen), findsNothing);
    final authFailures = E2eNetworkAudit.failures;
    expect(
      authFailures,
      isNotEmpty,
      reason: 'The invalid password must be rejected by the real backend.',
    );
    expect(
      authFailures.any((failure) => failure.status == '401'),
      isTrue,
      reason: 'Invalid credentials are expected to be rejected with HTTP 401.',
    );

    // The 401 above is an expected negative assertion. Clear only that recorded
    // failure before proving that the same app instance can recover normally.
    E2eNetworkAudit.clear();

    await tester.enterText(
      find.byKey(OmcWidgetKeys.loginPassword),
      config.primaryPassword,
    );
    await waits.tapAndWait(
      target: find.byKey(OmcWidgetKeys.loginSubmit),
      destination: find.byKey(OmcWidgetKeys.homeScreen),
      description: 'Valid login recovery after rejected password',
    );
    waits.assertHealthy('Valid login recovery after rejected password');
  }

  Future<void> verifyOtherCustomerIsolation(EdgeE2eConfig config) async {
    await waits.tapAndWait(
      target: find.byKey(OmcWidgetKeys.navTrack),
      destination: find.byKey(OmcWidgetKeys.trackScreen),
      description: 'Other customer -> Track',
    );

    final search = find.byType(TextField);
    await waits.waitFor(search, description: 'Other customer request search');
    await tester.enterText(search.first, config.requestId.trim());
    await tester.pump(const Duration(milliseconds: 500));
    await waits.waitForNetworkIdle(description: 'Other customer isolation search');
    waits.assertHealthy('Other customer isolation search');

    expect(
      E2eRecordFinders.requestCard(config.requestId),
      findsNothing,
      reason: 'A different customer must not see the primary customer request card.',
    );

    await waits.tapAndWait(
      target: find.byKey(OmcWidgetKeys.navMore),
      destination: find.byKey(OmcWidgetKeys.moreScreen),
      description: 'Other customer -> More',
    );

    for (final actionId in const [
      'workspace',
      'customers',
      'tasks',
      'reviewPayments',
      'reviewDocuments',
      'commissionOperations',
      'leads',
    ]) {
      expect(
        find.byKey(OmcWidgetKeys.moreAction(actionId)),
        findsNothing,
        reason: 'Normal customer must not receive internal More action $actionId.',
      );
    }
    waits.assertHealthy('Other customer internal-menu isolation');
  }
}
