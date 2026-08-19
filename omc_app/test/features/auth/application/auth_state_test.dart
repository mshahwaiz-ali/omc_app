import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/features/auth/application/auth_state.dart';

void main() {
  group('AuthCapabilities.fromJson', () {
    test('does not grant customer service requests to internal users', () {
      final capabilities = AuthCapabilities.fromJson({
        'access_state': 'internal',
        'can_access_internal_workspace': true,
        'can_create_service_request': false,
      });

      expect(capabilities.isInternal, isTrue);
      expect(capabilities.canAccessInternalWorkspace, isTrue);
      expect(capabilities.canCreateServiceRequest, isFalse);
    });

    test('fails closed when a protected capability key is missing', () {
      final capabilities = AuthCapabilities.fromJson({
        'access_state': 'approved',
      });

      expect(capabilities.isApproved, isTrue);
      expect(capabilities.canCreateServiceRequest, isFalse);
      expect(capabilities.canViewDocuments, isFalse);
      expect(capabilities.canViewPayments, isFalse);
      expect(capabilities.canViewCustomerNotifications, isFalse);
    });

    test('honors explicit approved-customer capability grants', () {
      final capabilities = AuthCapabilities.fromJson({
        'access_state': 'approved',
        'can_create_service_request': true,
        'can_upload_documents': true,
        'can_track_requests': true,
        'can_view_documents': true,
        'can_view_payments': true,
        'can_upload_payment_receipt': true,
        'can_upload_payment_receipts': true,
        'can_create_support_ticket': true,
        'can_view_customer_dashboard': true,
        'can_access_customer_dashboard': true,
        'can_view_customer_notifications': true,
      });

      expect(capabilities.canCreateServiceRequest, isTrue);
      expect(capabilities.canUploadDocuments, isTrue);
      expect(capabilities.canTrackRequests, isTrue);
      expect(capabilities.canViewDocuments, isTrue);
      expect(capabilities.canViewPayments, isTrue);
      expect(capabilities.canUploadPaymentReceipt, isTrue);
      expect(capabilities.canUploadPaymentReceipts, isTrue);
      expect(capabilities.canCreateSupportTicket, isTrue);
      expect(capabilities.canViewCustomerDashboard, isTrue);
      expect(capabilities.canAccessCustomerDashboard, isTrue);
      expect(capabilities.canViewCustomerNotifications, isTrue);
    });

    test('maps finance and commission capabilities one-to-one', () {
      final capabilities = AuthCapabilities.fromJson({
        'access_state': 'internal',
        'can_access_internal_workspace': true,
        'can_reconcile_settlement': true,
        'can_approve_post_paid': true,
        'can_view_referral_commissions': true,
        'can_approve_commissions': true,
        'can_mark_commissions_paid': true,
      });

      expect(capabilities.canReconcileSettlement, isTrue);
      expect(capabilities.canApprovePostPaid, isTrue);
      expect(capabilities.canViewReferralCommissions, isTrue);
      expect(capabilities.canApproveCommissions, isTrue);
      expect(capabilities.canMarkCommissionsPaid, isTrue);
      expect(capabilities.canManageReferralCommissions, isTrue);
    });

    test('does not parse retired synthetic capability keys as authority', () {
      final capabilities = AuthCapabilities.fromJson({
        'access_state': 'internal',
        'can_access_internal_workspace': true,
        'can_manage_customer_service_flow': true,
        'can_view_customer_documents': true,
        'can_view_customer_payments': true,
        'can_manage_referral_commissions': true,
      });

      expect(capabilities.canViewAnyServiceCase, isFalse);
      expect(capabilities.canViewAnyDocument, isFalse);
      expect(capabilities.canViewAnyPayment, isFalse);
      expect(capabilities.canApproveCommissions, isFalse);
      expect(capabilities.canMarkCommissionsPaid, isFalse);
    });

    test('maps blocked backend access to rejected client access', () {
      final capabilities = AuthCapabilities.fromJson({
        'access_state': 'blocked',
      });

      expect(capabilities.isRejected, isTrue);
    });
  });
}
