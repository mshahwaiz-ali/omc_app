import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/app/route_failure_recovery.dart';
import 'package:omc_app/features/auth/application/auth_state.dart';

void main() {
  group('resolveRouteFailureRecovery', () {
    test('sends unauthenticated users to sign in', () {
      final recovery = resolveRouteFailureRecovery(
        status: AuthStatus.unauthenticated,
        capabilities: const AuthCapabilities(
          accessState: AccountAccessState.approved,
        ),
      );

      expect(recovery.location, '/login');
      expect(recovery.label, 'Go to sign in');
      expect(recovery.kind, RouteFailureRecoveryKind.signIn);
    });

    test('sends pending authenticated users to account status', () {
      final recovery = resolveRouteFailureRecovery(
        status: AuthStatus.authenticated,
        capabilities: const AuthCapabilities(
          accessState: AccountAccessState.pending,
        ),
      );

      expect(recovery.location, '/under-review');
      expect(recovery.label, 'View account status');
      expect(recovery.kind, RouteFailureRecoveryKind.accountStatus);
    });

    test('sends guest users to home', () {
      final recovery = resolveRouteFailureRecovery(
        status: AuthStatus.guest,
        capabilities: const AuthCapabilities(
          accessState: AccountAccessState.approved,
        ),
      );

      expect(recovery.location, '/home');
      expect(recovery.label, 'Go to home');
      expect(recovery.kind, RouteFailureRecoveryKind.home);
    });

    test('sends approved authenticated users to home', () {
      final recovery = resolveRouteFailureRecovery(
        status: AuthStatus.authenticated,
        capabilities: const AuthCapabilities(
          accessState: AccountAccessState.approved,
        ),
      );

      expect(recovery.location, '/home');
      expect(recovery.label, 'Go to home');
      expect(recovery.kind, RouteFailureRecoveryKind.home);
    });
  });
}
