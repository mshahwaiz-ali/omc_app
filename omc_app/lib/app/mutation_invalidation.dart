import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/documents/data/documents_repository.dart';
import '../features/internal_workspace/presentation/internal_workspace_providers.dart';
import '../features/notifications/data/notifications_repository.dart';
import '../features/payments/data/payments_repository.dart';
import '../features/service_requests/data/service_case_repository.dart';

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
