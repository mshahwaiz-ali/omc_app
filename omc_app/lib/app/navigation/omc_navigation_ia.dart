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
    required this.taxCalculatorEnabled,
    required this.internalWorkspaceEnabled,
  });

  final bool paymentsEnabled;
  final bool expenseTrackerEnabled;
  final bool knowledgeEnabled;
  final bool supportEnabled;
  final bool taxCalculatorEnabled;
  final bool internalWorkspaceEnabled;
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
  final taxKnowledge = <OmcNavigationItem>[];
  final toolsHelp = <OmcNavigationItem>[];
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

  // Tax and knowledge are high-value destinations when available, so they
  // remain a first-level group rather than being buried among optional tools.
  if (features.taxCalculatorEnabled && capabilities.canUseTaxCalculator) {
    taxKnowledge.add(
      const OmcNavigationItem(OmcNavigationActionId.tax, 'Tax calculator'),
    );
  }
  if (features.knowledgeEnabled) {
    taxKnowledge.add(
      const OmcNavigationItem(
        OmcNavigationActionId.knowledge,
        'Knowledge & news',
      ),
    );
  }

  if (features.expenseTrackerEnabled) {
    toolsHelp.add(
      const OmcNavigationItem(OmcNavigationActionId.expense, 'Expense'),
    );
    if (capabilities.isApproved) {
      toolsHelp.add(
        const OmcNavigationItem(OmcNavigationActionId.budget, 'Budget'),
      );
    }
  }
  if (features.supportEnabled) {
    toolsHelp.add(
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
  if (taxKnowledge.isNotEmpty) {
    groups.add(OmcNavigationGroup('Tax & knowledge', taxKnowledge));
  }
  if (toolsHelp.isNotEmpty) {
    groups.add(OmcNavigationGroup('Tools & help', toolsHelp));
  }
  if (account.isNotEmpty) groups.add(OmcNavigationGroup('Account', account));
  return groups;
}

List<OmcNavigationGroup> _internalMoreNavigation(
  AuthCapabilities capabilities,
  OmcNavigationFeatureFlags features,
) {
  final work = <OmcNavigationItem>[];
  final review = <OmcNavigationItem>[];
  final manage = <OmcNavigationItem>[];
  final tools = <OmcNavigationItem>[];
  final account = <OmcNavigationItem>[];

  if (features.internalWorkspaceEnabled) {
    work.add(
      const OmcNavigationItem(OmcNavigationActionId.workspace, 'Workspace'),
    );

    if (capabilities.canManageCustomers ||
        capabilities.canViewAllCustomers ||
        capabilities.canViewRelevantCustomers) {
      work.add(
        const OmcNavigationItem(OmcNavigationActionId.customers, 'Customers'),
      );
    }
  }

  // These routes are capability-authorized and are not feature-gated by the
  // mobile route policy.
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

  if (features.internalWorkspaceEnabled && capabilities.canViewTasks) {
    work.add(const OmcNavigationItem(OmcNavigationActionId.tasks, 'Tasks'));
  }

  // /documents is intentionally not controlled by internal_workspace_enabled.
  if (capabilities.canViewAnyDocument) {
    review.add(
      const OmcNavigationItem(OmcNavigationActionId.documents, 'Documents'),
    );
  }
  if (features.paymentsEnabled && capabilities.canViewAnyPayment) {
    review.add(
      const OmcNavigationItem(OmcNavigationActionId.payments, 'Payments'),
    );
  }
  if (features.internalWorkspaceEnabled &&
      (capabilities.canApproveCommissions ||
          capabilities.canMarkCommissionsPaid)) {
    review.add(
      const OmcNavigationItem(
        OmcNavigationActionId.commissionOperations,
        'Commission Operations',
      ),
    );
  }
  if (features.supportEnabled && capabilities.canUseSupportWorkspace) {
    review.add(
      const OmcNavigationItem(OmcNavigationActionId.support, 'Support'),
    );
  }
  if (capabilities.canViewNotifications) {
    review.add(const OmcNavigationItem(OmcNavigationActionId.alerts, 'Alerts'));
  }

  if (features.internalWorkspaceEnabled && capabilities.canManageLeads) {
    manage.add(const OmcNavigationItem(OmcNavigationActionId.leads, 'Leads'));
  }
  if (features.taxCalculatorEnabled && capabilities.canUseTaxCalculator) {
    tools.add(
      const OmcNavigationItem(OmcNavigationActionId.tax, 'Tax calculator'),
    );
  }
  if (features.expenseTrackerEnabled) {
    tools.add(
      const OmcNavigationItem(OmcNavigationActionId.expense, 'Expense'),
    );
    tools.add(const OmcNavigationItem(OmcNavigationActionId.budget, 'Budget'));
  }
  if (features.knowledgeEnabled) {
    tools.add(
      const OmcNavigationItem(
        OmcNavigationActionId.knowledge,
        'Knowledge & news',
      ),
    );
  }

  account.add(
    const OmcNavigationItem(OmcNavigationActionId.settings, 'Settings'),
  );
  account.add(const OmcNavigationItem(OmcNavigationActionId.logout, 'Logout'));

  return [
    if (work.isNotEmpty) OmcNavigationGroup('Work', work),
    if (review.isNotEmpty) OmcNavigationGroup('Review & support', review),
    if (manage.isNotEmpty) OmcNavigationGroup('Manage', manage),
    if (tools.isNotEmpty) OmcNavigationGroup('Tools', tools),
    OmcNavigationGroup('Account', account),
  ];
}

List<OmcNavigationItem> buildOmcQuickActions(
  AuthCapabilities capabilities, {
  required OmcNavigationFeatureFlags features,
}) {
  if (capabilities.canAccessInternalWorkspace || capabilities.isInternal) {
    final items = <OmcNavigationItem>[];

    if (features.internalWorkspaceEnabled && capabilities.canManageLeads) {
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
    if (features.paymentsEnabled && capabilities.canReviewPayments) {
      items.add(
        const OmcNavigationItem(
          OmcNavigationActionId.reviewPayments,
          'Review Payments',
        ),
      );
    }

    // This opens /documents, which is capability-gated but intentionally not
    // controlled by internal_workspace_enabled.
    if (capabilities.canReviewDocuments) {
      items.add(
        const OmcNavigationItem(
          OmcNavigationActionId.reviewDocuments,
          'Review Documents',
        ),
      );
    }

    if (features.internalWorkspaceEnabled &&
        (capabilities.canApproveCommissions ||
            capabilities.canMarkCommissionsPaid)) {
      items.add(
        const OmcNavigationItem(
          OmcNavigationActionId.commissionOperations,
          'Commissions',
        ),
      );
    }
    if (features.supportEnabled && capabilities.canUseSupportWorkspace) {
      items.add(
        const OmcNavigationItem(
          OmcNavigationActionId.supportQueue,
          'Support Queue',
        ),
      );
    }
    if (features.internalWorkspaceEnabled && capabilities.canViewTasks) {
      items.add(const OmcNavigationItem(OmcNavigationActionId.tasks, 'Tasks'));
    }

    if (items.isEmpty && features.internalWorkspaceEnabled) {
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
    if (features.paymentsEnabled &&
        (capabilities.canViewPayments ||
            capabilities.canUploadPaymentReceipt ||
            capabilities.canUploadPaymentReceipts)) {
      items.add(
        const OmcNavigationItem(OmcNavigationActionId.payments, 'Payments'),
      );
    }
    if (features.supportEnabled && capabilities.canCreateSupportTicket) {
      items.add(
        const OmcNavigationItem(OmcNavigationActionId.support, 'Support'),
      );
    }
    if (features.taxCalculatorEnabled && capabilities.canUseTaxCalculator) {
      items.add(const OmcNavigationItem(OmcNavigationActionId.tax, 'Tax Calc'));
    }
    return items;
  }

  if (capabilities.isPending) {
    final items = <OmcNavigationItem>[];
    if (features.taxCalculatorEnabled) {
      items.add(const OmcNavigationItem(OmcNavigationActionId.tax, 'Tax'));
    }
    if (features.knowledgeEnabled) {
      items.add(
        const OmcNavigationItem(OmcNavigationActionId.knowledge, 'Knowledge'),
      );
    }
    if (features.supportEnabled) {
      items.add(
        const OmcNavigationItem(OmcNavigationActionId.support, 'Support'),
      );
    }
    items.add(const OmcNavigationItem(OmcNavigationActionId.profile, 'Status'));
    return items;
  }

  final items = <OmcNavigationItem>[];
  if (features.taxCalculatorEnabled) {
    items.add(const OmcNavigationItem(OmcNavigationActionId.tax, 'Tax'));
  }
  if (features.knowledgeEnabled) {
    items.add(
      const OmcNavigationItem(OmcNavigationActionId.knowledge, 'Knowledge'),
    );
  }
  if (features.supportEnabled) {
    items.add(
      const OmcNavigationItem(OmcNavigationActionId.support, 'Support'),
    );
  }
  items.add(const OmcNavigationItem(OmcNavigationActionId.profile, 'Sign Up'));
  return items;
}
