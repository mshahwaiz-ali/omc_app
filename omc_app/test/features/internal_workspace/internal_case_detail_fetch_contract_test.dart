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
  final providers = File(
    'lib/features/internal_workspace/presentation/'
    'internal_workspace_providers.dart',
  ).readAsStringSync();

  final screen = File(
    'lib/features/internal_workspace/presentation/'
    'internal_operations_center_screen.dart',
  ).readAsStringSync();

  test('case detail provider performs scoped case-id fetch', () {
    expect(providers, contains('internalServiceCaseByIdProvider'));
    expect(providers, contains('internalServiceCasePageRepositoryProvider'));
    expect(providers, contains('caseId: cleanCaseId'));
    expect(providers, contains('limit: 1'));
  });

  test('case detail route does not depend on loaded queue page', () {
    final detail = _block(
      screen,
      'class InternalServiceCaseWorkspaceScreen',
      '// ignore: unused_element\n'
          'class _InternalPaymentFilters',
    );

    expect(detail, contains('internalServiceCaseByIdProvider(caseId)'));

    expect(detail, isNot(contains('ref.watch(internalServiceCasesProvider)')));

    expect(detail, isNot(contains('currently loaded internal queue')));
  });
}
