import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/features/auth/application/auth_state.dart';
import 'package:omc_app/features/internal_workspace/application/internal_workspace_focus.dart';

void main() {
  const internal = AccountAccessState.internal;

  test('leadership focus wins over specialist capabilities', () {
    const capabilities = AuthCapabilities(
      accessState: internal,
      canViewAllServiceCases: true,
      canReconcileSettlement: true,
      canReviewPayments: true,
      canViewAssignedServiceCases: true,
    );

    final focus = InternalWorkspaceFocus.fromCapabilities(capabilities);

    expect(focus.kind, InternalWorkspaceFocusKind.leadership);
    expect(focus.title, 'Operations Command');
    expect(focus.showServicePerformance, isFalse);
  });

  test('finance focus uses finance capabilities without broad authority', () {
    const capabilities = AuthCapabilities(
      accessState: internal,
      canViewRelevantServiceCases: true,
      canViewPaymentQueue: true,
      canReviewPayments: true,
      canReconcileSettlement: true,
      canManageAssignedTasks: true,
    );

    final focus = InternalWorkspaceFocus.fromCapabilities(capabilities);

    expect(focus.kind, InternalWorkspaceFocusKind.finance);
    expect(focus.canShowPayments, isTrue);
    expect(focus.canShowSettlementExceptions, isTrue);
    expect(focus.canShowTasks, isTrue);
    expect(focus.canShowDocuments, isFalse);
  });

  test('document review focus does not widen queue visibility', () {
    const capabilities = AuthCapabilities(
      accessState: internal,
      canViewRelevantServiceCases: true,
      canViewDocumentQueue: true,
      canViewDocumentAttachments: true,
      canReviewDocuments: true,
      canManageAssignedTasks: true,
    );

    final focus = InternalWorkspaceFocus.fromCapabilities(capabilities);

    expect(focus.kind, InternalWorkspaceFocusKind.documentReview);
    expect(focus.canShowDocuments, isTrue);
    expect(focus.canShowPayments, isFalse);
    expect(focus.canShowSettlementExceptions, isFalse);
  });

  test('support focus has precedence over generic client work', () {
    const capabilities = AuthCapabilities(
      accessState: internal,
      canViewRelevantServiceCases: true,
      canViewRelevantCustomers: true,
      canCreateServiceForCustomer: true,
      canManageAssignedTasks: true,
      canViewSupportTickets: true,
      canReplySupportTickets: true,
    );

    final focus = InternalWorkspaceFocus.fromCapabilities(capabilities);

    expect(focus.kind, InternalWorkspaceFocusKind.support);
    expect(focus.canCreateServiceForCustomer, isTrue);
    expect(focus.canShowCustomers, isTrue);
  });

  test('assigned field staff receive client-work focus', () {
    const capabilities = AuthCapabilities(
      accessState: internal,
      canViewAssignedServiceCases: true,
      canUpdateAssignedServiceStatus: true,
      canViewRelevantCustomers: true,
      canCreateServiceForCustomer: true,
      canManageAssignedTasks: true,
      canViewReferralCommissions: true,
    );

    final focus = InternalWorkspaceFocus.fromCapabilities(capabilities);

    expect(focus.kind, InternalWorkspaceFocusKind.clientWork);
    expect(focus.showServicePerformance, isTrue);
    expect(focus.canShowServiceCases, isTrue);
    expect(focus.canShowTasks, isTrue);
  });

  test('visibility is derived only from exact canonical capabilities', () {
    const capabilities = AuthCapabilities(
      accessState: internal,
      canAccessInternalWorkspace: true,
    );

    final focus = InternalWorkspaceFocus.fromCapabilities(capabilities);

    expect(focus.kind, InternalWorkspaceFocusKind.operations);
    expect(focus.canShowServiceCases, isFalse);
    expect(focus.canShowDocuments, isFalse);
    expect(focus.canShowPayments, isFalse);
    expect(focus.canShowCustomers, isFalse);
    expect(focus.canShowLeads, isFalse);
    expect(focus.canShowTasks, isFalse);
    expect(focus.canCreateServiceForCustomer, isFalse);
    expect(focus.canShowSettlementExceptions, isFalse);
    expect(focus.canShowAdminControls, isFalse);
    expect(focus.canShowOperationalControls, isFalse);
  });
}
