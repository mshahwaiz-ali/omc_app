import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/app/route_access_policy.dart';
import 'package:omc_app/features/auth/application/auth_state.dart';

void main() {
  group('canAccessRoute', () {
    test('admin control requires a dedicated administrative capability', () {
      const ordinaryInternal = AuthCapabilities(
        accessState: AccountAccessState.internal,
        canAccessInternalWorkspace: true,
      );
      const omcAdmin = AuthCapabilities(
        accessState: AccountAccessState.internal,
        canManageStaff: true,
      );

      expect(canAccessRoute('/admin-control', ordinaryInternal), isFalse);
      expect(canAccessRoute('/admin-control', omcAdmin), isTrue);
    });

    test('operational controls use granular manager capabilities', () {
      const ordinaryInternal = AuthCapabilities(
        accessState: AccountAccessState.internal,
        canAccessInternalWorkspace: true,
      );
      const manager = AuthCapabilities(
        accessState: AccountAccessState.internal,
        canReassignServiceCases: true,
        canRetrySync: true,
      );
      const businessAdmin = AuthCapabilities(
        accessState: AccountAccessState.internal,
        canManageBusinessSettings: true,
      );

      expect(
        canAccessRoute('/admin-control/operations', ordinaryInternal),
        isFalse,
      );
      expect(canAccessRoute('/admin-control/operations', manager), isTrue);
      expect(
        canAccessRoute('/admin-control/operations', businessAdmin),
        isTrue,
      );
    });

    const internalWorkspaceOnly = AuthCapabilities(
      accessState: AccountAccessState.internal,
      canAccessInternalWorkspace: true,
    );

    test('does not let broad internal access unlock management routes', () {
      expect(canAccessRoute('/leads', internalWorkspaceOnly), isFalse);
      expect(canAccessRoute('/customers', internalWorkspaceOnly), isFalse);
      expect(canAccessRoute('/tasks', internalWorkspaceOnly), isFalse);
    });

    test('does not let broad internal access unlock scoped workspaces', () {
      expect(
        canAccessRoute('/internal-workspace/customers', internalWorkspaceOnly),
        isFalse,
      );
      expect(
        canAccessRoute('/internal-workspace/documents', internalWorkspaceOnly),
        isFalse,
      );
      expect(
        canAccessRoute('/internal-workspace/payments', internalWorkspaceOnly),
        isFalse,
      );
      expect(
        canAccessRoute('/internal-workspace/future-area', internalWorkspaceOnly),
        isFalse,
      );
    });

    test('requires explicit payment capability', () {
      expect(canAccessRoute('/payments', internalWorkspaceOnly), isFalse);

      const reviewer = AuthCapabilities(
        accessState: AccountAccessState.internal,
        canReviewPayments: true,
      );
      expect(canAccessRoute('/payments', reviewer), isTrue);
      expect(
        canAccessRoute('/internal-workspace/payments', reviewer),
        isTrue,
      );
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

    test(
      'allows customer request creation for explicitly capable internal users',
      () {
        const internalCreator = AuthCapabilities(
          accessState: AccountAccessState.internal,
          canCreateServiceForCustomer: true,
        );

        expect(
          canAccessRoute(
            '/services/mainland-company-setup/request',
            internalCreator,
          ),
          isTrue,
        );
      },
    );

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

    test('customer support capability permits owned ticket detail route', () {
      const customer = AuthCapabilities(
        accessState: AccountAccessState.approved,
        canCreateSupportTicket: true,
      );

      expect(
        canAccessRoute('/support-tickets/OMC-SUP-0001', customer),
        isTrue,
      );
    });

    test('internal workspace access does not imply notification authority', () {
      expect(
        canAccessRoute('/notifications', internalWorkspaceOnly),
        isFalse,
      );

      const customer = AuthCapabilities(
        accessState: AccountAccessState.approved,
        canViewCustomerNotifications: true,
      );
      expect(canAccessRoute('/notifications', customer), isTrue);
    });

    test('keeps public guest routes available', () {
      expect(canAccessRoute('/services', AuthCapabilities.guest), isTrue);
      expect(
        canAccessRoute('/expense-tracker', AuthCapabilities.guest),
        isTrue,
      );
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

    test('allows expense utilities for customers and internal staff', () {
      const approvedCustomer = AuthCapabilities(
        accessState: AccountAccessState.approved,
      );
      const internalUser = AuthCapabilities(
        accessState: AccountAccessState.internal,
        canAccessInternalWorkspace: true,
      );

      expect(canAccessRoute('/expense-tracker', approvedCustomer), isTrue);
      expect(canAccessRoute('/expense-tracker', internalUser), isTrue);
      expect(canAccessRoute('/expense-budget', approvedCustomer), isTrue);
      expect(canAccessRoute('/expense-budget', internalUser), isTrue);
    });

    test('uses my-referrals as the only referrals route', () {
      const referralUser = AuthCapabilities(
        accessState: AccountAccessState.internal,
        canOwnReferrals: true,
        canViewRelevantCustomers: true,
      );
      const customerViewerOnly = AuthCapabilities(
        accessState: AccountAccessState.internal,
        canViewRelevantCustomers: true,
      );

      expect(canAccessRoute('/my-referrals', referralUser), isTrue);
      expect(canAccessRoute('/my-referrals/CUST-0001', referralUser), isTrue);
      expect(canAccessRoute('/profile/referrals', referralUser), isFalse);
      expect(canAccessRoute('/my-referrals', customerViewerOnly), isFalse);
    });

    test('allows authenticated account routes explicitly', () {
      const pending = AuthCapabilities(
        accessState: AccountAccessState.pending,
        canUseTaxCalculator: true,
      );

      expect(canAccessRoute('/profile', pending), isTrue);
      expect(canAccessRoute('/profile/edit', pending), isTrue);
      expect(canAccessRoute('/settings', pending), isTrue);
      expect(canAccessRoute('/change-password', pending), isTrue);
      expect(canAccessRoute('/tax-calculator/history', pending), isTrue);
    });

    test('denies calculator history without calculator capability', () {
      const authenticated = AuthCapabilities(
        accessState: AccountAccessState.approved,
        canUseTaxCalculator: false,
      );

      expect(canAccessRoute('/tax-calculator/history', authenticated), isFalse);
    });

    test('denies unknown authenticated routes by default', () {
      const internal = AuthCapabilities(
        accessState: AccountAccessState.internal,
        canAccessInternalWorkspace: true,
      );

      expect(canAccessRoute('/future-unclassified-route', internal), isFalse);
    });
  });
}
