import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('routed support wrapper still renders the legacy implementation', () {
    final wrapper = File(
      'lib/features/support/presentation/support_screen.dart',
    ).readAsStringSync();
    expect(wrapper, contains('const Expanded(child: legacy.SupportScreen())'));
  });

  test('live support ticket form uses persistent V2 field labels', () {
    final source = File(
      'lib/features/support/presentation/support_screen_legacy.dart',
    ).readAsStringSync();
    final start = source.indexOf('class _CreateSupportTicketCard');
    final end = source.indexOf('class _SupportTicketsCard', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final block = source.substring(start, end);

    expect(block, contains("AppLabeledField(\n            label: 'Topic'"));
    expect(block, contains("AppLabeledField(\n            label: 'Message'"));
    expect(block, contains('isRequired: true'));
    expect(block, isNot(contains("labelText: 'Topic'")));
    expect(block, isNot(contains("labelText: 'Message'")));
    expect(block, contains('padding: const EdgeInsets.all(AppSpacing.lg)'));
    expect(block, contains('textTheme.bodyMedium'));
    expect(block, isNot(contains('fontSize: 13')));
  });
}
