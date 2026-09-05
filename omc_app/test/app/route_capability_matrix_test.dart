import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/app/auth_route_redirect.dart';
import 'package:omc_app/app/route_access_policy.dart';
import 'package:omc_app/features/auth/application/auth_state.dart';

void main() {
  const guest = AuthCapabilities.guest;

  const pending = AuthCapabilities(accessState: AccountAccessState.pending);

  const approvedCustomer = AuthCapabilities(
    accessState: AccountAccessState.approved,
    canCreateServiceRequest: true,
    canTrackRequests: true,
    canViewDocuments: true,
    canViewPayments: true,
    canCreateSupportTicket: true,
    canViewCustomerDashboard: true,
    canViewCustomerNotifications: true,
    canUseTaxCalculator: true,
  );

  const fullInternal = AuthCapabilities(
    accessState: AccountAccessState.internal,
    canAccessInternalWorkspace: true,
    canCreateServiceForCustomer: true,
    canViewAllServiceCases: true,
    canViewDocumentQueue: true,
    canReviewDocuments: true,
    canViewPaymentQueue: true,
    canReviewPayments: true,
    canViewSupportTickets: true,
    canReplySupportTickets: true,
    canUpdateSupportTicketStatus: true,
    canAssignSupportTickets: true,
    canManageCustomers: true,
    canViewAllCustomers: true,
    canManageLeads: true,
    canViewTasks: true,
    canManageTasks: true,
  );

  const assignedCaseStaff = AuthCapabilities(
    accessState: AccountAccessState.internal,
    canViewAssignedServiceCases: true,
  );

  const taskTrackingStaff = AuthCapabilities(
    accessState: AccountAccessState.internal,
    canViewTasks: true,
  );

  const documentSummaryStaff = AuthCapabilities(
    accessState: AccountAccessState.internal,
    canViewDocumentSummaries: true,
  );

  const paymentSummaryStaff = AuthCapabilities(
    accessState: AccountAccessState.internal,
    canViewPaymentSummaries: true,
  );

  const referralStaff = AuthCapabilities(
    accessState: AccountAccessState.internal,
    canOwnReferrals: true,
    canViewRelevantCustomers: true,
  );

  group('guest route matrix', () {
    const allowed = <String>[
      '/home',
      '/services',
      '/services/mainland-company-setup',
      '/more',
      '/knowledge',
      '/knowledge/article-1',
      '/tax-calculator',
      '/expense-tracker',
      '/support',
    ];

    const denied = <String>[
      '/services/mainland-company-setup/request',
      '/track',
      '/my-services',
      '/my-services/CASE-0001',
      '/documents',
      '/documents/DOC-0001',
      '/payments',
      '/payments/PAY-0001',
      '/notifications',
      '/notifications/NOTIF-0001',
      '/support-tickets/SUP-0001',
      '/dashboard',
      '/profile',
      '/profile/edit',
      '/settings',
      '/change-password',
      '/expense-budget',
      '/tax-calculator/history',
      '/internal-workspace',
      '/internal-workspace/service-cases',
      '/internal-workspace/service-cases/CASE-0001',
      '/internal-workspace/customers',
      '/internal-workspace/documents',
      '/internal-workspace/payments',
      '/admin-control/operations',
      '/leads',
      '/customers',
      '/tasks',
      '/my-referrals',
    ];

    for (final route in allowed) {
      test('allows $route', () {
        expect(canAccessRoute(route, guest), isTrue);
      });
    }

    for (final route in denied) {
      test('denies $route', () {
        expect(canAccessRoute(route, guest), isFalse);
      });
    }
  });

  group('approved customer route matrix', () {
    const allowed = <String>[
      '/home',
      '/services',
      '/services/mainland-company-setup',
      '/services/mainland-company-setup/request',
      '/track',
      '/my-services',
      '/my-services/CASE-0001',
      '/documents',
      '/documents/DOC-0001',
      '/payments',
      '/payments/PAY-0001',
      '/notifications',
      '/notifications/NOTIF-0001',
      '/support',
      '/support-tickets/SUP-0001',
      '/dashboard',
      '/profile',
      '/profile/edit',
      '/settings',
      '/change-password',
      '/tax-calculator',
      '/tax-calculator/history',
      '/expense-tracker',
      '/expense-budget',
      '/knowledge',
      '/knowledge/article-1',
    ];

    const denied = <String>[
      '/internal-workspace',
      '/internal-workspace/service-cases',
      '/internal-workspace/service-cases/CASE-0001',
      '/internal-workspace/customers',
      '/internal-workspace/documents',
      '/internal-workspace/payments',
      '/admin-control/operations',
      '/leads',
      '/leads/LEAD-0001',
      '/customers',
      '/customers/CUST-0001',
      '/tasks',
      '/tasks/TASK-0001',
      '/my-referrals',
      '/my-referrals/CUST-0001',
    ];

    for (final route in allowed) {
      test('allows $route', () {
        expect(canAccessRoute(route, approvedCustomer), isTrue);
      });
    }

    for (final route in denied) {
      test('denies $route', () {
        expect(canAccessRoute(route, approvedCustomer), isFalse);
      });
    }
  });

  group('full internal route matrix', () {
    const allowed = <String>[
      '/home',
      '/services',
      '/services/mainland-company-setup',
      '/services/mainland-company-setup/request',
      '/documents',
      '/documents/DOC-0001',
      '/payments',
      '/payments/PAY-0001',
      '/support',
      '/support-tickets/SUP-0001',
      '/dashboard',
      '/profile',
      '/profile/edit',
      '/settings',
      '/change-password',
      '/tax-calculator',
      '/tax-calculator/history',
      '/expense-tracker',
      '/knowledge',
      '/knowledge/article-1',
      '/internal-workspace',
      '/internal-workspace/service-cases',
      '/internal-workspace/service-cases/CASE-0001',
      '/internal-workspace/customers',
      '/internal-workspace/documents',
      '/internal-workspace/payments',
      '/leads',
      '/leads/LEAD-0001',
      '/customers',
      '/customers/CUST-0001',
      '/tasks',
      '/tasks/TASK-0001',
      '/track',
      '/my-services/CASE-0001',
    ];

    const denied = <String>[
      '/notifications',
      '/notifications/NOTIF-0001',
      '/my-services',
      '/my-referrals',
      '/my-referrals/CUST-0001',
      '/expense-budget',
    ];

    for (final route in allowed) {
      test('allows $route', () {
        expect(canAccessRoute(route, fullInternal), isTrue);
      });
    }

    for (final route in denied) {
      test('denies $route', () {
        expect(canAccessRoute(route, fullInternal), isFalse);
      });
    }
  });

  group('least-privilege internal capability routes', () {
    test('assigned case staff may open only service-case workspace routes', () {
      expect(
        canAccessRoute('/internal-workspace/service-cases', assignedCaseStaff),
        isTrue,
      );
      expect(
        canAccessRoute(
          '/internal-workspace/service-cases/CASE-0001',
          assignedCaseStaff,
        ),
        isTrue,
      );
      expect(canAccessRoute('/internal-workspace', assignedCaseStaff), isFalse);
      expect(canAccessRoute('/customers', assignedCaseStaff), isFalse);
    });

    test('task tracking staff may open task list and detail routes', () {
      expect(canAccessRoute('/tasks', taskTrackingStaff), isTrue);
      expect(canAccessRoute('/tasks/TASK-0001', taskTrackingStaff), isTrue);
      expect(canAccessRoute('/leads', taskTrackingStaff), isFalse);
    });

    test('document summary capability unlocks document routes only', () {
      expect(canAccessRoute('/documents', documentSummaryStaff), isTrue);
      expect(
        canAccessRoute('/documents/DOC-0001', documentSummaryStaff),
        isTrue,
      );
      expect(
        canAccessRoute('/internal-workspace/documents', documentSummaryStaff),
        isTrue,
      );
      expect(canAccessRoute('/payments', documentSummaryStaff), isFalse);
    });

    test('payment summary capability unlocks payment routes only', () {
      expect(canAccessRoute('/payments', paymentSummaryStaff), isTrue);
      expect(canAccessRoute('/payments/PAY-0001', paymentSummaryStaff), isTrue);
      expect(
        canAccessRoute('/internal-workspace/payments', paymentSummaryStaff),
        isTrue,
      );
      expect(canAccessRoute('/documents', paymentSummaryStaff), isFalse);
    });

    test('referral staff use only the canonical my-referrals routes', () {
      expect(canAccessRoute('/my-referrals', referralStaff), isTrue);
      expect(canAccessRoute('/my-referrals/CUST-0001', referralStaff), isTrue);
      expect(canAccessRoute('/profile/referrals', referralStaff), isFalse);
      expect(canAccessRoute('/customers', referralStaff), isTrue);
    });
  });

  group('pending and rejected account restrictions', () {
    const rejected = AuthCapabilities(accessState: AccountAccessState.rejected);

    for (final capabilities in [pending, rejected]) {
      test(
        '${capabilities.accessState} keeps account self-service available',
        () {
          expect(canAccessRoute('/profile', capabilities), isTrue);
          expect(canAccessRoute('/profile/edit', capabilities), isTrue);
          expect(canAccessRoute('/settings', capabilities), isTrue);
          expect(canAccessRoute('/change-password', capabilities), isTrue);
        },
      );

      test('${capabilities.accessState} cannot access approved services', () {
        expect(canAccessRoute('/my-services', capabilities), isFalse);
        expect(canAccessRoute('/documents', capabilities), isFalse);
        expect(canAccessRoute('/payments', capabilities), isFalse);
        expect(canAccessRoute('/expense-budget', capabilities), isFalse);
      });
    }
  });

  group('redirect integration matrix', () {
    String? redirect(
      AuthStatus status,
      String route,
      AuthCapabilities capabilities,
    ) {
      return resolveAuthRouteRedirect(
        status: status,
        capabilities: capabilities,
        location: route,
      );
    }

    test('guest forbidden routes return to home', () {
      expect(
        redirect(AuthStatus.guest, '/documents', guest),
        '/home?notice=access-denied',
      );
    });

    test('pending authenticated routes return to under-review', () {
      expect(
        redirect(AuthStatus.authenticated, '/documents', pending),
        '/under-review',
      );
    });

    test('approved forbidden internal routes return to home', () {
      expect(
        redirect(
          AuthStatus.authenticated,
          '/internal-workspace',
          approvedCustomer,
        ),
        '/home?notice=access-denied',
      );
    });

    test('authorised routes are retained', () {
      expect(
        redirect(AuthStatus.authenticated, '/documents', approvedCustomer),
        isNull,
      );
      expect(
        redirect(AuthStatus.authenticated, '/internal-workspace', fullInternal),
        isNull,
      );
    });
  });
}
