import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

String _block(String source, String start, String end) {
  final startIndex = source.indexOf(start);
  final endIndex = source.indexOf(end, startIndex + start.length);
  expect(startIndex, greaterThanOrEqualTo(0), reason: 'missing $start');
  expect(endIndex, greaterThan(startIndex), reason: 'missing $end');
  return source.substring(startIndex, endIndex);
}

void main() {
  final router = File('lib/app/router.dart').readAsStringSync();
  final source = File(
    'lib/features/internal_workspace/presentation/internal_operations_center_screen.dart',
  ).readAsStringSync();

  test(
    'router keeps dedicated customer/document owners and V2 payment owner',
    () {
      expect(router, contains("path: '/internal-workspace/customers'"));
      expect(router, contains('const CustomersScreen()'));
      expect(router, contains("path: '/internal-workspace/documents'"));
      expect(router, contains('const InternalDocumentReviewScreen()'));
      expect(
        router,
        contains(
          'const InternalOperationsCenterScreen(\n            area: InternalOperationArea.payments,',
        ),
      );
    },
  );

  test('live internal operation states use V2 scale, targets and radii', () {
    final caseState = _block(
      source,
      'class _CaseDetailsState',
      'class _CaseProgressState',
    );
    expect(caseState, contains('textTheme.titleMedium'));
    expect(caseState, contains('textTheme.bodyMedium'));
    expect(caseState, contains('width: double.infinity'));
    expect(caseState, contains('BorderRadius.circular(AppRadius.control)'));
    expect(caseState, isNot(contains('height: 44')));
    expect(caseState, isNot(contains('FontWeight.w900')));
    expect(caseState, isNot(contains('fontSize: 12.5')));
    expect(
      caseState,
      isNot(contains('backgroundColor: const Color(0xFF263244)')),
    );

    final loadingCard = _block(
      source,
      'class _LoadingCard',
      'class _OperationsError',
    );
    expect(loadingCard, contains('BorderRadius.circular(AppRadius.card)'));

    final skeleton = _block(
      source,
      'class _CaseSkeletonCard',
      'class _CaseDetailsState',
    );
    expect(skeleton, contains('BorderRadius.circular(AppRadius.card)'));
  });

  test('live metrics and workflow state do not use caption typography', () {
    final paymentMetric = _block(
      source,
      'class _PaymentPageMetricView',
      'class _PaymentResultsHeader',
    );
    expect(paymentMetric, contains('textTheme.bodyMedium'));
    expect(paymentMetric, isNot(contains('textTheme.bodySmall')));

    final evidenceMetric = _block(
      source,
      'class _CaseEvidenceMetricViewV2',
      'class _CaseOverviewV2',
    );
    expect(evidenceMetric, contains('textTheme.bodyMedium'));
    expect(evidenceMetric, isNot(contains('textTheme.bodySmall')));

    final progressRow = _block(
      source,
      'class _CaseProgressRowV2',
      'class _CaseTimelineV2',
    );
    expect(
      progressRow,
      contains('textTheme.labelMedium?.copyWith(color: color)'),
    );
    expect(
      progressRow,
      isNot(contains('textTheme.bodySmall?.copyWith(color: color)')),
    );
  });

  test(
    'standalone live loading and error states use responsive page layout',
    () {
      final stateList = _block(
        source,
        'class _OperationsStateListView',
        'class _CaseDetailsLoading',
      );
      expect(
        stateList,
        contains('AppLayout.pageInsetFor(constraints.maxWidth)'),
      );
      expect(stateList, contains('AppLayout.generalMaxWidth'));

      for (final pair in const [
        ['class _CaseDetailsLoading', 'class _CaseSkeletonCard'],
        ['class _CaseDetailsState', 'class _CaseProgressState'],
        ['class _OperationsLoading', 'class _LoadingCard'],
        ['class _OperationsError', 'class _OperationsEmpty'],
      ]) {
        final block = _block(source, pair[0], pair[1]);
        expect(block, contains('_OperationsStateListView('));
        expect(block, isNot(contains('padding: _kOpsPadding')));
      }
    },
  );
}
