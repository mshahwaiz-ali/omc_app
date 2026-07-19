import '../../../app/route_access_policy.dart';
import '../../auth/application/auth_state.dart';

bool canUseHomeActionCapability(
  String? requiredCapability,
  AuthCapabilities capabilities, {
  bool allowWithoutRequirement = true,
}) {
  final key = requiredCapability?.trim().toLowerCase();
  if (key == null || key.isEmpty) return allowWithoutRequirement;

  return switch (key) {
    'can_view_documents' => canAccessRoute('/documents', capabilities),
    'can_track_requests' => canAccessRoute('/my-services', capabilities),
    'can_view_payments' => canAccessRoute('/payments', capabilities),
    'can_review_documents' => capabilities.canReviewDocuments,
    'can_review_payments' => capabilities.canReviewPayments,
    'can_manage_customers' => canAccessRoute('/customers', capabilities),
    'can_manage_leads' => canAccessRoute('/leads', capabilities),
    'can_manage_tasks' => canAccessRoute('/tasks', capabilities),
    'can_use_tax_calculator' => capabilities.canUseTaxCalculator,
    'can_access_customer_dashboard' => canAccessRoute(
      '/dashboard',
      capabilities,
    ),
    'can_access_internal_workspace' => canAccessRoute(
      '/internal-workspace',
      capabilities,
    ),
    'can_update_service_status' => capabilities.canUpdateServiceStatus,
    'can_update_support_ticket_status' =>
      capabilities.canUpdateSupportTicketStatus,
    'can_view_internal_notes' => capabilities.canViewInternalNotes,
    _ => false,
  };
}
