import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/app/route_access_policy.dart';
import 'package:omc_app/features/auth/application/auth_state.dart';

void main() {
  group('canAccessRoute', () {
    const internalWorkspaceOnly = AuthCapabilities(
      accessState: AccountAccessState.internal,
      canAccessInternalWorkspace: true,
    );

    test('does not let broad internal access unlock management routes', () {
      expect(canAccessRoute('/leads', internalWorkspaceOnly), isFalse);
      expect(canAccessRoute('/customers', internalWorkspaceOnly), isFalse);
      expect(canAccessRoute('/tasks', internalWorkspaceOnly), isFalse);
    });

    test('requires explicit payment capability', () {
      expect(canAccessRoute('/payments', internalWorkspaceOnly), isFalse);

      const reviewer = AuthCapabilities(
        accessState: AccountAccessState.internal,
        canReviewPayments: true,
      );
      expect(canAccessRoute('/payments', reviewer), isTrue);
    });

    test('requires explicit tracking capability', () {
      const approvedWithoutTracking = AuthCapabilities(
        accessState: AccountAccessState.approved,
      );
      expect(canAccessRoute('/my-services', approvedWithoutTracking), isFalse);

      const approvedWithTracking = AuthCapabilities(
        accessState: AccountAccessState.approved,
        canTrackRequests: true,
      );
      expect(canAccessRoute('/my-services', approvedWithTracking), isTrue);
    });

    test('allows support operations through explicit status capability', () {
      const supportManager = AuthCapabilities(
        accessState: AccountAccessState.internal,
        canUpdateSupportTicketStatus: true,
      );
      expect(
        canAccessRoute('/support-tickets/OMC-SUP-0001', supportManager),
        isTrue,
      );
    });

    test('keeps public guest routes available', () {
      expect(canAccessRoute('/services', AuthCapabilities.guest), isTrue);
      expect(
        canAccessRoute(
          '/services/mainland-company-setup',
          AuthCapabilities.guest,
        ),
        isTrue,
      );
      expect(
        canAccessRoute(
          '/services/mainland-company-setup/request',
          AuthCapabilities.guest,
        ),
        isFalse,
      );
    });
  });
}
