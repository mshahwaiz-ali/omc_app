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
      appBar: AppBar(title: const Text('Expense Tracker')),
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
}

class _ExpenseTrackerBody extends StatelessWidget {
  const _ExpenseTrackerBody({
    required this.transactions,
    required this.onDelete,
  });

  final List<ExpenseTransaction> transactions;
  final ValueChanged<String> onDelete;

  @override
  Widget build(BuildContext context) {
    final income = transactions
        .where((item) => item.type == ExpenseTransactionType.income)
        .fold<double>(0, (sum, item) => sum + item.amount);

    final expenses = transactions
        .where((item) => item.type == ExpenseTransactionType.expense)
        .fold<double>(0, (sum, item) => sum + item.amount);

    final balance = income - expenses;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
      children: [
        _SummaryCard(income: income, expenses: expenses, balance: balance),
        const SizedBox(height: 16),
        _CategorySummaryCard(transactions: transactions),
        const SizedBox(height: 16),
        const Text(
          'Recent transactions',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        if (transactions.isEmpty)
          const EmptyState(
            title: 'No transactions yet',
            message:
                'Add income or expenses to start tracking your monthly cashflow.',
            icon: Icons.receipt_long_outlined,
          )
        else
          for (final transaction in transactions)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TransactionTile(
                transaction: transaction,
                onDelete: () => onDelete(transaction.id),
              ),
            ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.income,
    required this.expenses,
    required this.balance,
  });

  final double income;
  final double expenses;
  final double balance;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Cashflow summary',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          _SummaryRow(
            label: 'Income',
            value: income,
            icon: Icons.south_west_rounded,
          ),
          const Divider(height: 24),
          _SummaryRow(
            label: 'Expenses',
            value: expenses,
            icon: Icons.north_east_rounded,
          ),
          const Divider(height: 24),
          _SummaryRow(
            label: 'Balance',
            value: balance,
            icon: Icons.account_balance_wallet_outlined,
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final double value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(
      locale: 'en_PK',
      symbol: 'PKR ',
      decimalDigits: 0,
    );

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
          formatter.format(value),
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w900,
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
        .where((item) => item.type == ExpenseTransactionType.expense)
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

    final formatter = NumberFormat.currency(
      locale: 'en_PK',
      symbol: 'PKR ',
      decimalDigits: 0,
    );

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Expense by category',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          for (final row in rows.take(5))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.key,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    formatter.format(row.value),
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

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction, required this.onDelete});

  final ExpenseTransaction transaction;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(
      locale: 'en_PK',
      symbol: 'PKR ',
      decimalDigits: 0,
    );

    final isIncome = transaction.type == ExpenseTransactionType.income;

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
          Text(
            '${isIncome ? '+' : '-'}${formatter.format(transaction.amount)}',
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
  final _noteController = TextEditingController();

  ExpenseTransactionType _type = ExpenseTransactionType.expense;

  @override
  void dispose() {
    _amountController.dispose();
    _categoryController.dispose();
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
            const Text(
              'Add transaction',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
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
            TextFormField(
              controller: _categoryController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(
                labelText: 'Category',
                hintText: 'Food, fuel, salary, rent...',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Category is required.';
                }
                return null;
              },
            ),
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
      date: DateTime.now(),
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    );

    widget.onSave(transaction);
    Navigator.of(context).pop();
  }
}
