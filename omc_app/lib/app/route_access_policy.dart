import '../features/auth/application/auth_state.dart';

bool isGuestAllowedRoute(String location) {
  if (location == '/home' ||
      location == '/services' ||
      location == '/more' ||
      location == '/knowledge' ||
      location == '/tax-calculator' ||
      location == '/expense-tracker' ||
      location == '/support') {
    return true;
  }

  if (location.startsWith('/knowledge/')) return true;

  return location.startsWith('/services/') && !location.endsWith('/request');
}

bool canAccessRoute(String location, AuthCapabilities capabilities) {
  // Public utilities remain available to guest, customer, and staff personas.
  if (isGuestAllowedRoute(location)) return true;

  if (_isServiceRequestRoute(location)) {
    return capabilities.canCreateServiceRequest ||
        capabilities.canCreateServiceForCustomer;
  }

  if (location == '/dashboard') {
    return capabilities.canViewCustomerDashboard ||
        capabilities.canAccessCustomerDashboard ||
        capabilities.canAccessInternalWorkspace;
  }

  if (location == '/track') {
    return capabilities.canTrackRequests || capabilities.canViewAnyServiceCase;
  }

  if (location == '/my-services' || location.startsWith('/my-services/')) {
    return capabilities.canTrackRequests;
  }

  if (location == '/documents' || location.startsWith('/documents/')) {
    return capabilities.canViewDocuments ||
        capabilities.canUploadDocuments ||
        capabilities.canViewAnyDocument;
  }

  if (location == '/payments' || location.startsWith('/payments/')) {
    return capabilities.canViewPayments ||
        capabilities.canUploadPaymentReceipt ||
        capabilities.canUploadPaymentReceipts ||
        capabilities.canViewAnyPayment;
  }

  if (location == '/notifications' || location.startsWith('/notifications/')) {
    // The backend currently exposes a customer notification capability only.
    // Do not infer an internal notification permission from workspace access.
    return capabilities.canViewCustomerNotifications;
  }

  if (location.startsWith('/support-tickets/')) {
    // Customer support ownership is protected server-side. The customer
    // contract exposes ticket creation rather than a separate read flag.
    return capabilities.canCreateSupportTicket ||
        capabilities.canUseSupportWorkspace;
  }

  if (location == '/expense-budget') {
    return capabilities.isApproved || capabilities.isInternal;
  }

  if (location == '/internal-workspace') {
    return capabilities.canAccessInternalWorkspace;
  }

  if (location == '/admin-control/operations') {
    return capabilities.canReassignServiceCases ||
        capabilities.canRetrySync ||
        capabilities.canManageBusinessSettings;
  }

  if (location == '/admin-control') {
    return capabilities.canManageStaff ||
        capabilities.canReviewRegistrations ||
        capabilities.canManageBusinessSettings;
  }

  if (location.startsWith('/internal-workspace/service-cases')) {
    return capabilities.canViewAnyServiceCase;
  }

  if (location == '/internal-workspace/customers') {
    return capabilities.canManageCustomers ||
        capabilities.canViewAllCustomers ||
        capabilities.canViewRelevantCustomers;
  }

  if (location == '/internal-workspace/documents') {
    return capabilities.canViewAnyDocument;
  }

  if (location == '/internal-workspace/payments') {
    return capabilities.canViewAnyPayment;
  }

  // Unknown internal workspace sub-routes fail closed. New internal screens
  // must declare their capability rule explicitly above.
  if (location.startsWith('/internal-workspace/')) return false;

  if (location == '/leads' || location.startsWith('/leads/')) {
    return capabilities.canManageLeads;
  }

  if (location == '/customers' || location.startsWith('/customers/')) {
    return capabilities.canManageCustomers ||
        capabilities.canViewAllCustomers ||
        capabilities.canViewRelevantCustomers;
  }

  if (location == '/tasks' || location.startsWith('/tasks/')) {
    return capabilities.canManageTasks || capabilities.canManageAssignedTasks;
  }

  if (location == '/my-referrals' || location.startsWith('/my-referrals/')) {
    return capabilities.isInternal &&
        capabilities.canViewRelevantCustomers &&
        !capabilities.canViewAllCustomers;
  }

  if (location == '/my-commissions' ||
      location.startsWith('/my-commissions/')) {
    return capabilities.canViewReferralCommissions;
  }

  if (location == '/profile' ||
      location == '/profile/edit' ||
      location == '/settings' ||
      location == '/change-password') {
    return !capabilities.isGuest;
  }

  if (location == '/tax-calculator/history') {
    return !capabilities.isGuest && capabilities.canUseTaxCalculator;
  }

  return false;
}

bool _isServiceRequestRoute(String location) {
  return location.startsWith('/services/') && location.endsWith('/request');
}
