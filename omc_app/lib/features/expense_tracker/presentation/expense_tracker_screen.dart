import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/premium_card.dart';
import '../data/expense_tracker_repository.dart';
import '../domain/expense_transaction.dart';

final expenseTransactionsProvider =
    AsyncNotifierProvider<
      ExpenseTransactionsController,
      List<ExpenseTransaction>
    >(ExpenseTransactionsController.new);

class ExpenseTransactionsController
    extends AsyncNotifier<List<ExpenseTransaction>> {
  late final ExpenseTrackerRepository _repository;

  @override
  Future<List<ExpenseTransaction>> build() async {
    _repository = ref.read(expenseTrackerRepositoryProvider);
    final transactions = await _repository.readTransactions();
    return _sort(transactions);
  }

  Future<void> reload() async {
    state = const AsyncLoading();

    try {
      final transactions = await _repository.readTransactions();
      state = AsyncData(_sort(transactions));
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> add(ExpenseTransaction transaction) async {
    final current = state.value ?? const <ExpenseTransaction>[];
    final next = _sort([transaction, ...current]);

    state = AsyncData(next);

    try {
      await _repository.saveTransactions(next);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> replaceAll(List<ExpenseTransaction> transactions) async {
    final next = _sort(transactions);

    state = AsyncData(next);

    try {
      await _repository.saveTransactions(next);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> remove(String id) async {
    final current = state.value ?? const <ExpenseTransaction>[];
    final next = current.where((item) => item.id != id).toList(growable: false);

    state = AsyncData(next);

    try {
      await _repository.saveTransactions(next);
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> clearAll() async {
    state = const AsyncData([]);

    try {
      await _repository.clearTransactions();
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  List<ExpenseTransaction> _sort(List<ExpenseTransaction> transactions) {
    final sorted = [...transactions];
    sorted.sort((a, b) => b.date.compareTo(a.date));
    return sorted;
  }
}

class ExpenseTrackerScreen extends ConsumerWidget {
  const ExpenseTrackerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactionsAsync = ref.watch(expenseTransactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Tracker'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () =>
                ref.read(expenseTransactionsProvider.notifier).reload(),
            icon: const Icon(Icons.refresh_rounded),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'export') {
                _showExportDialog(context, transactionsAsync.value ?? const []);
              }

              if (value == 'import') {
                _showImportDialog(context, ref);
              }

              if (value == 'clear') {
                _confirmClearAll(context, ref);
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'export', child: Text('Export backup JSON')),
              PopupMenuItem(value: 'import', child: Text('Import backup JSON')),
              PopupMenuItem(value: 'clear', child: Text('Clear local data')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTransactionSheet(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
      ),
      body: SafeArea(
        top: false,
        child: transactionsAsync.when(
          loading: () => const LoadingView(message: 'Loading tracker...'),
          error: (_, _) => EmptyState(
            title: 'Tracker unavailable',
            message: 'Local expense data could not be loaded.',
            icon: Icons.account_balance_wallet_outlined,
            actionLabel: 'Retry',
            onAction: () =>
                ref.read(expenseTransactionsProvider.notifier).reload(),
          ),
          data: (transactions) => _ExpenseTrackerBody(
            transactions: transactions,
            onDelete: (id) => _confirmDeleteTransaction(context, ref, id),
          ),
        ),
      ),
    );
  }

  void _showExportDialog(
    BuildContext context,
    List<ExpenseTransaction> transactions,
  ) {
    final encoded = const JsonEncoder.withIndent(
      '  ',
    ).convert(transactions.map((transaction) => transaction.toJson()).toList());

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Backup JSON'),
        content: SingleChildScrollView(
          child: SelectableText(encoded, style: const TextStyle(fontSize: 12)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showImportDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Import backup JSON'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            minLines: 8,
            maxLines: 12,
            decoration: const InputDecoration(
              hintText: 'Paste exported JSON here...',
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              try {
                final decoded = jsonDecode(controller.text.trim());
                if (decoded is! List) {
                  throw const FormatException('Backup must be a JSON list.');
                }

                final transactions = decoded
                    .whereType<Map>()
                    .map(
                      (item) => ExpenseTransaction.fromJson(
                        Map<String, dynamic>.from(item),
                      ),
                    )
                    .where((item) => item.id.isNotEmpty && item.amount > 0)
                    .toList(growable: false);

                ref
                    .read(expenseTransactionsProvider.notifier)
                    .replaceAll(transactions);

                Navigator.of(dialogContext).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Imported ${transactions.length} transactions.',
                    ),
                  ),
                );
              } catch (_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Invalid backup JSON. Please check format.'),
                  ),
                );
              }
            },
            child: const Text('Import'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  void _showAddTransactionSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AddTransactionSheet(
        onSave: (transaction) {
          ref.read(expenseTransactionsProvider.notifier).add(transaction);
        },
      ),
    );
  }

  Future<void> _confirmDeleteTransaction(
    BuildContext context,
    WidgetRef ref,
    String id,
  ) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete transaction?'),
        content: const Text(
          'This transaction will be removed from the local tracker.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    ref.read(expenseTransactionsProvider.notifier).remove(id);
  }

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear tracker?'),
        content: const Text(
          'All local expense tracker transactions will be removed from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (shouldClear != true) return;

    ref.read(expenseTransactionsProvider.notifier).clearAll();
  }
}

class _ExpenseTrackerBody extends StatefulWidget {
  const _ExpenseTrackerBody({
    required this.transactions,
    required this.onDelete,
  });

  final List<ExpenseTransaction> transactions;
  final ValueChanged<String> onDelete;

  @override
  State<_ExpenseTrackerBody> createState() => _ExpenseTrackerBodyState();
}

class _ExpenseTrackerBodyState extends State<_ExpenseTrackerBody> {
  _TrackerFilter _filter = _TrackerFilter.thisMonth;

  @override
  Widget build(BuildContext context) {
    final filteredTransactions = _filterTransactions(widget.transactions);
    final allStats = _TrackerStats.fromTransactions(widget.transactions);
    final filteredStats = _TrackerStats.fromTransactions(filteredTransactions);

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 128),
      children: [
        _HeroSummaryCard(stats: allStats),
        const SizedBox(height: 16),
        _FilterChips(
          selected: _filter,
          onChanged: (filter) => setState(() => _filter = filter),
        ),
        const SizedBox(height: 16),
        _MonthSummaryCard(title: _filter.label, stats: filteredStats),
        const SizedBox(height: 16),
        _AccountSummaryCard(transactions: filteredTransactions),
        const SizedBox(height: 16),
        _MonthlyReportCard(transactions: widget.transactions),
        const SizedBox(height: 16),
        _CategorySummaryCard(transactions: filteredTransactions),
        const SizedBox(height: 16),
        const _TrackerSectionHeader(
          title: 'Transactions',
          subtitle:
              'Recent income and expense activity for the selected period.',
          icon: Icons.receipt_long_outlined,
        ),
        const SizedBox(height: 12),
        if (widget.transactions.isEmpty)
          const EmptyState(
            title: 'No transactions yet',
            message:
                'Add income or expenses to start tracking your monthly cashflow.',
            icon: Icons.receipt_long_outlined,
          )
        else if (filteredTransactions.isEmpty)
          EmptyState(
            title: 'No ${_filter.label.toLowerCase()} transactions',
            message: 'Try another period or add a transaction for this range.',
            icon: Icons.filter_alt_off_outlined,
          )
        else
          for (final transaction in filteredTransactions.take(25))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TransactionTile(
                transaction: transaction,
                onDelete: () => widget.onDelete(transaction.id),
              ),
            ),
      ],
    );
  }

  List<ExpenseTransaction> _filterTransactions(
    List<ExpenseTransaction> transactions,
  ) {
    final now = DateTime.now();

    return transactions
        .where((item) {
          if (_filter == _TrackerFilter.all) return true;

          if (_filter == _TrackerFilter.thisMonth) {
            return item.date.year == now.year && item.date.month == now.month;
          }

          final lastMonth = DateTime(now.year, now.month - 1);
          return item.date.year == lastMonth.year &&
              item.date.month == lastMonth.month;
        })
        .toList(growable: false);
  }
}

enum _TrackerFilter {
  thisMonth('This month'),
  lastMonth('Last month'),
  all('All');

  const _TrackerFilter(this.label);

  final String label;
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onChanged});

  final _TrackerFilter selected;
  final ValueChanged<_TrackerFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_TrackerFilter>(
      segments: _TrackerFilter.values
          .map(
            (filter) => ButtonSegment<_TrackerFilter>(
              value: filter,
              label: Text(filter.label),
            ),
          )
          .toList(growable: false),
      selected: {selected},
      onSelectionChanged: (selection) => onChanged(selection.first),
    );
  }
}

class _TrackerStats {
  const _TrackerStats({
    required this.income,
    required this.expenses,
    required this.transactionCount,
  });

  final double income;
  final double expenses;
  final int transactionCount;

  double get balance => income - expenses;

  factory _TrackerStats.fromTransactions(
    List<ExpenseTransaction> transactions,
  ) {
    final income = transactions
        .where((item) => item.isIncome)
        .fold<double>(0, (sum, item) => sum + item.amount);

    final expenses = transactions
        .where((item) => item.isExpense)
        .fold<double>(0, (sum, item) => sum + item.amount);

    return _TrackerStats(
      income: income,
      expenses: expenses,
      transactionCount: transactions.length,
    );
  }
}

class _HeroSummaryCard extends StatelessWidget {
  const _HeroSummaryCard({required this.stats});

  final _TrackerStats stats;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current balance',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _money(stats.balance),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Income',
                  value: _money(stats.income),
                  icon: Icons.south_west_rounded,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniStat(
                  label: 'Expenses',
                  value: _money(stats.expenses),
                  icon: Icons.north_east_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MonthSummaryCard extends StatelessWidget {
  const _MonthSummaryCard({required this.title, required this.stats});

  final String title;
  final _TrackerStats stats;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          _SummaryRow(
            label: 'Monthly income',
            value: stats.income,
            icon: Icons.trending_up_rounded,
          ),
          const Divider(height: 24),
          _SummaryRow(
            label: 'Monthly expenses',
            value: stats.expenses,
            icon: Icons.trending_down_rounded,
          ),
          const Divider(height: 24),
          _SummaryRow(
            label: 'Transactions',
            valueLabel: '${stats.transactionCount}',
            icon: Icons.receipt_long_outlined,
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryRed.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryRed),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.icon,
    this.value,
    this.valueLabel,
  });

  final String label;
  final double? value;
  final String? valueLabel;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryRed),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          valueLabel ?? _money(value ?? 0),
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _TrackerSectionHeader extends StatelessWidget {
  const _TrackerSectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppTheme.primaryRed.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AppTheme.primaryRed, size: 20),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountSummaryCard extends StatelessWidget {
  const _AccountSummaryCard({required this.transactions});

  final List<ExpenseTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const SizedBox.shrink();
    }

    final balances = <String, double>{};

    for (final transaction in transactions) {
      final signedAmount = transaction.isIncome
          ? transaction.amount
          : -transaction.amount;

      balances.update(
        transaction.account,
        (value) => value + signedAmount,
        ifAbsent: () => signedAmount,
      );
    }

    final rows = balances.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _TrackerSectionHeader(
            title: 'Account balances',
            subtitle: 'Net balance grouped by account.',
            icon: Icons.account_balance_wallet_outlined,
          ),
          const SizedBox(height: 12),
          for (final row in rows.take(6))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: AppTheme.primaryRed.withValues(
                      alpha: 0.08,
                    ),
                    child: const Icon(
                      Icons.account_balance_wallet_outlined,
                      color: AppTheme.primaryRed,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      row.key,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    _money(row.value),
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthlyReportCard extends StatelessWidget {
  const _MonthlyReportCard({required this.transactions});

  final List<ExpenseTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const SizedBox.shrink();
    }

    final rows = _buildRows(transactions);
    if (rows.isEmpty) {
      return const SizedBox.shrink();
    }

    final maxAmount = rows
        .map((row) => row.income > row.expenses ? row.income : row.expenses)
        .fold<double>(0, (max, value) => value > max ? value : max);

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _TrackerSectionHeader(
            title: 'Monthly report',
            subtitle: 'Income versus expenses by month.',
            icon: Icons.bar_chart_rounded,
          ),
          const SizedBox(height: 12),
          for (final row in rows.take(6))
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _MonthlyReportRow(
                row: row,
                maxAmount: maxAmount <= 0 ? 1 : maxAmount,
              ),
            ),
        ],
      ),
    );
  }

  List<_MonthlyReportRowData> _buildRows(
    List<ExpenseTransaction> transactions,
  ) {
    final buckets = <String, _MutableMonthlyTotals>{};

    for (final transaction in transactions) {
      final key =
          '${transaction.date.year}-${transaction.date.month.toString().padLeft(2, '0')}';

      final bucket = buckets.putIfAbsent(
        key,
        () => _MutableMonthlyTotals(
          year: transaction.date.year,
          month: transaction.date.month,
        ),
      );

      if (transaction.isIncome) {
        bucket.income += transaction.amount;
      } else {
        bucket.expenses += transaction.amount;
      }
    }

    final rows = buckets.values
        .map(
          (bucket) => _MonthlyReportRowData(
            year: bucket.year,
            month: bucket.month,
            label: DateFormat(
              'MMM yyyy',
            ).format(DateTime(bucket.year, bucket.month)),
            income: bucket.income,
            expenses: bucket.expenses,
          ),
        )
        .toList(growable: false);

    rows.sort((a, b) => b.sortKey.compareTo(a.sortKey));
    return rows;
  }
}

class _MutableMonthlyTotals {
  _MutableMonthlyTotals({required this.year, required this.month});

  final int year;
  final int month;
  double income = 0;
  double expenses = 0;
}

class _MonthlyReportRowData {
  const _MonthlyReportRowData({
    required this.year,
    required this.month,
    required this.label,
    required this.income,
    required this.expenses,
  });

  final int year;
  final int month;
  final String label;
  final double income;
  final double expenses;

  int get sortKey => year * 100 + month;
}

class _MonthlyReportRow extends StatelessWidget {
  const _MonthlyReportRow({required this.row, required this.maxAmount});

  final _MonthlyReportRowData row;
  final double maxAmount;

  @override
  Widget build(BuildContext context) {
    final incomeRatio = (row.income / maxAmount).clamp(0.0, 1.0);
    final expenseRatio = (row.expenses / maxAmount).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          row.label,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        _ReportBar(label: 'Income', value: row.income, ratio: incomeRatio),
        const SizedBox(height: 8),
        _ReportBar(label: 'Expenses', value: row.expenses, ratio: expenseRatio),
      ],
    );
  }
}

class _ReportBar extends StatelessWidget {
  const _ReportBar({
    required this.label,
    required this.value,
    required this.ratio,
  });

  final String label;
  final double value;
  final double ratio;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 6,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 92,
          child: Text(
            _money(value),
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _CategorySummaryCard extends StatelessWidget {
  const _CategorySummaryCard({required this.transactions});

  final List<ExpenseTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    final expenses = transactions
        .where((item) => item.isExpense)
        .toList(growable: false);

    if (expenses.isEmpty) {
      return const SizedBox.shrink();
    }

    final totals = <String, double>{};
    for (final transaction in expenses) {
      totals.update(
        transaction.category,
        (value) => value + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
    }

    final rows = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final totalExpense = expenses.fold<double>(
      0,
      (sum, item) => sum + item.amount,
    );

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _TrackerSectionHeader(
            title: 'Top expense categories',
            subtitle: 'Highest spending categories in this period.',
            icon: Icons.donut_large_rounded,
          ),
          const SizedBox(height: 12),
          for (final row in rows.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CategoryRow(
                label: row.key,
                amount: row.value,
                percentage: totalExpense <= 0 ? 0 : row.value / totalExpense,
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.label,
    required this.amount,
    required this.percentage,
  });

  final String label;
  final double amount;
  final double percentage;

  @override
  Widget build(BuildContext context) {
    final percentLabel = '${(percentage * 100).round()}%';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '${_money(amount)} · $percentLabel',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: percentage.clamp(0, 1),
          minHeight: 6,
          borderRadius: BorderRadius.circular(999),
        ),
      ],
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction, required this.onDelete});

  final ExpenseTransaction transaction;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.isIncome;

    return PremiumCard(
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.primaryRed.withValues(alpha: 0.08),
            child: Icon(
              isIncome ? Icons.south_west_rounded : Icons.north_east_rounded,
              color: AppTheme.primaryRed,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.category,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${transaction.account} · ${transaction.paymentMethod}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd MMM yyyy').format(transaction.date),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if ((transaction.note ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    transaction.note!.trim(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isIncome ? '+' : '-'}${_money(transaction.amount)}',
                style: TextStyle(
                  color: isIncome ? Colors.green.shade700 : Colors.red.shade700,
                  fontWeight: FontWeight.w900,
                ),
              ),
              IconButton(
                tooltip: 'Delete',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DatePickerTile extends StatelessWidget {
  const _DatePickerTile({required this.date, required this.onTap});

  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Date',
          prefixIcon: Icon(Icons.calendar_month_outlined),
        ),
        child: Text(
          DateFormat('dd MMM yyyy').format(date),
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _QuickChips extends StatelessWidget {
  const _QuickChips({required this.values, required this.onSelected});

  final List<String> values;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: values
          .map(
            (value) => ActionChip(
              label: Text(value),
              onPressed: () => onSelected(value),
              side: BorderSide(
                color: AppTheme.primaryRed.withValues(alpha: 0.18),
              ),
              backgroundColor: AppTheme.primaryRed.withValues(alpha: 0.05),
              labelStyle: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _AddTransactionSheet extends StatefulWidget {
  const _AddTransactionSheet({required this.onSave});

  final ValueChanged<ExpenseTransaction> onSave;

  @override
  State<_AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends State<_AddTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _categoryController = TextEditingController();
  final _accountController = TextEditingController(text: 'Cash');
  final _paymentMethodController = TextEditingController(text: 'Cash');
  final _noteController = TextEditingController();

  ExpenseTransactionType _type = ExpenseTransactionType.expense;
  DateTime _selectedDate = DateTime.now();

  @override
  void dispose() {
    _amountController.dispose();
    _categoryController.dispose();
    _accountController.dispose();
    _paymentMethodController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 20),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryRed.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.add_card_rounded,
                    color: AppTheme.primaryRed,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Add transaction',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SegmentedButton<ExpenseTransactionType>(
              segments: const [
                ButtonSegment(
                  value: ExpenseTransactionType.expense,
                  label: Text('Expense'),
                  icon: Icon(Icons.north_east_rounded),
                ),
                ButtonSegment(
                  value: ExpenseTransactionType.income,
                  label: Text('Income'),
                  icon: Icon(Icons.south_west_rounded),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (selection) {
                setState(() => _type = selection.first);
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixIcon: Icon(Icons.payments_outlined),
              ),
              validator: (value) {
                final amount = double.tryParse(
                  value?.replaceAll(',', '').trim() ?? '',
                );
                if (amount == null || amount <= 0) {
                  return 'Enter a valid amount.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            _QuickChips(
              values: _type == ExpenseTransactionType.income
                  ? const ['Salary', 'Bonus', 'Refund', 'Business']
                  : const ['Food', 'Fuel', 'Rent', 'Bills', 'Shopping'],
              onSelected: (value) => _categoryController.text = value,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _categoryController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: _type == ExpenseTransactionType.income
                    ? 'Income category'
                    : 'Expense category',
                hintText: _type == ExpenseTransactionType.income
                    ? 'Salary, bonus, refund...'
                    : 'Food, fuel, rent, bills...',
                prefixIcon: const Icon(Icons.category_outlined),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Category is required.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            _QuickChips(
              values: const ['Cash', 'Bank', 'Easypaisa', 'JazzCash'],
              onSelected: (value) => _accountController.text = value,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _accountController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Account',
                hintText: 'Cash, Bank, Easypaisa...',
                prefixIcon: Icon(Icons.account_balance_wallet_outlined),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Account is required.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            _QuickChips(
              values: const ['Cash', 'Card', 'Bank Transfer', 'Wallet'],
              onSelected: (value) => _paymentMethodController.text = value,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _paymentMethodController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Payment method',
                hintText: 'Cash, card, bank transfer...',
                prefixIcon: Icon(Icons.credit_card_rounded),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Payment method is required.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            _DatePickerTile(date: _selectedDate, onTap: _pickDate),
            const SizedBox(height: 14),
            TextFormField(
              controller: _noteController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Note optional',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
            ),
            const SizedBox(height: 18),
            AppButton(
              label: 'Save transaction',
              icon: Icons.check_rounded,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime.now(),
    );

    if (pickedDate == null) return;

    setState(() {
      _selectedDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        DateTime.now().hour,
        DateTime.now().minute,
      );
    });
  }

  void _save() {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    final transaction = ExpenseTransaction(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      type: _type,
      amount: double.parse(_amountController.text.replaceAll(',', '').trim()),
      category: _categoryController.text.trim(),
      account: _accountController.text.trim(),
      paymentMethod: _paymentMethodController.text.trim(),
      date: _selectedDate,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    );

    widget.onSave(transaction);
    Navigator.of(context).pop();
  }
}

String _money(double value) {
  return NumberFormat.currency(
    locale: 'en_PK',
    symbol: 'PKR ',
    decimalDigits: 0,
  ).format(value);
}
