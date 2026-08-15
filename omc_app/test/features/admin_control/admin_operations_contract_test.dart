import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'routine administrative operations are reachable and capability gated',
    () {
      final router = File('lib/app/router.dart').readAsStringSync();
      final policy = File(
        'lib/app/route_access_policy.dart',
      ).readAsStringSync();
      final workspace = File(
        'lib/features/internal_workspace/presentation/internal_workspace_screen.dart',
      ).readAsStringSync();
      final screen = File(
        'lib/features/admin_control/presentation/admin_operations_screen.dart',
      ).readAsStringSync();

      expect(router, contains("path: '/admin-control/operations'"));
      expect(policy, contains('capabilities.canReassignServiceCases'));
      expect(policy, contains('capabilities.canRetrySync'));
      expect(workspace, contains("route: '/admin-control/operations'"));
      expect(screen, contains('Search eligible staff'));
      expect(screen, contains('Reason (optional)'));
      expect(screen, contains('Retry exhausted sync'));
      expect(screen, contains('Review remarks (required)'));
    },
  );

  test('administrative mutations use focused cross-feature invalidation', () {
    final source = File(
      'lib/app/mutation_invalidation.dart',
    ).readAsStringSync();
    for (final provider in const [
      'adminOperationsProvider',
      'adminCaseOptionsProvider',
      'internalWorkspaceSummaryProvider',
      'homeDashboardSummaryProvider',
      'tasksProvider',
      'documentsProvider',
      'paymentsProvider',
      'serviceCasesProvider',
      'serviceCaseDetailProvider',
    ]) {
      expect(source, contains(provider), reason: '$provider must be refreshed');
    }
  });

  test('payment review uses server paging and authenticated receipt bytes', () {
    final repository = File(
      'lib/features/payments/data/payments_repository.dart',
    ).readAsStringSync();
    final screen = File(
      'lib/features/internal_workspace/presentation/internal_operations_center_screen.dart',
    ).readAsStringSync();
    final detail = File(
      'lib/features/payments/presentation/payment_detail_screen.dart',
    ).readAsStringSync();

    expect(repository, contains("'limit_start': query.start"));
    expect(repository, contains("'limit_page_length': query.pageLength"));
    expect(repository, contains("'search': query.search.trim()"));
    expect(repository, contains("'status': query.status.trim()"));
    expect(screen, contains('paymentPageProvider(query)'));
    expect(detail, contains('downloadPaymentProof(payment)'));
    expect(detail, contains('DocumentPreviewScreen'));
    expect(detail, contains('fileName: file.name'));
    expect(detail, contains('bytes: file.bytes'));
  });
}
