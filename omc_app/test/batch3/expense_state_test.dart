import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/app/providers/core_providers.dart';
import 'package:omc_app/features/expense_tracker/data/expense_tracker_repository.dart';
import 'package:omc_app/features/expense_tracker/domain/expense_transaction.dart';
import 'package:omc_app/features/expense_tracker/presentation/expense_tracker_screen.dart';

ExpenseTransaction item(String id, {bool synced = false}) => ExpenseTransaction(
  id: id,
  type: ExpenseTransactionType.expense,
  amount: 10,
  category: 'Other',
  date: DateTime(2026, 9, 1),
  synced: synced,
);

class ExpenseRepositoryFake implements ExpenseTrackerRepository {
  ExpenseRepositoryFake(this.local, this.reply);
  List<ExpenseTransaction> local;
  List<ExpenseTransaction> reply;
  List<ExpenseTransaction> sent = [];
  Completer<List<ExpenseTransaction>>? deferred;
  int writes = 0;
  @override
  Future<List<ExpenseTransaction>> readTransactions() async => [...local];
  @override
  Future<void> saveTransactions(List<ExpenseTransaction> values) async {
    writes++;
    local = [...values];
  }

  @override
  Future<List<ExpenseTransaction>> bulkSyncTransactions(
    List<ExpenseTransaction> values,
  ) async {
    sent = [...values];
    return deferred == null ? reply : await deferred!.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('Unexpected repository operation');
}

void main() {
  test(
    'bulk sync sends only pending records and preserves existing local history',
    () async {
      final fake = ExpenseRepositoryFake(
        [item('old', synced: true), item('pending')],
        [item('server-new', synced: true)],
      );
      final container = ProviderContainer.test(
        overrides: [expenseTrackerRepositoryProvider.overrideWithValue(fake)],
      );
      container.listen(expenseTransactionsProvider, (_, _) {});
      await container.read(expenseTransactionsProvider.future);
      await container.read(expenseTransactionsProvider.notifier).bulkSync();
      expect(fake.sent.map((row) => row.id), ['pending']);
      expect(fake.local.map((row) => row.id).toSet(), {'old', 'server-new'});
    },
  );
  test('partial sync response cannot replace pending local records', () async {
    final fake = ExpenseRepositoryFake([item('pending')], []);
    final container = ProviderContainer.test(
      overrides: [expenseTrackerRepositoryProvider.overrideWithValue(fake)],
    );
    container.listen(expenseTransactionsProvider, (_, _) {});
    await container.read(expenseTransactionsProvider.future);
    await expectLater(
      container.read(expenseTransactionsProvider.notifier).bulkSync(),
      throwsStateError,
    );
    expect(fake.writes, 0);
    expect(fake.local.single.id, 'pending');
  });
  test(
    'concurrent local mutation is rejected instead of losing updates',
    () async {
      final fake = ExpenseRepositoryFake([item('pending')], [])
        ..deferred = Completer();
      final container = ProviderContainer.test(
        overrides: [expenseTrackerRepositoryProvider.overrideWithValue(fake)],
      );
      container.listen(expenseTransactionsProvider, (_, _) {});
      await container.read(expenseTransactionsProvider.future);
      final controller = container.read(expenseTransactionsProvider.notifier);
      final sync = controller.bulkSync();
      await expectLater(controller.replaceAll([]), throwsStateError);
      fake.deferred!.complete([item('server-new')]);
      await sync;
      expect(fake.local.single.id, 'server-new');
    },
  );
  test(
    'late sync completion cannot publish into a new session generation',
    () async {
      final fake = ExpenseRepositoryFake([item('pending')], [])
        ..deferred = Completer();
      final container = ProviderContainer.test(
        overrides: [expenseTrackerRepositoryProvider.overrideWithValue(fake)],
      );
      container.listen(expenseTransactionsProvider, (_, _) {});
      await container.read(expenseTransactionsProvider.future);
      final sync = container
          .read(expenseTransactionsProvider.notifier)
          .bulkSync();
      container.read(sessionEpochProvider.notifier).advance();
      await container.read(expenseTransactionsProvider.future);
      final rejected = expectLater(sync, throwsStateError);
      fake.deferred!.complete([item('stale-result')]);
      await rejected;
      expect(fake.writes, 0);
      expect(
        container.read(expenseTransactionsProvider).value!.single.id,
        'pending',
      );
    },
  );
}
