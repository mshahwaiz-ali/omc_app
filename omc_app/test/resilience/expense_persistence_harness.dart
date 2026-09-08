import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omc_app/features/expense_tracker/data/expense_tracker_repository.dart';
import 'package:omc_app/features/expense_tracker/domain/expense_transaction.dart';
import 'package:omc_app/features/expense_tracker/presentation/expense_tracker_screen.dart';

ExpenseTransaction expenseRecord(String id, {bool synced = false}) {
  return ExpenseTransaction(
    id: id,
    type: ExpenseTransactionType.expense,
    amount: 10,
    category: 'Other',
    date: DateTime(2026, 9, 1),
    synced: synced,
  );
}

/// Deferred storage exposes the ordering between persistence and publication.
/// Unexpected API calls fail rather than silently passing through this fake.
class ExpensePersistenceProbe implements ExpenseTrackerRepository {
  ExpensePersistenceProbe(List<ExpenseTransaction> records)
    : persisted = List.of(records);

  List<ExpenseTransaction> persisted;
  Completer<void>? saveGate;
  Completer<void>? clearGate;
  Completer<bool>? deleteGate;
  final saveStarted = Completer<void>();
  final clearStarted = Completer<void>();
  final deleteStarted = Completer<void>();
  Object? saveError;
  Object? clearError;
  Object? deleteError;
  bool deleteConfirmed = true;
  int saveCalls = 0;
  int clearCalls = 0;
  int deleteCalls = 0;

  @override
  Future<List<ExpenseTransaction>> readTransactions() async {
    return List.of(persisted);
  }

  @override
  Future<void> saveTransactions(List<ExpenseTransaction> transactions) async {
    saveCalls++;
    if (!saveStarted.isCompleted) {
      saveStarted.complete();
    }
    final gate = saveGate;
    if (gate != null) {
      await gate.future;
    }
    final error = saveError;
    if (error != null) {
      throw error;
    }
    persisted = List.of(transactions);
  }

  @override
  Future<void> clearTransactions() async {
    clearCalls++;
    if (!clearStarted.isCompleted) {
      clearStarted.complete();
    }
    final gate = clearGate;
    if (gate != null) {
      await gate.future;
    }
    final error = clearError;
    if (error != null) {
      throw error;
    }
    persisted = [];
  }

  @override
  Future<bool> deleteSyncedTransaction(String id) async {
    deleteCalls++;
    if (!deleteStarted.isCompleted) {
      deleteStarted.complete();
    }
    final error = deleteError;
    if (error != null) {
      throw error;
    }
    final gate = deleteGate;
    return gate == null ? deleteConfirmed : await gate.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnsupportedError('Unexpected expense repository operation');
  }
}

class ExpensePersistenceHarness {
  ExpensePersistenceHarness._(this.probe, this.container);

  final ExpensePersistenceProbe probe;
  final ProviderContainer container;

  static Future<ExpensePersistenceHarness> create(
    ExpensePersistenceProbe probe,
  ) async {
    final container = ProviderContainer.test(
      overrides: [expenseTrackerRepositoryProvider.overrideWithValue(probe)],
    );
    container.listen(expenseTransactionsProvider, (_, _) {});
    await container.read(expenseTransactionsProvider.future);
    return ExpensePersistenceHarness._(probe, container);
  }

  ExpenseTransactionsController get controller {
    return container.read(expenseTransactionsProvider.notifier);
  }

  List<String> get visibleIds {
    return container
        .read(expenseTransactionsProvider)
        .value!
        .map((item) => item.id)
        .toList();
  }

  List<String> get persistedIds =>
      probe.persisted.map((item) => item.id).toList();
}
