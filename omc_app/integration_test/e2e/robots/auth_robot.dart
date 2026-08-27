import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/core/diagnostics/omc_widget_keys.dart';

import '../support/e2e_config.dart';
import '../support/e2e_waits.dart';

class AuthRobot {
  AuthRobot(this.tester, this.waits);

  final WidgetTester tester;
  final E2eWaits waits;

  Future<void> ensureLoggedOut() async {
    final state = await waits.waitForAny({
      'login': find.byKey(OmcWidgetKeys.loginScreen),
      'onboarding': find.byKey(OmcWidgetKeys.onboardingScreen),
      'device-lock': find.byKey(OmcWidgetKeys.deviceLockScreen),
      'under-review': find.byKey(OmcWidgetKeys.underReviewScreen),
      'authenticated-home': find.byKey(OmcWidgetKeys.homeScreen),
      'startup-error': find.byKey(OmcWidgetKeys.startupError),
      'route-failure': find.byKey(OmcWidgetKeys.routeFailure),
    }, description: 'App startup');

    switch (state) {
      case 'login':
        break;
      case 'onboarding':
        await waits.tapAndWait(
          target: find.byKey(OmcWidgetKeys.onboardingSkip),
          destination: find.byKey(OmcWidgetKeys.loginScreen),
          description: 'Onboarding -> Login',
        );
      case 'device-lock':
        await waits.tapAndWait(
          target: find.byKey(OmcWidgetKeys.deviceLockUseAnotherAccount),
          destination: find.byKey(OmcWidgetKeys.loginScreen),
          description: 'Device lock -> Use another account',
        );
      case 'under-review':
        await waits.tapAndWait(
          target: find.byKey(OmcWidgetKeys.underReviewLogout),
          destination: find.byKey(OmcWidgetKeys.loginScreen),
          description: 'Under review -> Sign out',
        );
      case 'authenticated-home':
        await _logoutCurrentSession();
      case 'startup-error':
      case 'route-failure':
        waits.assertHealthy('App startup');
    }

    await waits.waitForScreen(
      find.byKey(OmcWidgetKeys.loginScreen),
      description: 'Deterministic logged-out state',
    );
  }

  Future<void> login(E2eConfig config) async {
    await tester.enterText(
      find.byKey(OmcWidgetKeys.loginIdentifier),
      config.username,
    );
    await tester.enterText(
      find.byKey(OmcWidgetKeys.loginPassword),
      config.password,
    );
    await tester.pump();

    await waits.tapAndWait(
      target: find.byKey(OmcWidgetKeys.loginSubmit),
      destination: find.byKey(OmcWidgetKeys.homeScreen),
      description: 'Real password login -> Home',
    );
  }

  Future<void> logoutAndVerifyProtection() async {
    await _logoutCurrentSession();
    expect(
      find.byKey(OmcWidgetKeys.homeScreen),
      findsNothing,
      reason: 'Home must be removed after logout.',
    );
    expect(
      find.byKey(OmcWidgetKeys.navHome),
      findsNothing,
      reason: 'Protected shell navigation must be removed after logout.',
    );
    waits.assertHealthy('Logout and protected-shell removal');
  }

  Future<void> _logoutCurrentSession() async {
    await waits.tapAndWait(
      target: find.byKey(OmcWidgetKeys.navMore),
      destination: find.byKey(OmcWidgetKeys.moreScreen),
      description: 'Open More for logout',
    );
    final logout = find.byKey(OmcWidgetKeys.moreAction('logout'));
    final login = find.byKey(OmcWidgetKeys.moreAction('login'));
    final action = logout.evaluate().isNotEmpty ? logout : login;
    if (action.evaluate().isEmpty) {
      fail('More did not expose Login or Logout for the current session.');
    }
    await waits.tapAndWait(
      target: action,
      destination: find.byKey(OmcWidgetKeys.loginScreen),
      description:
          'More -> ${logout.evaluate().isNotEmpty ? 'Logout' : 'Login'}',
    );
  }
}
