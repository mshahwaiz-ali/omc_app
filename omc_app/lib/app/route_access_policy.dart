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
  if (isGuestAllowedRoute(location)) return true;

  if (_isServiceRequestRoute(location)) {
    return capabilities.canCreateServiceRequest;
  }

  if (location == '/dashboard') {
    return capabilities.canViewCustomerDashboard ||
        capabilities.canAccessInternalWorkspace;
  }

  if (location == '/track' ||
      location == '/my-services' ||
      location.startsWith('/my-services/')) {
    return capabilities.canTrackRequests;
  }

  if (location == '/documents' || location.startsWith('/documents/')) {
    return capabilities.canViewDocuments || capabilities.canReviewDocuments;
  }

  if (location == '/payments' || location.startsWith('/payments/')) {
    return capabilities.canViewPayments || capabilities.canReviewPayments;
  }

  if (location == '/notifications' || location.startsWith('/notifications/')) {
    return capabilities.canViewCustomerNotifications ||
        capabilities.canAccessInternalWorkspace;
  }

  if (location.startsWith('/support-tickets/')) {
    return capabilities.canViewSupportTickets ||
        capabilities.canUpdateSupportTicketStatus;
  }

  if (location == '/expense-tracker') {
    return !capabilities.isInternal;
  }

  if (location == '/expense-budget') {
    return capabilities.isApproved;
  }

  if (location == '/internal-workspace' ||
      location.startsWith('/internal-workspace/')) {
    return capabilities.canAccessInternalWorkspace;
  }

  if (location == '/leads' || location.startsWith('/leads/')) {
    return capabilities.canManageLeads;
  }

  if (location == '/customers' || location.startsWith('/customers/')) {
    return capabilities.canManageCustomers;
  }

  if (location == '/tasks' || location.startsWith('/tasks/')) {
    return capabilities.canManageTasks;
  }

  // Unclassified authenticated routes retain their existing behavior for now.
  // A later route-inventory batch will replace this with deny-by-default.
  return true;
}

bool _isServiceRequestRoute(String location) {
  return location.startsWith('/services/') && location.endsWith('/request');
}
