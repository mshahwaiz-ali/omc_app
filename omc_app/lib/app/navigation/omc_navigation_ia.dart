import '../../features/auth/application/auth_state.dart';

enum OmcNavigationActionId {
  workspace,
  customers,
  referrals,
  commissions,
  commissionOperations,
  documents,
  payments,
  leads,
  tasks,
  support,
  alerts,
  tax,
  expense,
  budget,
  knowledge,
  profile,
  settings,
  login,
  logout,
  apply,
  createLead,
  startRequest,
  reviewPayments,
  reviewDocuments,
  supportQueue,
}

class OmcNavigationItem {
  const OmcNavigationItem(this.id, this.label);

  final OmcNavigationActionId id;
  final String label;
}

class OmcNavigationGroup {
  const OmcNavigationGroup(this.title, this.items);

  final String title;
  final List<OmcNavigationItem> items;
}

class OmcNavigationFeatureFlags {
  const OmcNavigationFeatureFlags({
    required this.paymentsEnabled,
    required this.expenseTrackerEnabled,
    required this.knowledgeEnabled,
    required this.supportEnabled,
  });

  final bool paymentsEnabled;
  final bool expenseTrackerEnabled;
  final bool knowledgeEnabled;
  final bool supportEnabled;
}

List<OmcNavigationGroup> buildOmcMoreNavigation({
  required AuthCapabilities capabilities,
  required OmcNavigationFeatureFlags features,
  required bool isGuest,
}) {
  if (capabilities.canAccessInternalWorkspace || capabilities.isInternal) {
    return _internalMoreNavigation(capabilities, features);
  }

  final groups = <OmcNavigationGroup>[];
  final omc = <OmcNavigationItem>[];
  final tools = <OmcNavigationItem>[];
  final account = <OmcNavigationItem>[];

  // Home, Services and Requests already live in the persistent bottom nav.
  // More only contains destinations that are not first-level tabs.
  if (!capabilities.isGuest) {
    if (capabilities.canViewDocuments || capabilities.canUploadDocuments) {
      omc.add(
        const OmcNavigationItem(OmcNavigationActionId.documents, 'Documents'),
      );
    }
    if (features.paymentsEnabled &&
        (capabilities.canViewPayments ||
            capabilities.canUploadPaymentReceipt ||
            capabilities.canUploadPaymentReceipts)) {
      omc.add(
        const OmcNavigationItem(OmcNavigationActionId.payments, 'Payments'),
      );
    }
    if (capabilities.canViewNotifications) {
      omc.add(const OmcNavigationItem(OmcNavigationActionId.alerts, 'Alerts'));
    }
  }

  if (capabilities.canUseTaxCalculator) {
    tools.add(const OmcNavigationItem(OmcNavigationActionId.tax, 'Tax'));
  }
  if (features.expenseTrackerEnabled) {
    tools.add(
      const OmcNavigationItem(OmcNavigationActionId.expense, 'Expense'),
    );
    if (capabilities.isApproved) {
      tools.add(
        const OmcNavigationItem(OmcNavigationActionId.budget, 'Budget'),
      );
    }
  }
  if (features.knowledgeEnabled) {
    tools.add(
      const OmcNavigationItem(OmcNavigationActionId.knowledge, 'Knowledge'),
    );
  }
  if (features.supportEnabled) {
    tools.add(
      const OmcNavigationItem(OmcNavigationActionId.support, 'Support'),
    );
  }

  if (!isGuest) {
    account.add(
      const OmcNavigationItem(OmcNavigationActionId.profile, 'Profile'),
    );
    account.add(
      const OmcNavigationItem(OmcNavigationActionId.settings, 'Settings'),
    );
  }
  account.add(
    OmcNavigationItem(
      isGuest ? OmcNavigationActionId.login : OmcNavigationActionId.logout,
      isGuest ? 'Login' : 'Logout',
    ),
  );

  if (omc.isNotEmpty) groups.add(OmcNavigationGroup('My OMC', omc));
  if (tools.isNotEmpty) groups.add(OmcNavigationGroup('Tools & help', tools));
  if (account.isNotEmpty) groups.add(OmcNavigationGroup('Account', account));
  return groups;
}

List<OmcNavigationGroup> _internalMoreNavigation(
  AuthCapabilities capabilities,
  OmcNavigationFeatureFlags features,
) {
  final work = <OmcNavigationItem>[
    const OmcNavigationItem(OmcNavigationActionId.workspace, 'Workspace'),
  ];
  final review = <OmcNavigationItem>[];
  final manage = <OmcNavigationItem>[];
  final tools = <OmcNavigationItem>[];
  final account = <OmcNavigationItem>[];

  if (capabilities.canManageCustomers ||
      capabilities.canViewAllCustomers ||
      capabilities.canViewRelevantCustomers) {
    work.add(
      const OmcNavigationItem(OmcNavigationActionId.customers, 'Customers'),
    );
  }
  if (capabilities.canOwnReferrals) {
    work.add(
      const OmcNavigationItem(OmcNavigationActionId.referrals, 'My Referrals'),
    );
  }
  if (capabilities.canViewOwnCommissions) {
    work.add(
      const OmcNavigationItem(
        OmcNavigationActionId.commissions,
        'My Commissions',
      ),
    );
  }
  if (capabilities.canViewTasks) {
    work.add(const OmcNavigationItem(OmcNavigationActionId.tasks, 'Tasks'));
  }

  if (capabilities.canViewAnyDocument) {
    review.add(
      const OmcNavigationItem(OmcNavigationActionId.documents, 'Documents'),
    );
  }
  if (capabilities.canViewAnyPayment) {
    review.add(
      const OmcNavigationItem(OmcNavigationActionId.payments, 'Payments'),
    );
  }
  if (capabilities.canApproveCommissions ||
      capabilities.canMarkCommissionsPaid) {
    review.add(
      const OmcNavigationItem(
        OmcNavigationActionId.commissionOperations,
        'Commission Operations',
      ),
    );
  }
  if (capabilities.canUseSupportWorkspace) {
    review.add(
      const OmcNavigationItem(OmcNavigationActionId.support, 'Support'),
    );
  }
  if (capabilities.canViewNotifications) {
    review.add(const OmcNavigationItem(OmcNavigationActionId.alerts, 'Alerts'));
  }

  if (capabilities.canManageLeads) {
    manage.add(const OmcNavigationItem(OmcNavigationActionId.leads, 'Leads'));
  }
  if (capabilities.canUseTaxCalculator) {
    tools.add(const OmcNavigationItem(OmcNavigationActionId.tax, 'Tax'));
  }
  if (features.expenseTrackerEnabled) {
    tools.add(
      const OmcNavigationItem(OmcNavigationActionId.expense, 'Expense'),
    );
    tools.add(const OmcNavigationItem(OmcNavigationActionId.budget, 'Budget'));
  }
  if (features.knowledgeEnabled) {
    tools.add(
      const OmcNavigationItem(OmcNavigationActionId.knowledge, 'Knowledge'),
    );
  }

  account.add(
    const OmcNavigationItem(OmcNavigationActionId.settings, 'Settings'),
  );
  account.add(const OmcNavigationItem(OmcNavigationActionId.logout, 'Logout'));

  return [
    OmcNavigationGroup('Work', work),
    if (review.isNotEmpty) OmcNavigationGroup('Review & support', review),
    if (manage.isNotEmpty) OmcNavigationGroup('Manage', manage),
    if (tools.isNotEmpty) OmcNavigationGroup('Tools', tools),
    OmcNavigationGroup('Account', account),
  ];
}

List<OmcNavigationItem> buildOmcQuickActions(AuthCapabilities capabilities) {
  if (capabilities.canAccessInternalWorkspace || capabilities.isInternal) {
    final items = <OmcNavigationItem>[];
    if (capabilities.canManageLeads) {
      items.add(
        const OmcNavigationItem(OmcNavigationActionId.createLead, 'New Lead'),
      );
    }
    if (capabilities.canCreateServiceForCustomer) {
      items.add(
        const OmcNavigationItem(
          OmcNavigationActionId.startRequest,
          'Start Request',
        ),
      );
    }
    if (capabilities.canReviewPayments) {
      items.add(
        const OmcNavigationItem(
          OmcNavigationActionId.reviewPayments,
          'Review Payments',
        ),
      );
    }
    if (capabilities.canReviewDocuments) {
      items.add(
        const OmcNavigationItem(
          OmcNavigationActionId.reviewDocuments,
          'Review Documents',
        ),
      );
    }
    if (capabilities.canApproveCommissions ||
        capabilities.canMarkCommissionsPaid) {
      items.add(
        const OmcNavigationItem(
          OmcNavigationActionId.commissionOperations,
          'Commissions',
        ),
      );
    }
    if (capabilities.canUseSupportWorkspace) {
      items.add(
        const OmcNavigationItem(
          OmcNavigationActionId.supportQueue,
          'Support Queue',
        ),
      );
    }
    if (capabilities.canViewTasks) {
      items.add(const OmcNavigationItem(OmcNavigationActionId.tasks, 'Tasks'));
    }

    if (items.isEmpty) {
      items.add(
        const OmcNavigationItem(OmcNavigationActionId.workspace, 'Workspace'),
      );
    }
    return items;
  }

  if (capabilities.isApproved) {
    final items = <OmcNavigationItem>[];
    if (capabilities.canCreateServiceRequest) {
      items.add(const OmcNavigationItem(OmcNavigationActionId.apply, 'Apply'));
    }
    if (capabilities.canUploadDocuments || capabilities.canViewDocuments) {
      items.add(
        const OmcNavigationItem(OmcNavigationActionId.documents, 'Documents'),
      );
    }
    if (capabilities.canViewPayments ||
        capabilities.canUploadPaymentReceipt ||
        capabilities.canUploadPaymentReceipts) {
      items.add(
        const OmcNavigationItem(OmcNavigationActionId.payments, 'Payments'),
      );
    }
    if (capabilities.canCreateSupportTicket) {
      items.add(
        const OmcNavigationItem(OmcNavigationActionId.support, 'Support'),
      );
    }
    if (capabilities.canUseTaxCalculator) {
      items.add(const OmcNavigationItem(OmcNavigationActionId.tax, 'Tax Calc'));
    }
    return items;
  }

  if (capabilities.isPending) {
    return const [
      OmcNavigationItem(OmcNavigationActionId.tax, 'Tax'),
      OmcNavigationItem(OmcNavigationActionId.knowledge, 'Knowledge'),
      OmcNavigationItem(OmcNavigationActionId.support, 'Support'),
      OmcNavigationItem(OmcNavigationActionId.profile, 'Status'),
    ];
  }

  return const [
    OmcNavigationItem(OmcNavigationActionId.tax, 'Tax'),
    OmcNavigationItem(OmcNavigationActionId.knowledge, 'Knowledge'),
    OmcNavigationItem(OmcNavigationActionId.support, 'Support'),
    OmcNavigationItem(OmcNavigationActionId.profile, 'Sign Up'),
  ];
}
