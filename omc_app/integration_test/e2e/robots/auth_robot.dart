import 'package:flutter/widgets.dart';
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

    final submit = find.byKey(OmcWidgetKeys.loginSubmit);
    await waits.waitFor(submit, description: 'Real password login action');
    await tester.ensureVisible(submit);
    final tappableSubmit = submit.hitTestable();
    if (tappableSubmit.evaluate().isEmpty) {
      fail('Real password login action rendered but was not tappable.');
    }
    await tester.tap(tappableSubmit.first);
    await tester.pump();

    final state = await waits.waitForAny(
      {
        'home': find.byKey(OmcWidgetKeys.homeScreen),
        'login-error': find.byKey(OmcWidgetKeys.loginError),
        'device-lock': find.byKey(OmcWidgetKeys.deviceLockScreen),
        'under-review': find.byKey(OmcWidgetKeys.underReviewScreen),
        'startup-error': find.byKey(OmcWidgetKeys.startupError),
        'route-failure': find.byKey(OmcWidgetKeys.routeFailure),
      },
      description: 'Real password login result',
      timeout: const Duration(seconds: 30),
    );

    if (state != 'home') {
      if (state == 'login-error') {
        final messages = find
            .descendant(
              of: find.byKey(OmcWidgetKeys.loginError),
              matching: find.byType(Text),
            )
            .evaluate()
            .map((element) => element.widget)
            .whereType<Text>()
            .map((widget) => widget.data)
            .whereType<String>()
            .where((message) => message.trim().isNotEmpty)
            .join(' | ');
        fail(
          'Real password login was rejected by the app'
          '${messages.isEmpty ? '.' : ': $messages'}',
        );
      }
      fail('Real password login reached unexpected state: $state.');
    }

    await waits.waitForScreen(
      find.byKey(OmcWidgetKeys.homeScreen),
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
    if (find.byKey(OmcWidgetKeys.moreScreen).evaluate().isEmpty) {
      await waits.tapAndWait(
        target: find.byKey(OmcWidgetKeys.navMore),
        destination: find.byKey(OmcWidgetKeys.moreScreen),
        description: 'Open More for logout',
      );
    }
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
