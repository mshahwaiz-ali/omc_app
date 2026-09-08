import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'expense_persistence_harness.dart';

void main() {
  test('expense save and import remain persistence-consistent', () {
    final source = File(
      'lib/features/expense_tracker/presentation/expense_tracker_screen.dart',
    ).readAsStringSync();

    // UI feedback remains covered here. Storage ordering is exercised below,
    // rather than matching private variable names or formatter line breaks.
    expect(source, contains('var importing = false;'));
    expect(
      RegExp(r'if\s*\(importing\)\s*(?:\{\s*)?return;').hasMatch(source),
      isTrue,
    );
    expect(source, contains('await ref'));
    expect(source, contains('.replaceAll(transactions);'));
    expect(source, contains("fallbackTitle: 'Import not completed'"));
    expect(source, contains('Importing...'));
    expect(source, contains(r'Imported ${transactions.length} transactions.'));
  });

  test('local add publishes only after persistence completes', () async {
    final probe = ExpensePersistenceProbe([expenseRecord('old')])
      ..saveGate = Completer<void>();
    final harness = await ExpensePersistenceHarness.create(probe);
    final result = harness.controller.add(expenseRecord('new'), sync: false);
    await probe.saveStarted.future;
    expect(harness.visibleIds, ['old']);
    expect(harness.persistedIds, ['old']);
    probe.saveGate!.complete();
    expect((await result).id, 'new');
    expect(harness.visibleIds.toSet(), {'old', 'new'});
    expect(harness.persistedIds.toSet(), {'old', 'new'});
  });

  test('failed local add preserves data and propagates the failure', () async {
    final probe = ExpensePersistenceProbe([expenseRecord('old')])
      ..saveGate = Completer<void>()
      ..saveError = StateError('Storage unavailable');
    final harness = await ExpensePersistenceHarness.create(probe);
    final result = harness.controller.add(expenseRecord('new'), sync: false);
    final rejected = expectLater(result, throwsStateError);
    await probe.saveStarted.future;
    probe.saveGate!.complete();
    await rejected;
    expect(harness.visibleIds, ['old']);
    expect(harness.persistedIds, ['old']);
    // A failure must also release the mutation guard for an explicit retry.
    probe.saveError = null;
    probe.saveGate = null;
    await harness.controller.add(expenseRecord('new'), sync: false);
    expect(harness.visibleIds.toSet(), {'old', 'new'});
  });

  test(
    'import replacement publishes only after persistence completes',
    () async {
      final probe = ExpensePersistenceProbe([expenseRecord('old')])
        ..saveGate = Completer<void>();
      final harness = await ExpensePersistenceHarness.create(probe);
      final result = harness.controller.replaceAll([expenseRecord('imported')]);
      await probe.saveStarted.future;
      expect(harness.visibleIds, ['old']);
      probe.saveGate!.complete();
      await result;
      expect(harness.visibleIds, ['imported']);
      expect(harness.persistedIds, ['imported']);
    },
  );

  test('failed import preserves the previous local collection', () async {
    final probe = ExpensePersistenceProbe([expenseRecord('old')])
      ..saveGate = Completer<void>()
      ..saveError = StateError('Storage unavailable');
    final harness = await ExpensePersistenceHarness.create(probe);
    final result = harness.controller.replaceAll([expenseRecord('imported')]);
    final rejected = expectLater(result, throwsStateError);
    await probe.saveStarted.future;
    probe.saveGate!.complete();
    await rejected;
    expect(harness.visibleIds, ['old']);
    expect(harness.persistedIds, ['old']);
  });
}
