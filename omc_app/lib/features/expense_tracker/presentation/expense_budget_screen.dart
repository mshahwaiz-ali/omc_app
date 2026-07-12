import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/premium_empty_state.dart';
import '../../auth/application/auth_controller.dart';
import '../data/expense_tracker_repository.dart';
import '../domain/expense_transaction.dart';

final expenseBudgetsProvider = FutureProvider<List<ExpenseBudgetItem>>((
  ref,
) async {
  final repository = ref.watch(expenseTrackerRepositoryProvider);
  final rows = await repository.fetchBudgets();
  return rows.map(ExpenseBudgetItem.fromJson).toList(growable: false);
});

final expenseBudgetEntriesProvider = FutureProvider<List<ExpenseTransaction>>((
  ref,
) async {
  final repository = ref.watch(expenseTrackerRepositoryProvider);
  return repository.fetchSyncedTransactions();
});

class ExpenseBudgetItem {
  const ExpenseBudgetItem({
    required this.name,
    required this.category,
    required this.month,
    required this.limitAmount,
    required this.alertThreshold,
    required this.active,
  });

  final String name;
  final String category;
  final DateTime month;
  final double limitAmount;
  final double alertThreshold;
  final bool active;

  factory ExpenseBudgetItem.fromJson(Map<String, dynamic> json) {
    return ExpenseBudgetItem(
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? 'Overall',
      month:
          DateTime.tryParse(json['month']?.toString() ?? '') ?? DateTime.now(),
      limitAmount: double.tryParse(json['limit_amount']?.toString() ?? '') ?? 0,
      alertThreshold:
          double.tryParse(json['alert_threshold']?.toString() ?? '') ?? 80,
      active: _boolValue(json['active'], true),
    );
  }
}

class ExpenseBudgetScreen extends ConsumerStatefulWidget {
  const ExpenseBudgetScreen({super.key});

  @override
  ConsumerState<ExpenseBudgetScreen> createState() =>
      _ExpenseBudgetScreenState();
}

class _ExpenseBudgetScreenState extends ConsumerState<ExpenseBudgetScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final capabilities = ref.watch(authControllerProvider).capabilities;
    final canManageBudgets =
        capabilities.isApproved ||
        capabilities.canAccessInternalWorkspace ||
        capabilities.isInternal;

    if (!canManageBudgets) {
      return Scaffold(
        appBar: AppBar(title: const Text('Monthly Budgets')),
        body: const SafeArea(
          child: PremiumEmptyState(
            icon: Icons.lock_outline_rounded,
            title: 'Approved access required',
            message:
                'Monthly budgets are available for approved customers and OMC admin users only.',
          ),
        ),
      );
    }

    final budgetsAsync = ref.watch(expenseBudgetsProvider);
    final entriesAsync = ref.watch(expenseBudgetEntriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Monthly Budgets'),
        actions: [
          IconButton(
            tooltip: 'Add budget',
            onPressed: () => _showBudgetSheet(month: _month),
            icon: const Icon(Icons.add_rounded),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showBudgetSheet(month: _month),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Set budget'),
      ),
      body: SafeArea(
        child: RefreshIndicator.adaptive(
          onRefresh: () async => _refresh(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 128),
            children: [
              _BudgetMonthHeader(
                month: _month,
                onPrevious: () => setState(
                  () => _month = DateTime(_month.year, _month.month - 1),
                ),
                onNext: () => setState(
                  () => _month = DateTime(_month.year, _month.month + 1),
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: () => _showBudgetSheet(month: _month),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add budget'),
                ),
              ),
              const SizedBox(height: 14),
              budgetsAsync.when(
                loading: () => const _BudgetLoadingCard(),
                error: (_, _) => const PremiumEmptyState(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Budgets unavailable',
                  message: 'Could not load synced budget settings right now.',
                ),
                data: (budgets) {
                  final monthBudgets = budgets
                      .where((item) {
                        return item.month.year == _month.year &&
                            item.month.month == _month.month;
                      })
                      .toList(growable: false);

                  return entriesAsync.when(
                    loading: () => const _BudgetLoadingCard(),
                    error: (_, _) => _BudgetList(
                      budgets: monthBudgets,
                      entries: const [],
                      month: _month,
                      onAdd: () => _showBudgetSheet(month: _month),
                      onEdit: (budget) =>
                          _showBudgetSheet(month: _month, budget: budget),
                    ),
                    data: (entries) => _BudgetList(
                      budgets: monthBudgets,
                      entries: entries,
                      month: _month,
                      onAdd: () => _showBudgetSheet(month: _month),
                      onEdit: (budget) =>
                          _showBudgetSheet(month: _month, budget: budget),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _refresh() {
    ref.invalidate(expenseBudgetsProvider);
    ref.invalidate(expenseBudgetEntriesProvider);
  }

  Future<void> _showBudgetSheet({
    required DateTime month,
    ExpenseBudgetItem? budget,
  }) async {
    final categoryController = TextEditingController(
      text: budget?.category == 'Overall' ? '' : budget?.category ?? '',
    );
    final amountController = TextEditingController(
      text: budget == null || budget.limitAmount <= 0
          ? ''
          : budget.limitAmount.toStringAsFixed(0),
    );
    final thresholdController = TextEditingController(
      text: (budget?.alertThreshold ?? 80).toStringAsFixed(0),
    );

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        final bottomInset = MediaQuery.viewInsetsOf(sheetContext).bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                budget == null ? 'Set monthly budget' : 'Update monthly budget',
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                'Leave category blank for an overall monthly budget.',
                style: Theme.of(
                  sheetContext,
                ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: categoryController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  hintText: 'Example: Fuel, Food, Business',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Budget limit',
                  prefixText: 'PKR ',
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: thresholdController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Warning threshold',
                  suffixText: '%',
                  prefixIcon: Icon(Icons.warning_amber_rounded),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    final amount =
                        double.tryParse(amountController.text.trim()) ?? 0;
                    final threshold =
                        double.tryParse(thresholdController.text.trim()) ?? 80;
                    if (amount <= 0) {
                      ScaffoldMessenger.of(sheetContext).showSnackBar(
                        const SnackBar(
                          content: Text('Enter a valid budget amount.'),
                        ),
                      );
                      return;
                    }

                    await ref
                        .read(expenseTrackerRepositoryProvider)
                        .saveBudget({
                          if (budget != null && budget.name.isNotEmpty)
                            'name': budget.name,
                          'category': categoryController.text.trim().isEmpty
                              ? null
                              : categoryController.text.trim(),
                          'month': DateFormat('yyyy-MM-dd').format(month),
                          'limit_amount': amount,
                          'alert_threshold': threshold.clamp(1, 100),
                          'active': 1,
                        });

                    if (!sheetContext.mounted) return;
                    _refresh();
                    Navigator.of(sheetContext).pop();
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Save budget'),
                ),
              ),
            ],
          ),
        );
      },
    );

    categoryController.dispose();
    amountController.dispose();
    thresholdController.dispose();
  }
}

class _BudgetMonthHeader extends StatelessWidget {
  const _BudgetMonthHeader({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton.filledTonal(
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Column(
              children: [
                const Text(
                  'Budget month',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMMM yyyy').format(month),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          IconButton.filledTonal(
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _BudgetList extends StatelessWidget {
  const _BudgetList({
    required this.budgets,
    required this.entries,
    required this.month,
    required this.onAdd,
    required this.onEdit,
  });

  final List<ExpenseBudgetItem> budgets;
  final List<ExpenseTransaction> entries;
  final DateTime month;
  final VoidCallback onAdd;
  final ValueChanged<ExpenseBudgetItem> onEdit;

  @override
  Widget build(BuildContext context) {
    if (budgets.isEmpty) {
      return _NoBudgetState(onAdd: onAdd);
    }

    final visibleEntries = entries
        .where((item) {
          return item.isExpense &&
              item.date.year == month.year &&
              item.date.month == month.month;
        })
        .toList(growable: false);

    return Column(
      children: [
        for (final budget in budgets.where((item) => item.active))
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _BudgetCard(
              budget: budget,
              spent: _spentForBudget(budget, visibleEntries),
              onTap: () => onEdit(budget),
            ),
          ),
      ],
    );
  }

  double _spentForBudget(
    ExpenseBudgetItem budget,
    List<ExpenseTransaction> entries,
  ) {
    final category = budget.category.trim().toLowerCase();
    final matching = category.isEmpty || category == 'overall'
        ? entries
        : entries.where(
            (item) => item.category.trim().toLowerCase() == category,
          );
    return matching.fold<double>(0, (sum, item) => sum + item.amount);
  }
}

class _NoBudgetState extends StatelessWidget {
  const _NoBudgetState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 24, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(
            Icons.savings_outlined,
            size: 34,
            color: AppTheme.primary.withValues(alpha: 0.9),
          ),
          const SizedBox(height: 10),
          Text(
            'No budget set yet',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add an overall or category budget to track spending against your monthly limit.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add budget'),
          ),
        ],
      ),
    );
  }
}

class _BudgetCard extends StatelessWidget {
  const _BudgetCard({
    required this.budget,
    required this.spent,
    required this.onTap,
  });

  final ExpenseBudgetItem budget;
  final double spent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(symbol: 'PKR ', decimalDigits: 0);
    final rawRatio = budget.limitAmount <= 0 ? 0.0 : spent / budget.limitAmount;
    final ratio = rawRatio.clamp(0.0, 1.25).toDouble();
    final alertRatio = (budget.alertThreshold / 100)
        .clamp(0.01, 1.0)
        .toDouble();
    final isOverLimit = spent > budget.limitAmount;
    final isNearLimit = !isOverLimit && ratio >= alertRatio;
    final remaining = budget.limitAmount - spent;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: (isOverLimit || isNearLimit)
                ? AppTheme.primary.withValues(alpha: 0.26)
                : Colors.black.withValues(alpha: 0.05),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isOverLimit
                        ? Icons.error_outline_rounded
                        : Icons.savings_outlined,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        budget.category.trim().isEmpty
                            ? 'Overall budget'
                            : budget.category,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${formatter.format(spent)} spent of ${formatter.format(budget.limitAmount)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.edit_outlined,
                  size: 18,
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: ratio.clamp(0.0, 1.0).toDouble(),
                minHeight: 9,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              isOverLimit
                  ? 'Over budget by ${formatter.format(remaining.abs())}'
                  : isNearLimit
                  ? 'Warning: ${budget.alertThreshold.toStringAsFixed(0)}% threshold reached'
                  : '${formatter.format(remaining)} remaining',
              style: TextStyle(
                color: (isOverLimit || isNearLimit)
                    ? AppTheme.primary
                    : AppTheme.textSecondary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetLoadingCard extends StatelessWidget {
  const _BudgetLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const CircularProgressIndicator.adaptive(),
    );
  }
}

bool _boolValue(dynamic value, bool fallback) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().trim().toLowerCase();
  if (text == 'true' || text == '1' || text == 'yes' || text == 'on') {
    return true;
  }
  if (text == 'false' || text == '0' || text == 'no' || text == 'off') {
    return false;
  }
  return fallback;
}
