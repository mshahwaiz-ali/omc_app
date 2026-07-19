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
    this.canViewSupportTickets = false,
    this.canViewCustomerDashboard = false,
    this.canAccessCustomerDashboard = false,
    this.canViewCustomerNotifications = false,
    this.canAccessInternalWorkspace = false,
    this.canUpdateServiceStatus = false,
    this.canReviewDocuments = false,
    this.canReviewPayments = false,
    this.canUpdateSupportTicketStatus = false,
    this.canManageCustomers = false,
    this.canViewAllCustomers = false,
    this.canViewRelevantCustomers = false,
    this.canManageLeads = false,
    this.canManageTasks = false,
    this.canManageAssignedTasks = false,
    this.canCreateServiceForCustomer = false,
    this.canViewAllServiceCases = false,
    this.canViewRelevantServiceCases = false,
    this.canViewAssignedServiceCases = false,
    this.canUpdateAssignedServiceStatus = false,

    this.canViewDocumentQueue = false,
    this.canViewDocumentSummaries = false,
    this.canViewDocumentAttachments = false,
    this.canViewPaymentQueue = false,
    this.canViewPaymentSummaries = false,
    this.canViewPaymentReceipts = false,
    this.canReplySupportTickets = false,
    this.canAssignSupportTickets = false,
    this.canManageSettings = false,
    this.canViewInternalNotes = false,
  });

  final AccountAccessState accessState;
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
  final bool canViewSupportTickets;
  final bool canViewCustomerDashboard;
  final bool canAccessCustomerDashboard;
  final bool canViewCustomerNotifications;
  final bool canAccessInternalWorkspace;
  final bool canUpdateServiceStatus;
  final bool canReviewDocuments;
  final bool canReviewPayments;
  final bool canUpdateSupportTicketStatus;
  final bool canManageCustomers;
  final bool canViewAllCustomers;
  final bool canViewRelevantCustomers;
  final bool canManageLeads;
  final bool canManageTasks;
  final bool canManageAssignedTasks;
  final bool canCreateServiceForCustomer;
  final bool canViewAllServiceCases;
  final bool canViewRelevantServiceCases;
  final bool canViewAssignedServiceCases;
  final bool canUpdateAssignedServiceStatus;

  final bool canViewDocumentQueue;
  final bool canViewDocumentSummaries;
  final bool canViewDocumentAttachments;
  final bool canViewPaymentQueue;
  final bool canViewPaymentSummaries;
  final bool canViewPaymentReceipts;
  final bool canReplySupportTickets;
  final bool canAssignSupportTickets;
  final bool canManageSettings;
  final bool canViewInternalNotes;

  static const guest = AuthCapabilities(accessState: AccountAccessState.guest);

  bool get isGuest => accessState == AccountAccessState.guest;
  bool get isPending => accessState == AccountAccessState.pending;
  bool get isApproved => accessState == AccountAccessState.approved;
  bool get isInternal => accessState == AccountAccessState.internal;
  bool get isRejected => accessState == AccountAccessState.rejected;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is AuthCapabilities &&
            runtimeType == other.runtimeType &&
            accessState == other.accessState &&
            canViewPublicCatalogue == other.canViewPublicCatalogue &&
            canViewPublicContent == other.canViewPublicContent &&
            canUseTaxCalculator == other.canUseTaxCalculator &&
            canCreateServiceRequest == other.canCreateServiceRequest &&
            canUploadDocuments == other.canUploadDocuments &&
            canTrackRequests == other.canTrackRequests &&
            canViewDocuments == other.canViewDocuments &&
            canViewPayments == other.canViewPayments &&
            canUploadPaymentReceipt == other.canUploadPaymentReceipt &&
            canUploadPaymentReceipts == other.canUploadPaymentReceipts &&
            canCreateSupportTicket == other.canCreateSupportTicket &&
            canViewSupportTickets == other.canViewSupportTickets &&
            canViewCustomerDashboard == other.canViewCustomerDashboard &&
            canAccessCustomerDashboard == other.canAccessCustomerDashboard &&
            canViewCustomerNotifications ==
                other.canViewCustomerNotifications &&
            canAccessInternalWorkspace == other.canAccessInternalWorkspace &&
            canUpdateServiceStatus == other.canUpdateServiceStatus &&
            canReviewDocuments == other.canReviewDocuments &&
            canReviewPayments == other.canReviewPayments &&
            canUpdateSupportTicketStatus ==
                other.canUpdateSupportTicketStatus &&
            canManageCustomers == other.canManageCustomers &&
            canViewAllCustomers == other.canViewAllCustomers &&
            canViewRelevantCustomers == other.canViewRelevantCustomers &&
            canManageLeads == other.canManageLeads &&
            canManageTasks == other.canManageTasks &&
            canCreateServiceForCustomer == other.canCreateServiceForCustomer &&
            canViewRelevantServiceCases == other.canViewRelevantServiceCases &&
            canViewAssignedServiceCases == other.canViewAssignedServiceCases &&
            canManageAssignedTasks == other.canManageAssignedTasks &&
            canViewAllServiceCases == other.canViewAllServiceCases &&
            canViewRelevantServiceCases == other.canViewRelevantServiceCases &&
            canViewAssignedServiceCases == other.canViewAssignedServiceCases &&
            canCreateServiceForCustomer == other.canCreateServiceForCustomer &&
            canUpdateAssignedServiceStatus ==
                other.canUpdateAssignedServiceStatus &&
            canViewDocumentQueue == other.canViewDocumentQueue &&
            canViewDocumentSummaries == other.canViewDocumentSummaries &&
            canViewDocumentAttachments == other.canViewDocumentAttachments &&
            canViewPaymentQueue == other.canViewPaymentQueue &&
            canViewPaymentSummaries == other.canViewPaymentSummaries &&
            canViewPaymentReceipts == other.canViewPaymentReceipts &&
            canReplySupportTickets == other.canReplySupportTickets &&
            canAssignSupportTickets == other.canAssignSupportTickets &&
            canManageSettings == other.canManageSettings &&
            canViewInternalNotes == other.canViewInternalNotes;
  }

  @override
  int get hashCode => Object.hashAll([
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
    canViewSupportTickets,
    canViewCustomerDashboard,
    canAccessCustomerDashboard,
    canViewCustomerNotifications,
    canAccessInternalWorkspace,
    canUpdateServiceStatus,
    canReviewDocuments,
    canReviewPayments,
    canUpdateSupportTicketStatus,
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
    canUpdateAssignedServiceStatus,
    canViewDocumentQueue,
    canViewDocumentSummaries,
    canViewDocumentAttachments,
    canViewPaymentQueue,
    canViewPaymentSummaries,
    canViewPaymentReceipts,
    canReplySupportTickets,
    canAssignSupportTickets,
    canManageSettings,
    canViewInternalNotes,
  ]);

  factory AuthCapabilities.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return guest;

    final accessState = _accessStateFromJson(json);
    final isApprovedCustomer = accessState == AccountAccessState.approved;
    final isInternal = accessState == AccountAccessState.internal;

    final canUploadPaymentReceipt = _boolValue(
      json['can_upload_payment_receipt'] ?? json['can_upload_payment_receipts'],
      isApprovedCustomer,
    );
    final canViewCustomerDashboard = _boolValue(
      json['can_view_customer_dashboard'] ??
          json['can_access_customer_dashboard'],
      isApprovedCustomer,
    );

    return AuthCapabilities(
      accessState: accessState,
      canViewPublicCatalogue: _boolValue(
        json['can_view_public_catalogue'],
        true,
      ),
      canViewPublicContent: _boolValue(json['can_view_public_content'], true),
      canUseTaxCalculator: _boolValue(json['can_use_tax_calculator'], true),
      canCreateServiceRequest: _boolValue(
        json['can_create_service_request'],
        isApprovedCustomer,
      ),
      canUploadDocuments: _boolValue(
        json['can_upload_documents'],
        isApprovedCustomer,
      ),
      canTrackRequests: _boolValue(
        json['can_track_requests'],
        isApprovedCustomer,
      ),
      canViewDocuments: _boolValue(
        json['can_view_documents'],
        isApprovedCustomer,
      ),
      canViewPayments: _boolValue(
        json['can_view_payments'],
        isApprovedCustomer,
      ),
      canUploadPaymentReceipt: canUploadPaymentReceipt,
      canUploadPaymentReceipts: canUploadPaymentReceipt,
      canCreateSupportTicket: _boolValue(
        json['can_create_support_ticket'],
        isApprovedCustomer,
      ),
      canViewSupportTickets: _boolValue(
        json['can_view_support_tickets'],
        isApprovedCustomer,
      ),
      canViewCustomerDashboard: canViewCustomerDashboard,
      canAccessCustomerDashboard: canViewCustomerDashboard,
      canViewCustomerNotifications: _boolValue(
        json['can_view_customer_notifications'],
        isApprovedCustomer,
      ),
      canAccessInternalWorkspace: _boolValue(
        json['can_access_internal_workspace'],
        isInternal,
      ),
      canUpdateServiceStatus: _boolValue(json['can_update_service_status']),
      canReviewDocuments: _boolValue(json['can_review_documents']),
      canReviewPayments: _boolValue(json['can_review_payments']),
      canUpdateSupportTicketStatus: _boolValue(
        json['can_update_support_ticket_status'],
      ),
      canReplySupportTickets: _boolValue(json['can_reply_support_tickets']),
      canAssignSupportTickets: _boolValue(json['can_assign_support_tickets']),
      canManageCustomers: _boolValue(json['can_manage_customers']),
      canViewAllCustomers: _boolValue(json['can_view_all_customers']),
      canViewRelevantCustomers: _boolValue(json['can_view_relevant_customers']),
      canManageLeads: _boolValue(json['can_manage_leads']),
      canManageTasks: _boolValue(json['can_manage_tasks']),
      canManageAssignedTasks: _boolValue(json['can_manage_assigned_tasks']),
      canCreateServiceForCustomer: _boolValue(
        json['can_create_service_for_customer'],
      ),
      canViewAllServiceCases: _boolValue(json['can_view_all_service_cases']),
      canViewRelevantServiceCases: _boolValue(
        json['can_view_relevant_service_cases'],
      ),
      canViewAssignedServiceCases: _boolValue(
        json['can_view_assigned_service_cases'],
      ),
      canUpdateAssignedServiceStatus: _boolValue(
        json['can_update_assigned_service_status'],
      ),
      canViewDocumentQueue: _boolValue(json['can_view_document_queue']),
      canViewDocumentSummaries: _boolValue(json['can_view_document_summaries']),
      canViewDocumentAttachments: _boolValue(
        json['can_view_document_attachments'],
      ),
      canViewPaymentQueue: _boolValue(json['can_view_payment_queue']),
      canViewPaymentSummaries: _boolValue(json['can_view_payment_summaries']),
      canViewPaymentReceipts: _boolValue(json['can_view_payment_receipts']),
      canManageSettings: _boolValue(json['can_manage_settings']),
      canViewInternalNotes: _boolValue(json['can_view_internal_notes']),
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
    if (text == 'rejected') return AccountAccessState.rejected;
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
