import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late String router;
  late String redirect;
  late String recovery;
  late String shell;
  late String policy;
  late String effectiveCapabilities;

  setUpAll(() {
    router = File('lib/app/router.dart').readAsStringSync();
    redirect = File('lib/app/auth_route_redirect.dart').readAsStringSync();
    recovery = File('lib/app/route_failure_recovery.dart').readAsStringSync();
    shell = File('lib/app/main_shell.dart').readAsStringSync();
    policy = File('lib/app/route_access_policy.dart').readAsStringSync();
    effectiveCapabilities = File(
      'lib/app/providers/effective_capabilities_provider.dart',
    ).readAsStringSync();
  });

  group('Batch D navigation hardening contract', () {
    test('route failures remain capability-aware and recoverable', () {
      expect(router, contains('errorBuilder:'));
      expect(router, contains('RouteFailureScreen'));
      expect(router, contains('effectiveCapabilitiesProvider'));
      expect(router, contains('resolveRouteFailureRecovery'));
      expect(recovery, contains('RouteFailureRecoveryKind'));
      expect(recovery, contains("'/login'"));
      expect(recovery, contains("'/under-review'"));
      expect(recovery, contains("'/home'"));
    });

    test('forbidden routes preserve one-time access feedback', () {
      expect(redirect, contains('_accessDeniedHome'));
      expect(redirect, contains('/home?notice=access-denied'));
      expect(
        router,
        contains("state.uri.queryParameters['notice'] == 'access-denied'"),
      );
      expect(shell, contains('showAccessDeniedNotice'));
      expect(shell, contains('_showLockedSnack(_currentCapabilities())'));
    });

    test('canonical capability authority remains wired through navigation', () {
      expect(effectiveCapabilities, contains('effectiveCapabilitiesProvider'));
      expect(router, contains('effectiveCapabilitiesProvider'));
      expect(shell, contains('effectiveCapabilitiesProvider'));
      expect(shell, isNot(contains('profile?.capabilities ??')));
    });

    test('/more remains a guarded modal route rather than fake tab four', () {
      expect(router, contains("showMoreOnLoad: state.uri.path == '/more'"));
      expect(router, contains('StatefulShellRoute.indexedStack('));
      expect(router, isNot(contains('MainShell(initialIndex: 4)')));
      expect(shell, contains('bool _isMoreSheetOpen = false;'));
      expect(shell, contains('if (_isMoreSheetOpen) return;'));
      expect(shell, contains('await showOmcMoreSheet('));
      expect(shell, contains("state.uri.path == '/more'"));
      expect(shell, contains("context.go('/home')"));
      expect(shell, isNot(contains('widget.initialIndex == 4')));
    });

    test('known route-policy cleanup remains intact', () {
      expect(policy, contains("'/expense-tracker'"));
      expect(router, isNot(contains("'/profile/referrals'")));
      expect(shell, isNot(contains("'/profile/referrals'")));
    });
  });
}
