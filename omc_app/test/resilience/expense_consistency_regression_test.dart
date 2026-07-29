import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('expense save and import remain persistence-consistent', () {
    final source = File(
      'lib/features/expense_tracker/presentation/'
      'expense_tracker_screen.dart',
    ).readAsStringSync();

    expect(
      source,
      contains(
        'await _repository.saveTransactions(next);\n'
        '    state = AsyncData(next);',
      ),
    );
    expect(source, contains('var importing = false;'));
    expect(source, contains('if (importing) return;'));
    expect(source, contains('await ref'));
    expect(source, contains('.replaceAll(transactions);'));
    expect(source, contains("fallbackTitle: 'Import not completed'"));
    expect(source, contains('Importing...'));
    expect(source, contains(r'Imported ${transactions.length} transactions.'));
  });
}
