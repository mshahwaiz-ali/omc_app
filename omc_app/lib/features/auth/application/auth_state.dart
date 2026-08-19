enum AuthStatus {
  checking,
  authenticating,
  authenticated,
  guest,
  unauthenticated,
}

enum AccountAccessState { guest, pending, approved, internal, rejected }

class AuthCapabilities {
  const AuthCapabilities({
    required this.accessState,
    this.canViewPublicCatalogue = true,
    this.canViewPublicContent = true,
    this.canUseTaxCalculator = true,
    this.canCreateServiceRequest = false,
    this.canUploadDocuments = false,
    this.canTrackRequests = false,
    this.canViewDocuments = false,
    this.canViewPayments = false,
    this.canUploadPaymentReceipt = false,
    this.canUploadPaymentReceipts = false,
    this.canCreateSupportTicket = false,
    this.canViewCustomerDashboard = false,
    this.canAccessCustomerDashboard = false,
    this.canViewCustomerNotifications = false,
    this.canAccessInternalWorkspace = false,
    this.canManageCustomers = false,
    this.canViewAllCustomers = false,
    this.canViewRelevantCustomers = false,
    this.canManageLeads = false,
    this.canManageTasks = false,
    this.canManageAssignedTasks = false,
    this.canViewAllServiceCases = false,
    this.canViewRelevantServiceCases = false,
    this.canViewAssignedServiceCases = false,
    this.canCreateServiceForCustomer = false,
    this.canUpdateServiceStatus = false,
    this.canUpdateAssignedServiceStatus = false,
    this.canViewDocumentQueue = false,
    this.canViewDocumentSummaries = false,
    this.canViewDocumentAttachments = false,
    this.canReviewDocuments = false,
    this.canViewPaymentQueue = false,
    this.canViewPaymentSummaries = false,
    this.canViewPaymentReceipts = false,
    this.canReviewPayments = false,
    this.canReconcileSettlement = false,
    this.canApprovePostPaid = false,
    this.canViewSupportTickets = false,
    this.canReplySupportTickets = false,
    this.canUpdateSupportTicketStatus = false,
    this.canAssignSupportTickets = false,
    this.canViewInternalNotes = false,
    this.canManageSettings = false,
    this.canManageStaff = false,
    this.canReviewRegistrations = false,
    this.canManageBusinessSettings = false,
    this.canReassignServiceCases = false,
    this.canRetrySync = false,
    this.canViewReferralCommissions = false,
    this.canApproveCommissions = false,
    this.canMarkCommissionsPaid = false,
    @Deprecated('Derived from canonical service-case capabilities.')
    bool canManageCustomerServiceFlow = false,
    @Deprecated('Derived from canonical document capabilities.')
    bool canUploadCustomerDocuments = false,
    @Deprecated('Derived from canonical document capabilities.')
    bool canViewCustomerDocuments = false,
    @Deprecated('Derived from canonical payment capabilities.')
    bool canViewCustomerPayments = false,
    @Deprecated('Derived from canonical payment capabilities.')
    bool canUploadCustomerPaymentReceipt = false,
    @Deprecated('Use canApproveCommissions/canMarkCommissionsPaid.')
    bool canManageReferralCommissions = false,
  });

  final AccountAccessState accessState;

  // Public/customer capability contract.
  final bool canViewPublicCatalogue;
  final bool canViewPublicContent;
  final bool canUseTaxCalculator;
  final bool canCreateServiceRequest;
  final bool canUploadDocuments;
  final bool canTrackRequests;
  final bool canViewDocuments;
  final bool canViewPayments;
  final bool canUploadPaymentReceipt;
  final bool canUploadPaymentReceipts;
  final bool canCreateSupportTicket;
  final bool canViewCustomerDashboard;
  final bool canAccessCustomerDashboard;
  final bool canViewCustomerNotifications;

  // Internal capability contract. Keep these names in direct 1:1 sync with
  // omc_app.api.capabilities.INTERNAL_CAPABILITY_KEYS.
  final bool canAccessInternalWorkspace;
  final bool canManageCustomers;
  final bool canViewAllCustomers;
  final bool canViewRelevantCustomers;
  final bool canManageLeads;
  final bool canManageTasks;
  final bool canManageAssignedTasks;
  final bool canViewAllServiceCases;
  final bool canViewRelevantServiceCases;
  final bool canViewAssignedServiceCases;
  final bool canCreateServiceForCustomer;
  final bool canUpdateServiceStatus;
  final bool canUpdateAssignedServiceStatus;
  final bool canViewDocumentQueue;
  final bool canViewDocumentSummaries;
  final bool canViewDocumentAttachments;
  final bool canReviewDocuments;
  final bool canViewPaymentQueue;
  final bool canViewPaymentSummaries;
  final bool canViewPaymentReceipts;
  final bool canReviewPayments;
  final bool canReconcileSettlement;
  final bool canApprovePostPaid;
  final bool canViewSupportTickets;
  final bool canReplySupportTickets;
  final bool canUpdateSupportTicketStatus;
  final bool canAssignSupportTickets;
  final bool canViewInternalNotes;
  final bool canManageSettings;
  final bool canManageStaff;
  final bool canReviewRegistrations;
  final bool canManageBusinessSettings;
  final bool canReassignServiceCases;
  final bool canRetrySync;
  final bool canViewReferralCommissions;
  final bool canApproveCommissions;
  final bool canMarkCommissionsPaid;

  static const guest = AuthCapabilities(accessState: AccountAccessState.guest);

  bool get isGuest => accessState == AccountAccessState.guest;
  bool get isPending => accessState == AccountAccessState.pending;
  bool get isApproved => accessState == AccountAccessState.approved;
  bool get isInternal => accessState == AccountAccessState.internal;
  bool get isRejected => accessState == AccountAccessState.rejected;

  bool get canViewAnyServiceCase =>
      canViewAllServiceCases ||
      canViewRelevantServiceCases ||
      canViewAssignedServiceCases;

  bool get canViewAnyDocument =>
      canViewDocumentQueue ||
      canViewDocumentSummaries ||
      canViewDocumentAttachments ||
      canReviewDocuments;

  bool get canViewAnyPayment =>
      canViewPaymentQueue ||
      canViewPaymentSummaries ||
      canViewPaymentReceipts ||
      canReviewPayments;

  bool get canUseSupportWorkspace =>
      canViewSupportTickets ||
      canReplySupportTickets ||
      canUpdateSupportTicketStatus ||
      canAssignSupportTickets;

  // Compatibility getters for older UI code. These derive from canonical
  // backend capabilities and never parse or create independent authority.
  @Deprecated('Use canViewAnyServiceCase/canonical service-case capabilities.')
  bool get canManageCustomerServiceFlow =>
      canViewAnyServiceCase ||
      canUpdateServiceStatus ||
      canUpdateAssignedServiceStatus;

  @Deprecated('Use canonical document capabilities.')
  bool get canUploadCustomerDocuments =>
      canCreateServiceForCustomer &&
      (canViewDocumentAttachments || canReviewDocuments);

  @Deprecated('Use canViewAnyDocument.')
  bool get canViewCustomerDocuments => canViewAnyDocument;

  @Deprecated('Use canViewAnyPayment.')
  bool get canViewCustomerPayments => canViewAnyPayment;

  @Deprecated('Use canonical customer/payment capabilities.')
  bool get canUploadCustomerPaymentReceipt =>
      canCreateServiceForCustomer && canViewPaymentReceipts;

  @Deprecated('Use canApproveCommissions/canMarkCommissionsPaid.')
  bool get canManageReferralCommissions =>
      canApproveCommissions || canMarkCommissionsPaid;

  List<Object> get _equalityValues => [
    accessState,
    canViewPublicCatalogue,
    canViewPublicContent,
    canUseTaxCalculator,
    canCreateServiceRequest,
    canUploadDocuments,
    canTrackRequests,
    canViewDocuments,
    canViewPayments,
    canUploadPaymentReceipt,
    canUploadPaymentReceipts,
    canCreateSupportTicket,
    canViewCustomerDashboard,
    canAccessCustomerDashboard,
    canViewCustomerNotifications,
    canAccessInternalWorkspace,
    canManageCustomers,
    canViewAllCustomers,
    canViewRelevantCustomers,
    canManageLeads,
    canManageTasks,
    canManageAssignedTasks,
    canViewAllServiceCases,
    canViewRelevantServiceCases,
    canViewAssignedServiceCases,
    canCreateServiceForCustomer,
    canUpdateServiceStatus,
    canUpdateAssignedServiceStatus,
    canViewDocumentQueue,
    canViewDocumentSummaries,
    canViewDocumentAttachments,
    canReviewDocuments,
    canViewPaymentQueue,
    canViewPaymentSummaries,
    canViewPaymentReceipts,
    canReviewPayments,
    canReconcileSettlement,
    canApprovePostPaid,
    canViewSupportTickets,
    canReplySupportTickets,
    canUpdateSupportTicketStatus,
    canAssignSupportTickets,
    canViewInternalNotes,
    canManageSettings,
    canManageStaff,
    canReviewRegistrations,
    canManageBusinessSettings,
    canReassignServiceCases,
    canRetrySync,
    canViewReferralCommissions,
    canApproveCommissions,
    canMarkCommissionsPaid,
  ];

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! AuthCapabilities) return false;

    final left = _equalityValues;
    final right = other._equalityValues;
    if (left.length != right.length) return false;
    for (var index = 0; index < left.length; index += 1) {
      if (left[index] != right[index]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_equalityValues);

  factory AuthCapabilities.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return guest;

    final accessState = _accessStateFromJson(json);

    return AuthCapabilities(
      accessState: accessState,
      canViewPublicCatalogue: _boolValue(
        json['can_view_public_catalogue'],
        true,
      ),
      canViewPublicContent: _boolValue(json['can_view_public_content'], true),
      canUseTaxCalculator: _boolValue(json['can_use_tax_calculator'], true),
      canCreateServiceRequest: _boolValue(json['can_create_service_request']),
      canUploadDocuments: _boolValue(json['can_upload_documents']),
      canTrackRequests: _boolValue(json['can_track_requests']),
      canViewDocuments: _boolValue(json['can_view_documents']),
      canViewPayments: _boolValue(json['can_view_payments']),
      canUploadPaymentReceipt: _boolValue(
        json['can_upload_payment_receipt'],
      ),
      canUploadPaymentReceipts: _boolValue(
        json['can_upload_payment_receipts'],
      ),
      canCreateSupportTicket: _boolValue(json['can_create_support_ticket']),
      canViewCustomerDashboard: _boolValue(
        json['can_view_customer_dashboard'],
      ),
      canAccessCustomerDashboard: _boolValue(
        json['can_access_customer_dashboard'],
      ),
      canViewCustomerNotifications: _boolValue(
        json['can_view_customer_notifications'],
      ),
      canAccessInternalWorkspace: _boolValue(
        json['can_access_internal_workspace'],
      ),
      canManageCustomers: _boolValue(json['can_manage_customers']),
      canViewAllCustomers: _boolValue(json['can_view_all_customers']),
      canViewRelevantCustomers: _boolValue(json['can_view_relevant_customers']),
      canManageLeads: _boolValue(json['can_manage_leads']),
      canManageTasks: _boolValue(json['can_manage_tasks']),
      canManageAssignedTasks: _boolValue(json['can_manage_assigned_tasks']),
      canViewAllServiceCases: _boolValue(json['can_view_all_service_cases']),
      canViewRelevantServiceCases: _boolValue(
        json['can_view_relevant_service_cases'],
      ),
      canViewAssignedServiceCases: _boolValue(
        json['can_view_assigned_service_cases'],
      ),
      canCreateServiceForCustomer: _boolValue(
        json['can_create_service_for_customer'],
      ),
      canUpdateServiceStatus: _boolValue(json['can_update_service_status']),
      canUpdateAssignedServiceStatus: _boolValue(
        json['can_update_assigned_service_status'],
      ),
      canViewDocumentQueue: _boolValue(json['can_view_document_queue']),
      canViewDocumentSummaries: _boolValue(json['can_view_document_summaries']),
      canViewDocumentAttachments: _boolValue(
        json['can_view_document_attachments'],
      ),
      canReviewDocuments: _boolValue(json['can_review_documents']),
      canViewPaymentQueue: _boolValue(json['can_view_payment_queue']),
      canViewPaymentSummaries: _boolValue(json['can_view_payment_summaries']),
      canViewPaymentReceipts: _boolValue(json['can_view_payment_receipts']),
      canReviewPayments: _boolValue(json['can_review_payments']),
      canReconcileSettlement: _boolValue(json['can_reconcile_settlement']),
      canApprovePostPaid: _boolValue(json['can_approve_post_paid']),
      canViewSupportTickets: _boolValue(json['can_view_support_tickets']),
      canReplySupportTickets: _boolValue(json['can_reply_support_tickets']),
      canUpdateSupportTicketStatus: _boolValue(
        json['can_update_support_ticket_status'],
      ),
      canAssignSupportTickets: _boolValue(json['can_assign_support_tickets']),
      canViewInternalNotes: _boolValue(json['can_view_internal_notes']),
      canManageSettings: _boolValue(json['can_manage_settings']),
      canManageStaff: _boolValue(json['can_manage_staff']),
      canReviewRegistrations: _boolValue(json['can_review_registrations']),
      canManageBusinessSettings: _boolValue(
        json['can_manage_business_settings'],
      ),
      canReassignServiceCases: _boolValue(json['can_reassign_service_cases']),
      canRetrySync: _boolValue(json['can_retry_sync']),
      canViewReferralCommissions: _boolValue(
        json['can_view_referral_commissions'],
      ),
      canApproveCommissions: _boolValue(json['can_approve_commissions']),
      canMarkCommissionsPaid: _boolValue(
        json['can_mark_commissions_paid'],
      ),
    );
  }

  static AccountAccessState _accessStateFromJson(Map<String, dynamic> json) {
    if (_boolValue(
      json['can_access_internal_workspace'] ??
          json['canAccessInternalWorkspace'] ??
          json['is_internal'],
    )) {
      return AccountAccessState.internal;
    }

    final directState = _accessStateFromValue(
      json['access_state'] ?? json['account_access_state'],
    );
    if (directState != AccountAccessState.guest) return directState;

    if (_boolValue(json['is_approved_customer'] ?? json['is_approved'])) {
      return AccountAccessState.approved;
    }

    final customerStatus = _textValue(
      json['customer_status'] ?? json['status'],
    );
    final approvalStatus = _textValue(json['approval_status']);

    if (customerStatus == 'rejected' || approvalStatus == 'rejected') {
      return AccountAccessState.rejected;
    }

    if ((customerStatus == 'active' || customerStatus == 'approved') &&
        (approvalStatus.isEmpty || approvalStatus == 'approved')) {
      return AccountAccessState.approved;
    }

    if (approvalStatus == 'approved' && customerStatus.isEmpty) {
      return AccountAccessState.approved;
    }

    const pendingValues = {
      'pending',
      'pending_review',
      'pending review',
      'under review',
    };
    if (pendingValues.contains(customerStatus) ||
        pendingValues.contains(approvalStatus)) {
      return AccountAccessState.pending;
    }

    return AccountAccessState.guest;
  }

  static AccountAccessState _accessStateFromValue(dynamic value) {
    final text = _textValue(value);
    if (text == 'internal') return AccountAccessState.internal;
    if (text == 'approved' || text == 'active') {
      return AccountAccessState.approved;
    }
    if (text == 'rejected' || text == 'blocked') {
      return AccountAccessState.rejected;
    }
    if (text == 'pending' || text == 'pending_review') {
      return AccountAccessState.pending;
    }
    return AccountAccessState.guest;
  }

  static bool _boolValue(dynamic value, [bool fallback = false]) {
    if (value is bool) return value;
    if (value is num) return value != 0;

    final text = value?.toString().trim().toLowerCase();
    if (text == null || text.isEmpty) return fallback;

    if (text == 'true' || text == '1' || text == 'yes' || text == 'on') {
      return true;
    }
    if (text == 'false' || text == '0' || text == 'no' || text == 'off') {
      return false;
    }

    return fallback;
  }

  static String _textValue(dynamic value) {
    return value?.toString().trim().toLowerCase() ?? '';
  }
}

class AuthState {
  const AuthState({
    required this.status,
    this.userId,
    this.message,
    this.canAccessInternalWorkspace = false,
    this.displayName,
    this.phone,
    this.companyName,
    this.customerStatus,
    this.approvalStatus,
    this.avatarUrl,
    this.capabilities = AuthCapabilities.guest,
  });

  final AuthStatus status;
  final String? userId;
  final String? message;
  final bool canAccessInternalWorkspace;
  final String? displayName;
  final String? phone;
  final String? companyName;
  final String? customerStatus;
  final String? approvalStatus;
  final String? avatarUrl;
  final AuthCapabilities capabilities;

  const AuthState.checking()
    : status = AuthStatus.checking,
      userId = null,
      message = null,
      canAccessInternalWorkspace = false,
      displayName = null,
      phone = null,
      companyName = null,
      customerStatus = null,
      approvalStatus = null,
      avatarUrl = null,
      capabilities = AuthCapabilities.guest;

  const AuthState.authenticating()
    : status = AuthStatus.authenticating,
      userId = null,
      message = null,
      canAccessInternalWorkspace = false,
      displayName = null,
      phone = null,
      companyName = null,
      customerStatus = null,
      approvalStatus = null,
      avatarUrl = null,
      capabilities = AuthCapabilities.guest;

  const AuthState.authenticated({
    required String this.userId,
    this.canAccessInternalWorkspace = false,
    this.displayName,
    this.phone,
    this.companyName,
    this.customerStatus,
    this.approvalStatus,
    this.avatarUrl,
    this.capabilities = AuthCapabilities.guest,
  }) : status = AuthStatus.authenticated,
       message = null;

  const AuthState.guest()
    : status = AuthStatus.guest,
      userId = null,
      message = null,
      canAccessInternalWorkspace = false,
      displayName = null,
      phone = null,
      companyName = null,
      customerStatus = 'Guest',
      approvalStatus = null,
      avatarUrl = null,
      capabilities = AuthCapabilities.guest;

  const AuthState.unauthenticated({this.message})
    : status = AuthStatus.unauthenticated,
      userId = null,
      canAccessInternalWorkspace = false,
      displayName = null,
      phone = null,
      companyName = null,
      customerStatus = null,
      approvalStatus = null,
      avatarUrl = null,
      capabilities = AuthCapabilities.guest;

  AuthState copyWith({
    AuthStatus? status,
    String? userId,
    String? message,
    bool? canAccessInternalWorkspace,
    String? displayName,
    String? phone,
    String? companyName,
    String? customerStatus,
    String? approvalStatus,
    String? avatarUrl,
    AuthCapabilities? capabilities,
  }) {
    return AuthState(
      status: status ?? this.status,
      userId: userId ?? this.userId,
      message: message ?? this.message,
      canAccessInternalWorkspace:
          canAccessInternalWorkspace ?? this.canAccessInternalWorkspace,
      displayName: displayName ?? this.displayName,
      phone: phone ?? this.phone,
      companyName: companyName ?? this.companyName,
      customerStatus: customerStatus ?? this.customerStatus,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      capabilities: capabilities ?? this.capabilities,
    );
  }
}
