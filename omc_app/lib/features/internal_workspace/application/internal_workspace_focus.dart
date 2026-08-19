import '../../auth/application/auth_state.dart';

enum InternalWorkspaceFocusKind {
  leadership,
  finance,
  documentReview,
  support,
  clientWork,
  operations,
}

class InternalWorkspaceFocus {
  const InternalWorkspaceFocus({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.overviewTitle,
    required this.priorityTitle,
    required this.canShowServiceCases,
    required this.canShowDocuments,
    required this.canShowPayments,
    required this.canShowCustomers,
    required this.canShowLeads,
    required this.canShowTasks,
    required this.canCreateServiceForCustomer,
    required this.canShowSettlementExceptions,
    required this.canShowAdminControls,
    required this.canShowOperationalControls,
    required this.showServicePerformance,
  });

  final InternalWorkspaceFocusKind kind;
  final String title;
  final String subtitle;
  final String overviewTitle;
  final String priorityTitle;

  // Presentation visibility only. Backend capability enforcement remains the
  // source of authority for every route and mutation.
  final bool canShowServiceCases;
  final bool canShowDocuments;
  final bool canShowPayments;
  final bool canShowCustomers;
  final bool canShowLeads;
  final bool canShowTasks;
  final bool canCreateServiceForCustomer;
  final bool canShowSettlementExceptions;
  final bool canShowAdminControls;
  final bool canShowOperationalControls;
  final bool showServicePerformance;

  factory InternalWorkspaceFocus.fromCapabilities(AuthCapabilities capabilities) {
    final kind = _focusKind(capabilities);
    final labels = _labels(kind);

    return InternalWorkspaceFocus(
      kind: kind,
      title: labels.title,
      subtitle: labels.subtitle,
      overviewTitle: labels.overviewTitle,
      priorityTitle: labels.priorityTitle,
      canShowServiceCases: capabilities.canViewAnyServiceCase,
      canShowDocuments: capabilities.canViewAnyDocument,
      canShowPayments: capabilities.canViewAnyPayment,
      canShowCustomers:
          capabilities.canManageCustomers ||
          capabilities.canViewAllCustomers ||
          capabilities.canViewRelevantCustomers,
      canShowLeads: capabilities.canManageLeads,
      canShowTasks:
          capabilities.canManageTasks || capabilities.canManageAssignedTasks,
      canCreateServiceForCustomer: capabilities.canCreateServiceForCustomer,
      canShowSettlementExceptions: capabilities.canReconcileSettlement,
      canShowAdminControls:
          capabilities.canManageStaff ||
          capabilities.canReviewRegistrations ||
          capabilities.canManageBusinessSettings,
      canShowOperationalControls:
          capabilities.canReassignServiceCases ||
          capabilities.canRetrySync ||
          capabilities.canManageBusinessSettings,
      showServicePerformance:
          kind == InternalWorkspaceFocusKind.clientWork &&
          (capabilities.canViewAssignedServiceCases ||
              capabilities.canUpdateAssignedServiceStatus),
    );
  }
}

InternalWorkspaceFocusKind _focusKind(AuthCapabilities capabilities) {
  // Broad/global authority wins over specialist capabilities so Manager/Admin
  // users receive an operations-wide home rather than a specialist home.
  if (capabilities.canViewAllServiceCases ||
      capabilities.canViewAllCustomers ||
      capabilities.canManageStaff ||
      capabilities.canManageBusinessSettings ||
      capabilities.canManageSettings) {
    return InternalWorkspaceFocusKind.leadership;
  }

  if (capabilities.canReconcileSettlement ||
      capabilities.canReviewPayments ||
      capabilities.canApprovePostPaid ||
      capabilities.canApproveCommissions ||
      capabilities.canMarkCommissionsPaid) {
    return InternalWorkspaceFocusKind.finance;
  }

  if (capabilities.canReviewDocuments || capabilities.canViewDocumentQueue) {
    return InternalWorkspaceFocusKind.documentReview;
  }

  if (capabilities.canViewSupportTickets ||
      capabilities.canReplySupportTickets ||
      capabilities.canUpdateSupportTicketStatus ||
      capabilities.canAssignSupportTickets) {
    return InternalWorkspaceFocusKind.support;
  }

  if (capabilities.canViewAssignedServiceCases ||
      capabilities.canCreateServiceForCustomer ||
      capabilities.canManageAssignedTasks ||
      capabilities.canViewReferralCommissions) {
    return InternalWorkspaceFocusKind.clientWork;
  }

  return InternalWorkspaceFocusKind.operations;
}

({
  String title,
  String subtitle,
  String overviewTitle,
  String priorityTitle,
}) _labels(InternalWorkspaceFocusKind kind) {
  return switch (kind) {
    InternalWorkspaceFocusKind.leadership => (
      title: 'Operations Command',
      subtitle: 'Business-wide queues, customers and team execution',
      overviewTitle: 'Business pulse',
      priorityTitle: 'Priority across operations',
    ),
    InternalWorkspaceFocusKind.finance => (
      title: 'Finance Workspace',
      subtitle: 'Payments, settlement exceptions and finance review',
      overviewTitle: 'Finance review',
      priorityTitle: 'Cases needing financial attention',
    ),
    InternalWorkspaceFocusKind.documentReview => (
      title: 'Document Review',
      subtitle: 'Document exceptions, uploads and customer evidence',
      overviewTitle: 'Document review',
      priorityTitle: 'Documents needing attention',
    ),
    InternalWorkspaceFocusKind.support => (
      title: 'Support Workspace',
      subtitle: 'Customer issues, relevant cases and follow-up work',
      overviewTitle: 'Support workload',
      priorityTitle: 'Customer cases needing attention',
    ),
    InternalWorkspaceFocusKind.clientWork => (
      title: 'My Client Work',
      subtitle: 'Assigned services, customers, referrals and tasks',
      overviewTitle: 'My workload',
      priorityTitle: 'My priority cases',
    ),
    InternalWorkspaceFocusKind.operations => (
      title: 'Workspace',
      subtitle: 'Your authorized OMC operations and daily work',
      overviewTitle: 'Operations today',
      priorityTitle: 'Priority queue',
    ),
  };
}
