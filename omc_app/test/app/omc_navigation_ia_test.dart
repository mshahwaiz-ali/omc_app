import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/app/navigation/omc_navigation_ia.dart';
import 'package:omc_app/features/auth/application/auth_state.dart';

const features = OmcNavigationFeatureFlags(
  paymentsEnabled: true,
  expenseTrackerEnabled: true,
  knowledgeEnabled: true,
  supportEnabled: true,
  taxCalculatorEnabled: true,
  internalWorkspaceEnabled: true,
);

const disabledFeatures = OmcNavigationFeatureFlags(
  paymentsEnabled: false,
  expenseTrackerEnabled: false,
  knowledgeEnabled: false,
  supportEnabled: false,
  taxCalculatorEnabled: false,
  internalWorkspaceEnabled: false,
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

  test('approved customer More keeps tax and knowledge first-level', () {
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

    expect(groups.map((group) => group.title).toList(), [
      'My OMC',
      'Tax & knowledge',
      'Tools & help',
      'Account',
    ]);
    final taxKnowledge = groups.singleWhere(
      (group) => group.title == 'Tax & knowledge',
    );
    expect(
      taxKnowledge.items.map((item) => item.label),
      containsAllInOrder(['Tax calculator', 'Knowledge & news']),
    );
    expect(groups.first.items.map((item) => item.label), contains('Alerts'));
  });

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
      expect(labels, contains('Tax calculator'));
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

      final actions = buildOmcQuickActions(staff, features: features);
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

      final actions = buildOmcQuickActions(customer, features: features);
      final labels = actions.map((item) => item.label);

      expect(
        labels,
        containsAll(['Apply', 'Documents', 'Payments', 'Support']),
      );
      expect(labels, isNot(contains('Track')));
      expect(labels, isNot(contains('Requests')));
    },
  );

  test('customer More hides feature-disabled routes but keeps Documents', () {
    const customer = AuthCapabilities(
      accessState: AccountAccessState.approved,
      canViewDocuments: true,
      canViewPayments: true,
      canCreateSupportTicket: true,
      canUseTaxCalculator: true,
    );

    final groups = buildOmcMoreNavigation(
      capabilities: customer,
      features: disabledFeatures,
      isGuest: false,
    );
    final ids = groups
        .expand((group) => group.items)
        .map((item) => item.id)
        .toSet();

    expect(ids, contains(OmcNavigationActionId.documents));
    expect(ids, isNot(contains(OmcNavigationActionId.payments)));
    expect(ids, isNot(contains(OmcNavigationActionId.tax)));
    expect(ids, isNot(contains(OmcNavigationActionId.knowledge)));
    expect(ids, isNot(contains(OmcNavigationActionId.support)));
  });

  test(
    'internal More hides internal-feature routes but keeps capability-only work',
    () {
      const staff = AuthCapabilities(
        accessState: AccountAccessState.internal,
        canAccessInternalWorkspace: true,
        canManageCustomers: true,
        canManageLeads: true,
        canViewTasks: true,
        canViewDocumentQueue: true,
        canViewPaymentQueue: true,
        canViewSupportTickets: true,
        canUseTaxCalculator: true,
        canOwnReferrals: true,
        canViewOwnCommissions: true,
        canApproveCommissions: true,
      );

      final groups = buildOmcMoreNavigation(
        capabilities: staff,
        features: disabledFeatures,
        isGuest: false,
      );
      final ids = groups
          .expand((group) => group.items)
          .map((item) => item.id)
          .toSet();

      expect(ids, contains(OmcNavigationActionId.documents));
      expect(ids, contains(OmcNavigationActionId.referrals));
      expect(ids, contains(OmcNavigationActionId.commissions));

      expect(ids, isNot(contains(OmcNavigationActionId.workspace)));
      expect(ids, isNot(contains(OmcNavigationActionId.customers)));
      expect(ids, isNot(contains(OmcNavigationActionId.tasks)));
      expect(ids, isNot(contains(OmcNavigationActionId.payments)));
      expect(ids, isNot(contains(OmcNavigationActionId.commissionOperations)));
      expect(ids, isNot(contains(OmcNavigationActionId.support)));
      expect(ids, isNot(contains(OmcNavigationActionId.leads)));
      expect(ids, isNot(contains(OmcNavigationActionId.tax)));
    },
  );

  test('internal Quick Actions suppress feature-disabled destinations', () {
    const staff = AuthCapabilities(
      accessState: AccountAccessState.internal,
      canAccessInternalWorkspace: true,
      canManageLeads: true,
      canCreateServiceForCustomer: true,
      canReviewPayments: true,
      canReviewDocuments: true,
      canApproveCommissions: true,
      canViewSupportTickets: true,
      canViewTasks: true,
    );

    final actions = buildOmcQuickActions(staff, features: disabledFeatures);
    final ids = actions.map((item) => item.id).toSet();

    expect(ids, contains(OmcNavigationActionId.startRequest));
    expect(ids, contains(OmcNavigationActionId.reviewDocuments));

    expect(ids, isNot(contains(OmcNavigationActionId.createLead)));
    expect(ids, isNot(contains(OmcNavigationActionId.reviewPayments)));
    expect(ids, isNot(contains(OmcNavigationActionId.commissionOperations)));
    expect(ids, isNot(contains(OmcNavigationActionId.supportQueue)));
    expect(ids, isNot(contains(OmcNavigationActionId.tasks)));
    expect(ids, isNot(contains(OmcNavigationActionId.workspace)));
  });

  test('guest Quick Actions expose no disabled public utility', () {
    final actions = buildOmcQuickActions(
      AuthCapabilities.guest,
      features: disabledFeatures,
    );

    expect(actions, hasLength(1));
    expect(actions.single.id, OmcNavigationActionId.profile);
  });
}
