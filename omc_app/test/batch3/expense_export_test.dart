import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/features/expense_tracker/data/expense_export_io.dart';
import 'package:omc_app/features/expense_tracker/data/expense_export_validation.dart';
import 'package:omc_app/features/expense_tracker/data/expense_tracker_repository.dart';
import 'package:omc_app/features/expense_tracker/domain/expense_transaction.dart';

ExpenseTransaction entry(int id, {double amount = 10}) => ExpenseTransaction(
  id: 'E-$id',
  type: ExpenseTransactionType.expense,
  amount: amount,
  category: 'Other',
  date: DateTime(2026, 9, 1),
  synced: true,
);
Map<String, dynamic> summary(int count, {double? expenses}) => {
  'transaction_count': count,
  'income': 0,
  'expenses': expenses ?? count * 10,
};
ExpenseCloudPage page(int start, int count, int total, {bool more = false}) =>
    ExpenseCloudPage(
      List.generate(count, (i) => entry(start + i)),
      more ? start + count : null,
      summary(total),
    );

void main() {
  test('empty account is a valid complete export', () {
    final check = ExpenseExportValidation()..add(page(0, 0, 0));
    expect(check.finish, returnsNormally);
  });
  test('201 records across deterministic pages are complete', () {
    final check = ExpenseExportValidation()
      ..add(page(0, 100, 201, more: true))
      ..add(page(100, 100, 201, more: true))
      ..add(page(200, 1, 201));
    check.finish();
    expect(check.count, 201);
  });
  test('duplicate records cannot conceal a skipped row', () {
    final check = ExpenseExportValidation()..add(page(0, 1, 2, more: true));
    expect(() => check.add(page(0, 1, 2)), throwsStateError);
  });
  test('count-preserving monetary edit is detected', () {
    final check = ExpenseExportValidation()..add(page(0, 1, 2, more: true));
    expect(
      () => check.add(
        ExpenseCloudPage([entry(1)], null, summary(2, expenses: 21)),
      ),
      throwsStateError,
    );
  });
  test('matching count with wrong totals is rejected', () {
    final check = ExpenseExportValidation()
      ..add(ExpenseCloudPage([entry(0, amount: 9)], null, summary(1)));
    expect(check.finish, throwsStateError);
  });
  test('missing terminal page is incomplete', () {
    final check = ExpenseExportValidation()..add(page(0, 1, 2, more: true));
    expect(check.finish, throwsStateError);
  });
  test('invalid numeric totals fail closed', () {
    final check = ExpenseExportValidation();
    expect(
      () => check.add(ExpenseCloudPage([], null, {'transaction_count': 0})),
      throwsFormatException,
    );
  });
  test(
    'complete file is published once and temporary files are removed',
    () async {
      String? exportedPath;
      final progress = <int>[];
      await exportExpensePages(
        Stream.fromIterable([page(0, 2, 2)]),
        isCancelled: () => false,
        onProgress: progress.add,
        publish: (path) async {
          exportedPath = path;
          final rows = jsonDecode(await File(path).readAsString()) as List;
          expect(rows, hasLength(2));
          expect(path.endsWith('expenses.json'), isTrue);
        },
      );
      expect(exportedPath, isNotNull);
      expect(await File(exportedPath!).exists(), isFalse);
      expect(progress, [2]);
    },
  );
  test('failed or duplicated pages publish no backup', () async {
    var published = false;
    await expectLater(
      exportExpensePages(
        Stream.fromIterable([page(0, 1, 2, more: true), page(0, 1, 2)]),
        isCancelled: () => false,
        onProgress: (_) {},
        publish: (_) async {
          published = true;
        },
      ),
      throwsStateError,
    );
    expect(published, isFalse);
  });
  test('cancellation before publishing shares no partial file', () async {
    var cancelled = false;
    var published = false;
    await expectLater(
      exportExpensePages(
        Stream.fromIterable([page(0, 2, 2)]),
        isCancelled: () => cancelled,
        onProgress: (_) {
          cancelled = true;
        },
        publish: (_) async {
          published = true;
        },
      ),
      throwsStateError,
    );
    expect(published, isFalse);
  });
}
