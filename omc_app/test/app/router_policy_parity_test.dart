import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/app/route_access_policy.dart';
import 'package:omc_app/features/auth/application/auth_state.dart';

void main() {
  const registeredRouteTemplates = <String>{
    '/',
    '/onboarding',
    '/login',
    '/forgot-password',
    '/reset-password',
    '/app/reset-password',
    '/signup',
    '/verify-email',
    '/app/verify-email',
    '/under-review',
    '/home',
    '/services',
    '/track',
    '/more',
    '/services/:serviceId',
    '/services/:serviceId/request',
    '/my-services',
    '/dashboard',
    '/documents',
    '/documents/:documentId',
    '/payments',
    '/payments/:paymentId',
    '/leads',
    '/customers',
    '/tasks',
    '/leads/:leadId',
    '/customers/:customerId',
    '/tasks/:taskId',
    '/my-services/:caseId',
    '/knowledge',
    '/knowledge/:articleId',
    '/notifications',
    '/notifications/:notificationId',
    '/support',
    '/tax-calculator',
    '/tax-calculator/history',
    '/profile',
    '/profile/edit',
    '/my-referrals',
    '/my-referrals/:customerId',
    '/expense-tracker',
    '/expense-budget',
    '/support-tickets/:ticketId',
    '/settings',
    '/change-password',
    '/internal-workspace',
    '/admin-control',
    '/admin-control/operations',
    '/internal-service-requests',
    '/internal-workspace/service-cases',
    '/internal-workspace/customers',
    '/internal-workspace/documents',
    '/internal-workspace/payments',
    '/internal-workspace/service-cases/:caseId',
  };

  const routesHandledBeforeCapabilityPolicy = <String>{
    '/',
    '/onboarding',
    '/login',
    '/forgot-password',
    '/reset-password',
    '/app/reset-password',
    '/signup',
    '/verify-email',
    '/app/verify-email',
    '/under-review',
  };

  const approvedCustomer = AuthCapabilities(
    accessState: AccountAccessState.approved,
    canCreateServiceRequest: true,
    canTrackRequests: true,
    canViewDocuments: true,
    canViewPayments: true,
    canViewSupportTickets: true,
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
    canManageTasks: true,
    canManageStaff: true,
    canReviewRegistrations: true,
    canManageBusinessSettings: true,
  );

  const referralStaff = AuthCapabilities(
    accessState: AccountAccessState.internal,
    canViewRelevantCustomers: true,
  );

  const routeAudiences = <AuthCapabilities>[
    AuthCapabilities.guest,
    approvedCustomer,
    fullInternal,
    referralStaff,
  ];

  group('registered route inventory', () {
    test('router declarations exactly match the audited route registry', () {
      final routerSource = File('lib/app/router.dart').readAsStringSync();
      final routePattern = RegExp(r"path:\s*'([^']+)'");
      final declaredRoutes = routePattern
          .allMatches(routerSource)
          .map((match) => match.group(1)!)
          .toSet();

      expect(
        declaredRoutes,
        registeredRouteTemplates,
        reason:
            'A route was added, removed, or renamed. Update the access policy, '
            'navigation entry points, deep-link expectations, and this audited '
            'registry together.',
      );
    });

    test('route names remain unique', () {
      final routerSource = File('lib/app/router.dart').readAsStringSync();
      final namePattern = RegExp(r"name:\s*'([^']+)'");
      final names = namePattern
          .allMatches(routerSource)
          .map((match) => match.group(1)!)
          .toList();

      expect(names.toSet().length, names.length);
    });

    test('intentional track aliases remain registered', () {
      expect(registeredRouteTemplates, contains('/track'));
      expect(registeredRouteTemplates, contains('/my-services'));
    });

    test('obsolete profile referrals route is not registered', () {
      expect(registeredRouteTemplates, isNot(contains('/profile/referrals')));
    });
  });

  group('router and capability policy parity', () {
    for (final template in registeredRouteTemplates.difference(
      routesHandledBeforeCapabilityPolicy,
    )) {
      final sample = _sampleLocation(template);

      test('$template is reachable by at least one intended audience', () {
        final reachable = routeAudiences.any(
          (capabilities) => canAccessRoute(sample, capabilities),
        );

        expect(
          reachable,
          isTrue,
          reason:
              '$template is registered but no audited audience can access it. '
              'Either its policy is missing or the route is obsolete.',
        );
      });
    }

    test('every audited guest route maps to a registered route template', () {
      const guestSamples = <String>[
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

      for (final sample in guestSamples) {
        expect(isGuestAllowedRoute(sample), isTrue);
        expect(
          registeredRouteTemplates.any(
            (template) => _matchesTemplate(template, sample),
          ),
          isTrue,
          reason: '$sample is guest-allowed but is not registered.',
        );
      }
    });

    test('unknown and stale routes remain denied', () {
      for (final route in const [
        '/profile/referrals',
        '/future-unclassified-route',
        '/internal',
        '/service-cases',
      ]) {
        for (final capabilities in routeAudiences) {
          expect(
            canAccessRoute(route, capabilities),
            isFalse,
            reason: '$route unexpectedly became accessible.',
          );
        }
      }
    });
  });
}

String _sampleLocation(String template) {
  return template
      .replaceAll(':serviceId', 'mainland-company-setup')
      .replaceAll(':documentId', 'DOC-0001')
      .replaceAll(':paymentId', 'PAY-0001')
      .replaceAll(':leadId', 'LEAD-0001')
      .replaceAll(':customerId', 'CUST-0001')
      .replaceAll(':taskId', 'TASK-0001')
      .replaceAll(':caseId', 'CASE-0001')
      .replaceAll(':articleId', 'ARTICLE-0001')
      .replaceAll(':notificationId', 'NOTIF-0001')
      .replaceAll(':ticketId', 'SUP-0001');
}

bool _matchesTemplate(String template, String location) {
  final templateSegments = Uri.parse(template).pathSegments;
  final locationSegments = Uri.parse(location).pathSegments;

  if (templateSegments.length != locationSegments.length) return false;

  for (var index = 0; index < templateSegments.length; index++) {
    final templateSegment = templateSegments[index];
    if (templateSegment.startsWith(':')) continue;
    if (templateSegment != locationSegments[index]) return false;
  }

  return true;
}
