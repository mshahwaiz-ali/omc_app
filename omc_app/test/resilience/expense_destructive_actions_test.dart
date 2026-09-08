import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'expense_persistence_harness.dart';

void main() {
  test('expense destructive actions await persistence and report failures', () {
    final source = File(
      'lib/features/expense_tracker/presentation/expense_tracker_screen.dart',
    ).readAsStringSync();

    // Preserve the UI action/feedback assertions. The controller's actual
    // persistence and rejection behavior is exercised by the tests below.
    expect(source, contains('await ref'));
    expect(source, contains('.read(expenseTransactionsProvider.notifier)'));
    expect(source, contains('.remove(id, sync: sync)'));
    expect(source, contains('.clearAll();'));
    expect(source, contains("fallbackTitle: 'Transaction not archived'"));
    expect(source, contains("fallbackTitle: 'Local data not cleared'"));
    expect(source, contains('Transaction archived.'));
    expect(source, contains('Local tracker cleared.'));
  });

  test('local remove waits for persistence before publishing', () async {
    final probe = ExpensePersistenceProbe([expenseRecord('old')])
      ..saveGate = Completer<void>();
    final harness = await ExpensePersistenceHarness.create(probe);
    final result = harness.controller.remove('old', sync: false);
    await probe.saveStarted.future;
    expect(harness.visibleIds, ['old']);
    expect(harness.persistedIds, ['old']);
    probe.saveGate!.complete();
    await result;
    expect(harness.visibleIds, isEmpty);
    expect(harness.persistedIds, isEmpty);
    expect(probe.deleteCalls, 0);
  });

  test('failed local remove retains the existing record', () async {
    final probe = ExpensePersistenceProbe([expenseRecord('old')])
      ..saveGate = Completer<void>()
      ..saveError = StateError('Storage unavailable');
    final harness = await ExpensePersistenceHarness.create(probe);
    final result = harness.controller.remove('old', sync: false);
    final rejected = expectLater(result, throwsStateError);
    await probe.saveStarted.future;
    probe.saveGate!.complete();
    await rejected;
    expect(harness.visibleIds, ['old']);
    expect(harness.persistedIds, ['old']);
  });

  test(
    'clear waits for storage and publishes an empty collection afterwards',
    () async {
      final probe = ExpensePersistenceProbe([expenseRecord('old')])
        ..clearGate = Completer<void>();
      final harness = await ExpensePersistenceHarness.create(probe);
      final result = harness.controller.clearAll();
      await probe.clearStarted.future;
      expect(harness.visibleIds, ['old']);
      expect(harness.persistedIds, ['old']);
      probe.clearGate!.complete();
      await result;
      expect(harness.visibleIds, isEmpty);
      expect(harness.persistedIds, isEmpty);
    },
  );

  test('failed clear retains the collection and permits retry', () async {
    final probe = ExpensePersistenceProbe([expenseRecord('old')])
      ..clearGate = Completer<void>()
      ..clearError = StateError('Storage unavailable');
    final harness = await ExpensePersistenceHarness.create(probe);
    final result = harness.controller.clearAll();
    final rejected = expectLater(result, throwsStateError);
    await probe.clearStarted.future;
    probe.clearGate!.complete();
    await rejected;
    expect(harness.visibleIds, ['old']);
    expect(harness.persistedIds, ['old']);
    probe.clearError = null;
    probe.clearGate = null;
    await harness.controller.clearAll();
    expect(harness.visibleIds, isEmpty);
    expect(probe.clearCalls, 2);
  });

  test('unconfirmed remote deletion cannot remove local data', () async {
    final probe = ExpensePersistenceProbe([expenseRecord('old', synced: true)])
      ..deleteConfirmed = false;
    final harness = await ExpensePersistenceHarness.create(probe);
    await expectLater(
      harness.controller.remove('old', sync: true),
      throwsStateError,
    );
    expect(probe.deleteCalls, 1);
    expect(probe.saveCalls, 0);
    expect(harness.visibleIds, ['old']);
    expect(harness.persistedIds, ['old']);
  });

  test('remote deletion failure cannot remove local data', () async {
    final probe = ExpensePersistenceProbe([expenseRecord('old', synced: true)])
      ..deleteError = StateError('Remote delete unavailable');
    final harness = await ExpensePersistenceHarness.create(probe);
    await expectLater(
      harness.controller.remove('old', sync: true),
      throwsStateError,
    );
    expect(probe.saveCalls, 0);
    expect(harness.visibleIds, ['old']);
    expect(harness.persistedIds, ['old']);
  });

  test(
    'synced deletion waits for both remote confirmation and local persistence',
    () async {
      final probe =
          ExpensePersistenceProbe([expenseRecord('old', synced: true)])
            ..deleteGate = Completer<bool>()
            ..saveGate = Completer<void>();
      final harness = await ExpensePersistenceHarness.create(probe);
      final result = harness.controller.remove('old', sync: true);
      await probe.deleteStarted.future;
      expect(probe.saveCalls, 0);
      expect(harness.visibleIds, ['old']);
      probe.deleteGate!.complete(true);
      await probe.saveStarted.future;
      expect(harness.visibleIds, ['old']);
      probe.saveGate!.complete();
      await result;
      expect(harness.visibleIds, isEmpty);
      expect(harness.persistedIds, isEmpty);
    },
  );
}
