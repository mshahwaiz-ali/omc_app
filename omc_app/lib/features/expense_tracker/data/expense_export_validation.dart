import 'expense_tracker_repository.dart';

/// Detect incomplete/duplicated pages and changing totals. This is NOT a
/// point-in-time snapshot: offset paging cannot prove isolation from edits.
class ExpenseExportValidation {
  int? _expected;
  double? _expectedIncome;
  double? _expectedExpenses;
  double _income = 0;
  double _expenses = 0;
  final _ids = <String>{};
  bool _ended = false;
  int get count => _ids.length;

  double _number(Object? value) {
    final result = value is num ? value.toDouble() : double.tryParse('$value');
    if (result == null || !result.isFinite) {
      throw const FormatException('Missing or invalid account totals.');
    }
    return result;
  }

  bool _equal(double a, double b) => (a - b).abs() <= 0.005 + a.abs() * 1e-12;

  void add(ExpenseCloudPage page) {
    if (_ended) {
      throw StateError('Unexpected page after end of history.');
    }
    final countValue = _number(page.summary['transaction_count']);
    if (countValue < 0 || countValue != countValue.truncateToDouble()) {
      throw const FormatException('Invalid account record count.');
    }
    final expected = countValue.toInt();
    final income = _number(page.summary['income']);
    final expenses = _number(page.summary['expenses']);
    _expected ??= expected;
    _expectedIncome ??= income;
    _expectedExpenses ??= expenses;
    if (expected != _expected ||
        !_equal(income, _expectedIncome!) ||
        !_equal(expenses, _expectedExpenses!)) {
      throw StateError('History changed during export. Please retry.');
    }
    for (final entry in page.entries) {
      if (entry.id.trim().isEmpty ||
          !_ids.add(entry.id) ||
          !entry.amount.isFinite ||
          entry.amount <= 0 ||
          entry.isArchived) {
        throw StateError(
          'Duplicate or invalid expense in export. Please retry.',
        );
      }
      if (entry.isIncome) {
        _income += entry.amount;
      } else {
        _expenses += entry.amount;
      }
    }
    if (count > expected ||
        (page.nextStart != null && page.nextStart != count)) {
      throw StateError('Invalid expense continuation. Please retry.');
    }
    _ended = page.nextStart == null;
  }

  void finish() {
    if (!_ended ||
        _expected == null ||
        count != _expected ||
        !_equal(_income, _expectedIncome!) ||
        !_equal(_expenses, _expectedExpenses!)) {
      throw StateError('Export incomplete or totals changed. Please retry.');
    }
  }
}
