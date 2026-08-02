import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/documents/data/documents_repository.dart';
import '../features/admin_control/data/admin_control_repository.dart';
import '../features/home/data/home_dashboard_repository.dart';
import '../features/internal_workspace/presentation/internal_workspace_providers.dart';
import '../features/notifications/data/notifications_repository.dart';
import '../features/payments/data/payments_repository.dart';
import '../features/service_requests/data/service_case_repository.dart';
import '../features/tasks/data/tasks_repository.dart';

void invalidateServiceMutation(WidgetRef ref, {String? caseId}) {
  ref
    ..invalidate(serviceCasesProvider)
    ..invalidate(internalServiceCasesProvider)
    ..invalidate(notificationsProvider);
  if (caseId?.trim().isNotEmpty ?? false) {
    ref.invalidate(serviceCaseDetailProvider(caseId!.trim()));
  }
}

void invalidateDocumentMutation(
  WidgetRef ref, {
  String? documentId,
  String? caseId,
}) {
  ref.invalidate(documentsProvider);
  if (documentId?.trim().isNotEmpty ?? false) {
    ref.invalidate(documentDetailProvider(documentId!.trim()));
  }
  invalidateServiceMutation(ref, caseId: caseId);
}

void invalidatePaymentMutation(
  WidgetRef ref, {
  String? paymentId,
  String? caseId,
}) {
  ref.invalidate(paymentsProvider);
  if (paymentId?.trim().isNotEmpty ?? false) {
    ref.invalidate(paymentDetailProvider(paymentId!.trim()));
  }
  invalidateServiceMutation(ref, caseId: caseId);
}

void invalidateAdministrativeCaseMutation(
  WidgetRef ref, {
  required String caseId,
}) {
  ref
    ..invalidate(adminOperationsProvider)
    ..invalidate(adminCaseOptionsProvider(caseId))
    ..invalidate(internalWorkspaceSummaryProvider)
    ..invalidate(homeDashboardSummaryProvider)
    ..invalidate(tasksProvider)
    ..invalidate(documentsProvider)
    ..invalidate(paymentsProvider);
  invalidateServiceMutation(ref, caseId: caseId);
}

void invalidateTaskMutation(
  WidgetRef ref, {
  required String taskId,
  String? caseId,
}) {
  ref
    ..invalidate(tasksProvider)
    ..invalidate(taskDetailProvider(taskId))
    ..invalidate(internalWorkspaceSummaryProvider)
    ..invalidate(homeDashboardSummaryProvider);
  invalidateServiceMutation(ref, caseId: caseId);
}
