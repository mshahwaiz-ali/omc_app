import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/design_tokens.dart';
import '../../../app/theme.dart';
import '../../../core/diagnostics/omc_widget_keys.dart';
import '../../../core/forms/dirty_form_controller.dart';
import '../../../core/widgets/app_back_header.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_labeled_field.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_empty_state.dart';
import '../../auth/application/auth_controller.dart';
import '../data/expense_tracker_repository.dart';
import '../data/local_expense_budget_store.dart';
import '../domain/expense_transaction.dart';
import 'expense_budget_screen.dart'
    show
        ExpenseBudgetItem,
        expenseBudgetSummaryProvider,
        expenseBudgetsProvider,
        localExpenseBudgetEntriesProvider,
        localExpenseBudgetsProvider;

const _budgetV2RequestTimeout = Duration(seconds: 12);

class ExpenseBudgetV2Screen extends ConsumerStatefulWidget {
  const ExpenseBudgetV2Screen({super.key});

  @override
  ConsumerState<ExpenseBudgetV2Screen> createState() =>
      _ExpenseBudgetV2ScreenState();
}

class _ExpenseBudgetV2ScreenState extends ConsumerState<ExpenseBudgetV2Screen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final capabilities = authState.capabilities;
    final isInternal =
        capabilities.isInternal || capabilities.canAccessInternalWorkspace;
    final canManageBudgets = capabilities.isApproved || isInternal;

    if (!canManageBudgets) {
      return Scaffold(
        key: OmcWidgetKeys.budgetScreen,
        backgroundColor: AppTheme.background,
        appBar: const AppBackHeader(
          title: 'Monthly Budgets',
          fallbackRoute: '/expense-tracker',
        ),
        body: const SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: PremiumEmptyState(
              icon: Icons.lock_outline_rounded,
              title: 'Approved access required',
              message:
                  'Monthly budgets are available for approved customers and OMC admin users only.',
            ),
          ),
        ),
      );
    }

    final budgetsAsync = isInternal
        ? ref.watch(localExpenseBudgetsProvider)
        : ref.watch(expenseBudgetsProvider);
    final entriesAsync = isInternal
        ? ref.watch(localExpenseBudgetEntriesProvider)
        : const AsyncData<List<ExpenseTransaction>>([]);
    final cloudSummary = isInternal
        ? null
        : ref.watch(
            expenseBudgetSummaryProvider(
              DateFormat('yyyy-MM-01').format(_month),
            ),
          );

    return Scaffold(
      key: OmcWidgetKeys.budgetScreen,
      backgroundColor: AppTheme.background,
      appBar: AppBackHeader(
        title: 'Monthly Budgets',
        subtitle: 'Set limits and track category spending',
        fallbackRoute: '/expense-tracker',
        action: PopupMenuButton<String>(
          tooltip: 'Budget actions',
          icon: const Icon(Icons.more_horiz_rounded),
          onSelected: (value) {
            if (value == 'add') _showBudgetSheet(month: _month);
            if (value == 'refresh') _refresh();
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'add', child: Text('Add budget')),
            PopupMenuItem(value: 'refresh', child: Text('Refresh')),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator.adaptive(
          onRefresh: () async => _refresh(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
            children: [
              _MonthSelector(
                month: _month,
                onPrevious: () => setState(
                  () => _month = DateTime(_month.year, _month.month - 1),
                ),
                onNext: () => setState(
                  () => _month = DateTime(_month.year, _month.month + 1),
                ),
              ),
              const SizedBox(height: 12),
              if (isInternal) ...[
                const _StorageContextCard(),
                const SizedBox(height: 12),
              ],
              budgetsAsync.when(
                loading: () => const _BudgetLoadingView(),
                error: (_, _) => PremiumEmptyState(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Budgets unavailable',
                  message: isInternal
                      ? 'Local budget data could not be loaded right now.'
                      : 'Could not load synced budget settings right now.',
                  actionLabel: 'Retry',
                  onAction: _refresh,
                ),
                data: (budgets) {
                  final monthBudgets = budgets
                      .where(
                        (item) =>
                            item.month.year == _month.year &&
                            item.month.month == _month.month &&
                            item.active,
                      )
                      .toList(growable: false);

                  if (!isInternal) {
                    return cloudSummary!.when(
                      loading: () => const _BudgetLoadingView(),
                      error: (_, _) => PremiumEmptyState(
                        icon: Icons.cloud_off_outlined,
                        title: 'Spending unavailable',
                        message: 'Account totals could not be loaded.',
                        actionLabel: 'Retry',
                        onAction: _refresh,
                      ),
                      data: (summary) => _BudgetWorkspace(
                        budgets: monthBudgets,
                        entries: const [],
                        summary: summary,
                        month: _month,
                        onAdd: () => _showBudgetSheet(month: _month),
                        onEdit: (budget) =>
                            _showBudgetSheet(month: _month, budget: budget),
                      ),
                    );
                  }

                  return entriesAsync.when(
                    loading: () => const _BudgetLoadingView(),
                    error: (_, _) => _BudgetWorkspace(
                      budgets: monthBudgets,
                      entries: const [],
                      month: _month,
                      onAdd: () => _showBudgetSheet(month: _month),
                      onEdit: (budget) =>
                          _showBudgetSheet(month: _month, budget: budget),
                    ),
                    data: (entries) => _BudgetWorkspace(
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
    ref.invalidate(localExpenseBudgetsProvider);
    ref.invalidate(expenseBudgetSummaryProvider);
    ref.invalidate(localExpenseBudgetEntriesProvider);
  }

  Future<void> _showBudgetSheet({
    required DateTime month,
    ExpenseBudgetItem? budget,
  }) async {
    final authState = ref.read(authControllerProvider);
    final capabilities = authState.capabilities;
    final useLocalBudgetStore =
        capabilities.isInternal || capabilities.canAccessInternalWorkspace;
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
    final dirtyFormController = DirtyFormController();
    final amountFieldKey = GlobalKey<FormFieldState<String>>();

    void markDirty() => dirtyFormController.markDirty();

    categoryController.addListener(markDirty);
    amountController.addListener(markDirty);
    thresholdController.addListener(markDirty);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        final bottomInset = MediaQuery.viewInsetsOf(sheetContext).bottom;
        return UnsavedChangesGuard(
          controller: dirtyFormController,
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Align(
              alignment: Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: AppLayout.formMaxWidth,
                  maxHeight: 720,
                ),
                child: Material(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.sheet),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          budget == null
                              ? 'Set monthly budget'
                              : 'Update monthly budget',
                          style: Theme.of(sheetContext).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          DateFormat('MMMM yyyy').format(month),
                          style: Theme.of(sheetContext).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 18),
                        AppLabeledField(
                          label: 'Category',
                          child: TextField(
                            controller: categoryController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              hintText: 'Leave blank for overall budget',
                              prefixIcon: Icon(Icons.category_outlined),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        AppLabeledField(
                          label: 'Budget limit',
                          isRequired: true,
                          child: TextFormField(
                            key: amountFieldKey,
                            controller: amountController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              prefixText: 'PKR ',
                              prefixIcon: Icon(
                                Icons.account_balance_wallet_outlined,
                              ),
                            ),
                            validator: (value) {
                              final amount =
                                  double.tryParse(value?.trim() ?? '') ?? 0;
                              return amount <= 0
                                  ? 'Enter a valid budget amount.'
                                  : null;
                            },
                          ),
                        ),
                        const SizedBox(height: 12),
                        AppLabeledField(
                          label: 'Warning threshold',
                          child: TextField(
                            controller: thresholdController,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              suffixText: '%',
                              prefixIcon: Icon(Icons.warning_amber_rounded),
                              helperText:
                                  'The saved threshold remains between 1% and 100%.',
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        AppButton(
                          label: 'Save budget',
                          icon: Icons.check_rounded,
                          onPressed: () async {
                            if (!(amountFieldKey.currentState?.validate() ??
                                false)) {
                              return;
                            }
                            final amount =
                                double.tryParse(amountController.text.trim()) ??
                                0;
                            final threshold =
                                double.tryParse(
                                  thresholdController.text.trim(),
                                ) ??
                                80;

                            final payload = <String, dynamic>{
                              if (budget != null && budget.name.isNotEmpty)
                                'name': budget.name,
                              'category': categoryController.text.trim().isEmpty
                                  ? null
                                  : categoryController.text.trim(),
                              'month': DateFormat('yyyy-MM-dd').format(month),
                              'limit_amount': amount,
                              'alert_threshold': threshold.clamp(1, 100),
                              'active': 1,
                            };

                            dirtyFormController.beginSubmitting();
                            try {
                              if (useLocalBudgetStore) {
                                await LocalExpenseBudgetStore(
                                  authState.userId,
                                ).saveBudget(payload);
                              } else {
                                await ref
                                    .read(expenseTrackerRepositoryProvider)
                                    .saveBudget(payload)
                                    .timeout(_budgetV2RequestTimeout);
                              }

                              dirtyFormController.submissionSucceeded();
                              if (!sheetContext.mounted) return;
                              _refresh();
                              Navigator.of(sheetContext).pop();
                            } catch (_) {
                              dirtyFormController.submissionFailed();
                              if (!sheetContext.mounted) return;
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Budget could not be saved right now. Please try again.',
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    categoryController.removeListener(markDirty);
    amountController.removeListener(markDirty);
    thresholdController.removeListener(markDirty);
    dirtyFormController.dispose();
    categoryController.dispose();
    amountController.dispose();
    thresholdController.dispose();
  }
}

class _MonthSelector extends StatelessWidget {
  const _MonthSelector({
    required this.month,
    required this.onPrevious,
    required this.onNext,
  });

  final DateTime month;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Previous month',
            onPressed: onPrevious,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'Budget month',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 2),
                Text(
                  DateFormat('MMMM yyyy').format(month),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Next month',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _StorageContextCard extends StatelessWidget {
  const _StorageContextCard();

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.phone_iphone_rounded,
            size: 22,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Internal account budgets are stored on this device and use your local expense entries.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetWorkspace extends StatelessWidget {
  const _BudgetWorkspace({
    this.summary,
    required this.budgets,
    required this.entries,
    required this.month,
    required this.onAdd,
    required this.onEdit,
  });

  final Map<String, dynamic>? summary;
  final List<ExpenseBudgetItem> budgets;
  final List<ExpenseTransaction> entries;
  final DateTime month;
  final VoidCallback onAdd;
  final ValueChanged<ExpenseBudgetItem> onEdit;

  @override
  Widget build(BuildContext context) {
    if (budgets.isEmpty) {
      return _NoBudgetState(month: month, onAdd: onAdd);
    }

    final visibleEntries = entries
        .where(
          (item) =>
              item.isExpense &&
              item.date.year == month.year &&
              item.date.month == month.month,
        )
        .toList(growable: false);

    final rows = [
      for (final budget in budgets)
        (budget: budget, spent: _spentForBudget(budget, visibleEntries)),
    ];
    final overall = rows.where((row) {
      final category = row.budget.category.trim().toLowerCase();
      return category.isEmpty || category == 'overall';
    }).firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MonthContext(
          count: budgets.length,
          overallBudget: overall?.budget,
          overallSpent: overall?.spent,
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add budget'),
          ),
        ),
        const SizedBox(height: 22),
        Text('Category budgets', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(
          'Spent, limit and remaining amount stay visible without relying on color.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < rows.length; index++) ...[
          _BudgetCard(
            budget: rows[index].budget,
            spent: rows[index].spent,
            onTap: () => onEdit(rows[index].budget),
          ),
          if (index != rows.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  double _spentForBudget(
    ExpenseBudgetItem budget,
    List<ExpenseTransaction> entries,
  ) {
    final category = budget.category.trim().toLowerCase();
    if (summary != null) {
      if (category.isEmpty || category == 'overall') {
        return (summary!['expenses'] as num?)?.toDouble() ?? 0;
      }
      final totals = summary!['category_totals'] as Map? ?? const {};
      return totals.entries
          .where(
            (entry) => entry.key.toString().trim().toLowerCase() == category,
          )
          .fold<double>(
            0,
            (sum, entry) => sum + (entry.value as num).toDouble(),
          );
    }
    final matching = category.isEmpty || category == 'overall'
        ? entries
        : entries.where(
            (item) => item.category.trim().toLowerCase() == category,
          );
    return matching.fold<double>(0, (sum, item) => sum + item.amount);
  }
}

class _MonthContext extends StatelessWidget {
  const _MonthContext({
    required this.count,
    this.overallBudget,
    this.overallSpent,
  });

  final int count;
  final ExpenseBudgetItem? overallBudget;
  final double? overallSpent;

  @override
  Widget build(BuildContext context) {
    final budget = overallBudget;
    final spent = overallSpent ?? 0;
    final remaining = budget == null ? null : budget.limitAmount - spent;

    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$count active budget${count == 1 ? '' : 's'}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (budget != null) ...[
            const SizedBox(height: 14),
            Text(
              'Overall monthly limit',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 3),
            Text(
              _money(budget.limitAmount),
              style: Theme.of(context).textTheme.amount,
            ),
            const SizedBox(height: 12),
            _KeyValue(label: 'Spent', value: _money(spent)),
            _KeyValue(
              label: remaining! < 0 ? 'Over budget by' : 'Remaining',
              value: _money(remaining.abs()),
              strong: true,
            ),
          ] else ...[
            const SizedBox(height: 6),
            Text(
              'No overall monthly limit is set. Category budgets below remain independent.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
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
    final rawRatio = budget.limitAmount <= 0 ? 0.0 : spent / budget.limitAmount;
    final progress = rawRatio.clamp(0.0, 1.0).toDouble();
    final alertRatio = (budget.alertThreshold / 100)
        .clamp(0.01, 1.0)
        .toDouble();
    final isOverLimit = spent > budget.limitAmount;
    final isNearLimit = !isOverLimit && rawRatio >= alertRatio;
    final remaining = budget.limitAmount - spent;
    final status = isOverLimit
        ? 'Over budget'
        : isNearLimit
        ? 'Near warning threshold'
        : 'Within budget';
    final statusColor = isOverLimit
        ? AppTheme.danger
        : isNearLimit
        ? AppTheme.warning
        : AppTheme.success;
    final progressPercent = (rawRatio * 100).clamp(0, 999).round();
    final category = budget.category.trim();

    return PremiumCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          category.isEmpty ||
                                  category.toLowerCase() == 'overall'
                              ? 'Overall budget'
                              : category,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 5),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isOverLimit
                                  ? Icons.error_outline_rounded
                                  : isNearLimit
                                  ? Icons.warning_amber_rounded
                                  : Icons.check_circle_outline_rounded,
                              size: 18,
                              color: statusColor,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                status,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.edit_outlined,
                    size: 22,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _KeyValue(label: 'Spent', value: _money(spent), strong: true),
              _KeyValue(label: 'Limit', value: _money(budget.limitAmount)),
              _KeyValue(
                label: isOverLimit ? 'Over by' : 'Remaining',
                value: _money(remaining.abs()),
                strong: true,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Progress · $progressPercent%',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    'Warning at ${budget.alertThreshold.toStringAsFixed(0)}%',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Semantics(
                label:
                    '$status. $progressPercent percent of budget used. Warning threshold ${budget.alertThreshold.toStringAsFixed(0)} percent.',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: AppTheme.processingSoft,
                    color: statusColor,
                  ),
                ),
              ),
              if (isOverLimit) ...[
                const SizedBox(height: 10),
                Text(
                  'The progress bar is capped visually, but actual spending is ${_money(remaining.abs())} over the budget limit.',
                  style: const TextStyle(
                    color: AppTheme.danger,
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NoBudgetState extends StatelessWidget {
  const _NoBudgetState({required this.month, required this.onAdd});
  final DateTime month;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return PremiumEmptyState(
      icon: Icons.savings_outlined,
      title: 'No budget set for ${DateFormat('MMMM').format(month)}',
      message: 'Add an overall or category budget for this month.',
      actionLabel: 'Add budget',
      onAction: onAdd,
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style:
                  (strong
                          ? Theme.of(context).textTheme.titleMedium
                          : Theme.of(context).textTheme.bodyLarge)
                      ?.copyWith(fontWeight: strong ? FontWeight.w600 : null),
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetLoadingView extends StatelessWidget {
  const _BudgetLoadingView();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < 3; index++) ...[
          PremiumCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _SkeletonLine(width: 150, height: 18),
                SizedBox(height: 10),
                _SkeletonLine(height: 15),
                SizedBox(height: 10),
                _SkeletonLine(width: 210, height: 13),
              ],
            ),
          ),
          if (index != 2) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({this.width, required this.height});
  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

String _money(double value) {
  return NumberFormat.currency(
    locale: 'en_PK',
    symbol: 'PKR ',
    decimalDigits: 0,
  ).format(value);
}
