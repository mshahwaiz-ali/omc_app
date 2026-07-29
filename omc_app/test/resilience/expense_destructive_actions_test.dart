import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('expense destructive actions await persistence and report failures', () {
    final source = File(
      'lib/features/expense_tracker/presentation/'
      'expense_tracker_screen.dart',
    ).readAsStringSync();

    expect(source, contains('await _repository.saveTransactions(next);'));
    expect(source, contains('await _repository.clearTransactions();'));

    expect(source, contains('await ref'));
    expect(source, contains('.read(expenseTransactionsProvider.notifier)'));
    expect(source, contains('.remove(id, sync: sync)'));
    expect(source, contains('.clearAll();'));

    expect(source, contains("fallbackTitle: 'Transaction not archived'"));
    expect(source, contains("fallbackTitle: 'Local data not cleared'"));
    expect(source, contains('Transaction archived.'));
    expect(source, contains('Local tracker cleared.'));
  });
}
