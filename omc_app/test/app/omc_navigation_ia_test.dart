import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/app/navigation/omc_navigation_ia.dart';
import 'package:omc_app/features/auth/application/auth_state.dart';

const features = OmcNavigationFeatureFlags(
  paymentsEnabled: true,
  expenseTrackerEnabled: true,
  knowledgeEnabled: true,
  supportEnabled: true,
);

void main() {
  test(
    'approved customer More excludes persistent bottom-nav destinations',
    () {
      const customer = AuthCapabilities(
        accessState: AccountAccessState.approved,
        canViewDocuments: true,
        canViewPayments: true,
        canViewCustomerNotifications: true,
        canUseTaxCalculator: true,
        canCreateSupportTicket: true,
      );

      final groups = buildOmcMoreNavigation(
        capabilities: customer,
        features: features,
        isGuest: false,
      );
      final labels = groups
          .expand((group) => group.items)
          .map((item) => item.label);

      expect(labels, containsAll(['Documents', 'Payments', 'Alerts']));
      expect(labels, isNot(contains('Dashboard')));
      expect(labels, isNot(contains('Services')));
      expect(labels, isNot(contains('Requests')));
    },
  );

  test(
    'finance More exposes finance work without unrelated management areas',
    () {
      const finance = AuthCapabilities(
        accessState: AccountAccessState.internal,
        canAccessInternalWorkspace: true,
        canViewPaymentQueue: true,
        canReviewPayments: true,
        canReconcileSettlement: true,
        canUseTaxCalculator: true,
      );

      final groups = buildOmcMoreNavigation(
        capabilities: finance,
        features: features,
        isGuest: false,
      );
      final labels = groups
          .expand((group) => group.items)
          .map((item) => item.label);

      expect(labels, contains('Workspace'));
      expect(labels, contains('Payments'));
      expect(labels, isNot(contains('Customers')));
      expect(labels, isNot(contains('Leads')));
      expect(labels, isNot(contains('Documents')));
    },
  );

  test('support More stays support scoped', () {
    const support = AuthCapabilities(
      accessState: AccountAccessState.internal,
      canAccessInternalWorkspace: true,
      canViewSupportTickets: true,
      canReplySupportTickets: true,
      canUseTaxCalculator: true,
    );

    final groups = buildOmcMoreNavigation(
      capabilities: support,
      features: features,
      isGuest: false,
    );
    final labels = groups
        .expand((group) => group.items)
        .map((item) => item.label);

    expect(labels, containsAll(['Workspace', 'Support', 'Settings', 'Logout']));
    expect(labels, isNot(contains('Payments')));
    expect(labels, isNot(contains('Documents')));
    expect(labels, isNot(contains('Customers')));
  });

  test(
    'internal Quick Actions contain executable work instead of menu clones',
    () {
      const staff = AuthCapabilities(
        accessState: AccountAccessState.internal,
        canAccessInternalWorkspace: true,
        canCreateServiceForCustomer: true,
        canReviewDocuments: true,
        canViewTasks: true,
        canViewRelevantCustomers: true,
      );

      final actions = buildOmcQuickActions(staff);
      final ids = actions.map((item) => item.id).toSet();

      expect(ids, contains(OmcNavigationActionId.startRequest));
      expect(ids, contains(OmcNavigationActionId.reviewDocuments));
      expect(ids, contains(OmcNavigationActionId.tasks));
      expect(ids, isNot(contains(OmcNavigationActionId.customers)));
      expect(ids, isNot(contains(OmcNavigationActionId.workspace)));
    },
  );

  test(
    'approved customer Quick Actions omit Requests navigation duplicate',
    () {
      const customer = AuthCapabilities(
        accessState: AccountAccessState.approved,
        canCreateServiceRequest: true,
        canUploadDocuments: true,
        canViewPayments: true,
        canCreateSupportTicket: true,
        canUseTaxCalculator: true,
        canTrackRequests: true,
      );

      final actions = buildOmcQuickActions(customer);
      final labels = actions.map((item) => item.label);

      expect(
        labels,
        containsAll(['Apply', 'Documents', 'Payments', 'Support']),
      );
      expect(labels, isNot(contains('Track')));
      expect(labels, isNot(contains('Requests')));
    },
  );
}
