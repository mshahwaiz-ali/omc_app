import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_empty_state.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../profile/data/profile_repository.dart';
import '../data/expense_tracker_repository.dart';
import '../domain/expense_transaction.dart';

final expenseTrackerConfigProvider = FutureProvider<ExpenseTrackerConfig>((ref) {
  return ref.watch(expenseTrackerRepositoryProvider).fetchConfig();
});

final expenseTransactionsProvider =
    AsyncNotifierProvider<ExpenseTransactionsController, List<ExpenseTransaction>>(
  ExpenseTransactionsController.new,
);

class ExpenseTransactionsController extends AsyncNotifier<List<ExpenseTransaction>> {
  late final ExpenseTrackerRepository _repository;

  @override
  Future<List<ExpenseTransaction>> build() async {
    _repository = ref.read(expenseTrackerRepositoryProvider);
    return _sort(await _repository.readTransactions());
  }

  Future<void> reloadLocal() async {
    state = const AsyncLoading();
    try {
      state = AsyncData(_sort(await _repository.readTransactions()));
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> loadSynced() async {
    state = const AsyncLoading();
    try {
      final remote = await _repository.fetchSyncedTransactions();
      await _repository.saveTransactions(remote);
      state = AsyncData(_sort(remote));
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> add(ExpenseTransaction transaction, {required bool sync}) async {
    final current = state.value ?? const <ExpenseTransaction>[];
    var nextTransaction = transaction;

    if (sync) {
      final synced = await _repository.createSyncedTransaction(transaction);
      if (synced != null) nextTransaction = synced.copyWith(synced: true);
    }

    final next = _sort([nextTransaction, ...current]);
    state = AsyncData(next);
    await _repository.saveTransactions(next);
  }

  Future<void> update(ExpenseTransaction transaction, {required bool sync}) async {
    final current = state.value ?? const <ExpenseTransaction>[];
    var nextTransaction = transaction;

    if (sync) {
      final synced = await _repository.updateSyncedTransaction(transaction);
      if (synced != null) nextTransaction = synced.copyWith(synced: true);
    }

    final next = _sort(
      current
          .map((item) => item.id == transaction.id ? nextTransaction : item)
          .toList(growable: false),
    );
    state = AsyncData(next);
    await _repository.saveTransactions(next);
  }

  Future<void> bulkSync() async {
    final current = state.value ?? const <ExpenseTransaction>[];
    if (current.isEmpty) return;

    state = const AsyncLoading();
    try {
      final synced = await _repository.bulkSyncTransactions(current);
      await _repository.saveTransactions(synced);
      state = AsyncData(_sort(synced));
    } catch (error, stackTrace) {
      state = AsyncError(error, stackTrace);
    }
  }

  Future<void> remove(String id, {required bool sync}) async {
    final current = state.value ?? const <ExpenseTransaction>[];
    final next = current.where((item) => item.id != id).toList(growable: false);

    if (sync) await _repository.deleteSyncedTransaction(id);

    state = AsyncData(next);
    await _repository.saveTransactions(next);
  }

  Future<void> replaceAll(List<ExpenseTransaction> transactions) async {
    final next = _sort(transactions);
    state = AsyncData(next);
    await _repository.saveTransactions(next);
  }

  Future<void> clearAll() async {
    state = const AsyncData([]);
    await _repository.clearTransactions();
  }

  List<ExpenseTransaction> _sort(List<ExpenseTransaction> transactions) {
    final sorted = [...transactions.where((item) => !item.isArchived)];
    sorted.sort((a, b) => b.date.compareTo(a.date));
    return sorted;
  }
}

class ExpenseTrackerScreen extends ConsumerWidget {
  const ExpenseTrackerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileSummaryProvider).maybeWhen(
          data: (profile) => profile,
          orElse: () => null,
        );
    final authState = ref.watch(authControllerProvider);
    final capabilities = profile?.capabilities ?? authState.capabilities;
    final accessMode = _resolveAccessMode(capabilities);
    final config = ref.watch(expenseTrackerConfigProvider).value ??
        ExpenseTrackerConfig.fallback();
    final transactionsAsync = ref.watch(expenseTransactionsProvider);
    final shouldSync = accessMode == ExpenseTrackerAccessMode.approvedSync;

    if (accessMode == ExpenseTrackerAccessMode.internalHidden) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tax-Ready Expense Tracker')),
        body: const SafeArea(
          child: PremiumEmptyState(
            icon: Icons.admin_panel_settings_outlined,
            title: 'Customer tracker hidden',
            message:
                'Internal users use Desk for customer review. Personal customer tracker is hidden by default.',
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tax-Ready Expense Tracker'),
        centerTitle: false,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: shouldSync ? 'Load cloud data' : 'Refresh local data',
            onPressed: () {
              if (shouldSync) {
                ref.read(expenseTransactionsProvider.notifier).loadSynced();
              } else {
                ref.read(expenseTransactionsProvider.notifier).reloadLocal();
              }
            },
            icon: Icon(shouldSync ? Icons.cloud_sync_outlined : Icons.refresh_rounded),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              final transactions = transactionsAsync.value ?? const <ExpenseTransaction>[];
              if (value == 'export') _showExportDialog(context, transactions);
              if (value == 'import') _showImportDialog(context, ref);
              if (value == 'sync') ref.read(expenseTransactionsProvider.notifier).bulkSync();
              if (value == 'clear') _confirmClearAll(context, ref);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'export', child: Text('Export backup JSON')),
              if (!shouldSync)
                const PopupMenuItem(value: 'import', child: Text('Import backup JSON')),
              if (shouldSync)
                const PopupMenuItem(value: 'sync', child: Text('Sync local entries now')),
              const PopupMenuItem(value: 'clear', child: Text('Clear local data')),
            ],
          ),
        ],
      ),
      floatingActionButton: Builder(
        builder: (context) {
          final count = transactionsAsync.value?.length ?? 0;
          final limitReached = accessMode == ExpenseTrackerAccessMode.guestLocal &&
              count >= config.guestLimit;
          return FloatingActionButton.extended(
            onPressed: limitReached
                ? () => _showLimitDialog(context, config.guestLimit)
                : () => _showTransactionSheet(
                      context,
                      ref,
                      accessMode: accessMode,
                      config: config,
                      sync: shouldSync,
                    ),
            icon: Icon(limitReached ? Icons.lock_outline_rounded : Icons.add_rounded),
            label: Text(limitReached ? 'Limit reached' : 'Add'),
          );
        },
      ),
      body: SafeArea(
        top: false,
        child: transactionsAsync.when(
          loading: () => const _TrackerLoadingView(),
          error: (_, _) => PremiumEmptyState(
            icon: Icons.account_balance_wallet_outlined,
            title: shouldSync ? 'Sync unavailable' : 'Tracker unavailable',
            message: shouldSync
                ? 'Cloud data could not be loaded. Your local backup remains safe.'
                : 'Local expense data could not be loaded.',
            actionLabel: 'Retry',
            onAction: () => shouldSync
                ? ref.read(expenseTransactionsProvider.notifier).loadSynced()
                : ref.read(expenseTransactionsProvider.notifier).reloadLocal(),
          ),
          data: (transactions) => _ExpenseTrackerBody(
            accessMode: accessMode,
            config: config,
            transactions: transactions,
            onQuickAdd: (category) => _showTransactionSheet(
              context,
              ref,
              accessMode: accessMode,
              config: config,
              sync: shouldSync,
              initialCategory: category,
            ),
            onSync: shouldSync
                ? () => ref.read(expenseTransactionsProvider.notifier).bulkSync()
                : null,
            onEdit: (transaction) => _showTransactionSheet(
              context,
              ref,
              accessMode: accessMode,
              config: config,
              sync: shouldSync,
              transaction: transaction,
            ),
            onDelete: (id) => _confirmDeleteTransaction(
              context,
              ref,
              id,
              sync: shouldSync,
            ),
          ),
        ),
      ),
    );
  }

  ExpenseTrackerAccessMode _resolveAccessMode(AuthCapabilities capabilities) {
    if (capabilities.isInternal) return ExpenseTrackerAccessMode.internalHidden;
    if (capabilities.isApproved) return ExpenseTrackerAccessMode.approvedSync;
    if (capabilities.isPending) return ExpenseTrackerAccessMode.pendingLocal;
    return ExpenseTrackerAccessMode.guestLocal;
  }

  void _showTransactionSheet(
    BuildContext context,
    WidgetRef ref, {
    required ExpenseTrackerAccessMode accessMode,
    required ExpenseTrackerConfig config,
    required bool sync,
    ExpenseTrackerCategory? initialCategory,
    ExpenseTransaction? transaction,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _TransactionSheet(
        transaction: transaction,
        categories: config.categories,
        initialCategory: initialCategory,
        receiptEnabled: accessMode == ExpenseTrackerAccessMode.approvedSync,
        onSave: (next) {
          final controller = ref.read(expenseTransactionsProvider.notifier);
          if (transaction == null) {
            controller.add(next, sync: sync);
          } else {
            controller.update(next, sync: sync);
          }
        },
      ),
    );
  }

  void _showExportDialog(BuildContext context, List<ExpenseTransaction> transactions) {
    final encoded = const JsonEncoder.withIndent('  ')
        .convert(transactions.map((transaction) => transaction.toJson()).toList());

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
            decoration: const InputDecoration(hintText: 'Paste exported JSON here...'),
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
                if (decoded is! List) throw const FormatException('Backup must be a list.');
                final transactions = decoded
                    .whereType<Map>()
                    .map((item) => ExpenseTransaction.fromJson(Map<String, dynamic>.from(item)))
                    .where((item) => item.id.isNotEmpty && item.amount > 0)
                    .toList(growable: false);
                ref.read(expenseTransactionsProvider.notifier).replaceAll(transactions);
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Imported ${transactions.length} transactions.')),
                );
              } catch (_) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invalid backup JSON. Please check format.')),
                );
              }
            },
            child: const Text('Import'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  Future<void> _confirmDeleteTransaction(
    BuildContext context,
    WidgetRef ref,
    String id, {
    required bool sync,
  }) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive transaction?'),
        content: Text(sync
            ? 'This transaction will be archived in your OMC account.'
            : 'This transaction will be removed from the local tracker.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      ref.read(expenseTransactionsProvider.notifier).remove(id, sync: sync);
    }
  }

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear local tracker?'),
        content: const Text('Only local cache is cleared. Cloud records are not deleted.'),
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

    if (shouldClear == true) {
      ref.read(expenseTransactionsProvider.notifier).clearAll();
    }
  }

  void _showLimitDialog(BuildContext context, int limit) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Create account to keep tracking'),
        content: Text(
          'Guest lite mode supports $limit local entries. Create an OMC account to unlock cloud sync, reports, receipts and tax-ready summaries.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Later'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).pushNamed('/signup');
            },
            child: const Text('Create account'),
          ),
        ],
      ),
    );
  }
}

class _ExpenseTrackerBody extends StatefulWidget {
  const _ExpenseTrackerBody({
    required this.accessMode,
    required this.config,
    required this.transactions,
    required this.onQuickAdd,
    required this.onEdit,
    required this.onDelete,
    this.onSync,
  });

  final ExpenseTrackerAccessMode accessMode;
  final ExpenseTrackerConfig config;
  final List<ExpenseTransaction> transactions;
  final ValueChanged<ExpenseTrackerCategory> onQuickAdd;
  final ValueChanged<ExpenseTransaction> onEdit;
  final ValueChanged<String> onDelete;
  final VoidCallback? onSync;

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
    final visibleCategories = widget.config.categories
        .where((item) => item.isExpense || item.isIncome)
        .toList(growable: false);

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 128),
      children: [
        _AccessBanner(
          mode: widget.accessMode,
          count: widget.transactions.length,
          guestLimit: widget.config.guestLimit,
          onSync: widget.onSync,
        ),
        const SizedBox(height: 16),
        _HeroSummaryCard(stats: allStats),
        const SizedBox(height: 16),
        _QuickAddPanel(
          categories: visibleCategories.take(10).toList(growable: false),
          onSelected: widget.onQuickAdd,
        ),
        const SizedBox(height: 16),
        _TaxReadyCard(stats: allStats),
        const SizedBox(height: 16),
        _ServiceSuggestionCard(stats: allStats),
        const SizedBox(height: 16),
        _FilterChips(selected: _filter, onChanged: (filter) => setState(() => _filter = filter)),
        const SizedBox(height: 16),
        _MonthSummaryCard(title: _filter.label, stats: filteredStats),
        const SizedBox(height: 16),
        _CategorySummaryCard(transactions: filteredTransactions),
        const SizedBox(height: 16),
        const _TrackerSectionHeader(
          title: 'Transactions',
          subtitle: 'Recent income, expense and tax-ready activity.',
          icon: Icons.receipt_long_outlined,
        ),
        const SizedBox(height: 12),
        if (widget.transactions.isEmpty)
          const PremiumEmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No transactions yet',
            message: 'Add income or expenses to start building your monthly tax-ready summary.',
          )
        else if (filteredTransactions.isEmpty)
          PremiumEmptyState(
            icon: Icons.filter_alt_off_outlined,
            title: 'No ${_filter.label.toLowerCase()} transactions',
            message: 'Try another period or add a transaction for this range.',
          )
        else
          for (final transaction in filteredTransactions.take(40))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _TransactionTile(
                transaction: transaction,
                onEdit: () => widget.onEdit(transaction),
                onDelete: () => widget.onDelete(transaction.id),
              ),
            ),
      ],
    );
  }

  List<ExpenseTransaction> _filterTransactions(List<ExpenseTransaction> transactions) {
    final now = DateTime.now();
    return transactions.where((item) {
      if (_filter == _TrackerFilter.all) return true;
      if (_filter == _TrackerFilter.thisMonth) {
        return item.date.year == now.year && item.date.month == now.month;
      }
      final lastMonth = DateTime(now.year, now.month - 1);
      return item.date.year == lastMonth.year && item.date.month == lastMonth.month;
    }).toList(growable: false);
  }
}

enum _TrackerFilter {
  thisMonth('This month'),
  lastMonth('Last month'),
  all('All');

  const _TrackerFilter(this.label);
  final String label;
}

class _TrackerStats {
  const _TrackerStats({
    required this.income,
    required this.expenses,
    required this.transactionCount,
    required this.taxRelevantTotal,
    required this.businessTotal,
    required this.receiptsAttached,
    required this.recurringCount,
  });

  final double income;
  final double expenses;
  final int transactionCount;
  final double taxRelevantTotal;
  final double businessTotal;
  final int receiptsAttached;
  final int recurringCount;

  double get balance => income - expenses;

  int get readinessScore {
    if (transactionCount == 0) return 0;
    var score = 20;
    if (taxRelevantTotal > 0) score += 25;
    if (businessTotal > 0) score += 15;
    if (receiptsAttached > 0) score += 20;
    if (income > 0) score += 10;
    if (recurringCount > 0) score += 10;
    return score.clamp(0, 100);
  }

  String get readinessLabel {
    if (readinessScore >= 80) return 'Ready for review';
    if (readinessScore >= 60) return 'Good';
    if (readinessScore >= 35) return 'Improving';
    return 'Low';
  }

  factory _TrackerStats.fromTransactions(List<ExpenseTransaction> transactions) {
    double income = 0;
    double expenses = 0;
    double taxRelevantTotal = 0;
    double businessTotal = 0;
    var receiptsAttached = 0;
    var recurringCount = 0;

    for (final item in transactions) {
      if (item.isIncome) {
        income += item.amount;
      } else {
        expenses += item.amount;
        if (item.taxRelevant) taxRelevantTotal += item.amount;
        if (item.businessRelated) businessTotal += item.amount;
      }
      if ((item.receiptFile ?? '').trim().isNotEmpty) receiptsAttached += 1;
      if (item.recurring) recurringCount += 1;
    }

    return _TrackerStats(
      income: income,
      expenses: expenses,
      transactionCount: transactions.length,
      taxRelevantTotal: taxRelevantTotal,
      businessTotal: businessTotal,
      receiptsAttached: receiptsAttached,
      recurringCount: recurringCount,
    );
  }
}

class _AccessBanner extends StatelessWidget {
  const _AccessBanner({
    required this.mode,
    required this.count,
    required this.guestLimit,
    this.onSync,
  });

  final ExpenseTrackerAccessMode mode;
  final int count;
  final int guestLimit;
  final VoidCallback? onSync;

  @override
  Widget build(BuildContext context) {
    final data = switch (mode) {
      ExpenseTrackerAccessMode.guestLocal => (
          Icons.phone_iphone_rounded,
          'Local Lite Mode',
          '$count/$guestLimit entries used. Create an OMC account for sync, backup, receipts and tax-ready summaries.',
        ),
      ExpenseTrackerAccessMode.pendingLocal => (
          Icons.hourglass_top_rounded,
          'Local tracker unlocked',
          'Sync will activate after your profile is approved. Your local entries stay safe on this device.',
        ),
      ExpenseTrackerAccessMode.approvedSync => (
          Icons.cloud_sync_outlined,
          'Approved cloud tracker',
          'Sync entries to OMC Desk, upload receipts, prepare reports and share summaries with consultants.',
        ),
      _ => (
          Icons.lock_outline_rounded,
          'Tracker unavailable',
          'This account cannot use the customer tracker.',
        ),
    };

    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBox(icon: data.$1),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.$2, style: _titleStyle(size: 15)),
                const SizedBox(height: 5),
                Text(data.$3, style: _bodyStyle()),
                if (mode == ExpenseTrackerAccessMode.approvedSync && onSync != null) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: onSync,
                    icon: const Icon(Icons.cloud_upload_outlined, size: 18),
                    label: const Text('Sync local entries'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
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
          Text('Current month balance', style: _bodyStyle()),
          const SizedBox(height: 8),
          Text(_money(stats.balance), maxLines: 1, overflow: TextOverflow.ellipsis, style: _titleStyle(size: 30)),
          const SizedBox(height: 12),
          Text(_insightText(stats), style: _bodyStyle()),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _MiniStat(label: 'Income', value: _money(stats.income), icon: Icons.south_west_rounded)),
              const SizedBox(width: 12),
              Expanded(child: _MiniStat(label: 'Expenses', value: _money(stats.expenses), icon: Icons.north_east_rounded)),
            ],
          ),
        ],
      ),
    );
  }

  String _insightText(_TrackerStats stats) {
    if (stats.taxRelevantTotal > 0) return '${_money(stats.taxRelevantTotal)} marked tax-relevant.';
    if (stats.businessTotal > 0) return '${_money(stats.businessTotal)} tracked as business expense.';
    if (stats.transactionCount == 0) return 'Add your first expense in two taps.';
    return '${stats.transactionCount} entries tracked this month.';
  }
}

class _QuickAddPanel extends StatelessWidget {
  const _QuickAddPanel({required this.categories, required this.onSelected});

  final List<ExpenseTrackerCategory> categories;
  final ValueChanged<ExpenseTrackerCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _TrackerSectionHeader(
            title: 'Quick add',
            subtitle: 'Choose a category, enter amount, save.',
            icon: Icons.bolt_rounded,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categories
                .map((category) => ActionChip(
                      avatar: Icon(_iconForCategory(category.title), size: 18, color: AppTheme.primaryRed),
                      label: Text(category.title),
                      onPressed: () => onSelected(category),
                      side: BorderSide(color: AppTheme.primaryRed.withValues(alpha: 0.18)),
                      backgroundColor: AppTheme.primaryRed.withValues(alpha: 0.05),
                      labelStyle: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w800),
                    ))
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _TaxReadyCard extends StatelessWidget {
  const _TaxReadyCard({required this.stats});
  final _TrackerStats stats;

  @override
  Widget build(BuildContext context) {
    final score = stats.readinessScore;
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _TrackerSectionHeader(
            title: 'Tax readiness',
            subtitle: 'Based on tags, receipts, business expenses and income entries.',
            icon: Icons.verified_outlined,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              SizedBox(
                width: 76,
                height: 76,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(value: score / 100, strokeWidth: 8),
                    Text('$score%', style: _titleStyle(size: 17)),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(stats.readinessLabel, style: _titleStyle(size: 17)),
                    const SizedBox(height: 4),
                    Text('Tax total ${_money(stats.taxRelevantTotal)} · Business ${_money(stats.businessTotal)} · Receipts ${stats.receiptsAttached}', style: _bodyStyle()),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ServiceSuggestionCard extends StatelessWidget {
  const _ServiceSuggestionCard({required this.stats});
  final _TrackerStats stats;

  @override
  Widget build(BuildContext context) {
    final (title, message, icon) = stats.businessTotal > 0
        ? ('Bookkeeping support', 'You are tracking business expenses. OMC can organize these into monthly books.', Icons.business_center_outlined)
        : stats.taxRelevantTotal > 0
            ? ('Tax filing preparation', 'Your tax-ready expense summary is building. Start tax filing with OMC when ready.', Icons.fact_check_outlined)
            : ('Build your tax record', 'Mark useful expenses as tax-relevant and attach receipts for better filing readiness.', Icons.lightbulb_outline_rounded);

    return PremiumCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBox(icon: icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: _titleStyle(size: 16)),
                const SizedBox(height: 5),
                Text(message, style: _bodyStyle()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChips extends StatelessWidget {
  const _FilterChips({required this.selected, required this.onChanged});
  final _TrackerFilter selected;
  final ValueChanged<_TrackerFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<_TrackerFilter>(
      segments: _TrackerFilter.values
          .map((filter) => ButtonSegment<_TrackerFilter>(value: filter, label: Text(filter.label)))
          .toList(growable: false),
      selected: {selected},
      onSelectionChanged: (selection) => onChanged(selection.first),
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
          Text(title, style: _titleStyle(size: 18)),
          const SizedBox(height: 12),
          _SummaryRow(label: 'Income', value: stats.income, icon: Icons.trending_up_rounded),
          const Divider(height: 24),
          _SummaryRow(label: 'Expenses', value: stats.expenses, icon: Icons.trending_down_rounded),
          const Divider(height: 24),
          _SummaryRow(label: 'Net balance', value: stats.balance, icon: Icons.account_balance_wallet_outlined),
          const Divider(height: 24),
          _SummaryRow(label: 'Transactions', valueLabel: '${stats.transactionCount}', icon: Icons.receipt_long_outlined),
        ],
      ),
    );
  }
}

class _CategorySummaryCard extends StatelessWidget {
  const _CategorySummaryCard({required this.transactions});
  final List<ExpenseTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    final expenses = transactions.where((item) => item.isExpense).toList(growable: false);
    if (expenses.isEmpty) return const SizedBox.shrink();

    final totals = <String, double>{};
    for (final transaction in expenses) {
      totals.update(transaction.category, (value) => value + transaction.amount, ifAbsent: () => transaction.amount);
    }
    final rows = totals.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final totalExpense = expenses.fold<double>(0, (sum, item) => sum + item.amount);

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

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction, required this.onEdit, required this.onDelete});
  final ExpenseTransaction transaction;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.isIncome;
    return PremiumCard(
      child: Row(
        children: [
          _IconBox(icon: isIncome ? Icons.south_west_rounded : _iconForCategory(transaction.category)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(transaction.merchant?.trim().isNotEmpty == true ? transaction.merchant!.trim() : transaction.category, maxLines: 1, overflow: TextOverflow.ellipsis, style: _titleStyle(size: 15)),
                const SizedBox(height: 4),
                Text('${DateFormat('dd MMM yyyy').format(transaction.date)} · ${transaction.account} · ${transaction.paymentMethod}', maxLines: 1, overflow: TextOverflow.ellipsis, style: _bodyStyle()),
                if ((transaction.note ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(transaction.note!.trim(), maxLines: 2, overflow: TextOverflow.ellipsis, style: _bodyStyle()),
                ],
                const SizedBox(height: 7),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    if (transaction.taxRelevant) const _MiniChip(label: 'Tax'),
                    if (transaction.businessRelated) const _MiniChip(label: 'Business'),
                    if (transaction.recurring) const _MiniChip(label: 'Recurring'),
                    if ((transaction.receiptFile ?? '').trim().isNotEmpty) const _MiniChip(label: 'Receipt'),
                    if (transaction.synced) const _MiniChip(label: 'Synced'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 118),
                child: Text('${isIncome ? '+' : '-'}${_money(transaction.amount)}', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: TextStyle(color: isIncome ? Colors.green.shade700 : Colors.red.shade700, fontWeight: FontWeight.w900)),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(visualDensity: VisualDensity.compact, tooltip: 'Edit', onPressed: onEdit, icon: const Icon(Icons.edit_outlined)),
                  IconButton(visualDensity: VisualDensity.compact, tooltip: 'Archive', onPressed: onDelete, icon: const Icon(Icons.archive_outlined)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TransactionSheet extends StatefulWidget {
  const _TransactionSheet({
    required this.categories,
    required this.receiptEnabled,
    required this.onSave,
    this.transaction,
    this.initialCategory,
  });

  final List<ExpenseTrackerCategory> categories;
  final bool receiptEnabled;
  final ValueChanged<ExpenseTransaction> onSave;
  final ExpenseTransaction? transaction;
  final ExpenseTrackerCategory? initialCategory;

  @override
  State<_TransactionSheet> createState() => _TransactionSheetState();
}

class _TransactionSheetState extends State<_TransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _categoryController;
  late final TextEditingController _accountController;
  late final TextEditingController _paymentMethodController;
  late final TextEditingController _merchantController;
  late final TextEditingController _noteController;
  late final TextEditingController _receiptController;

  late ExpenseTransactionType _type;
  late DateTime _selectedDate;
  bool _advanced = false;
  bool _taxRelevant = false;
  bool _businessRelated = false;
  bool _recurring = false;
  bool _reimbursable = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.transaction;
    final initialCategory = widget.initialCategory;
    _type = existing?.type ?? initialCategory?.type ?? ExpenseTransactionType.expense;
    _selectedDate = existing?.date ?? DateTime.now();
    _amountController = TextEditingController(text: existing == null ? '' : existing.amount.toStringAsFixed(0));
    _categoryController = TextEditingController(text: existing?.category ?? initialCategory?.title ?? '');
    _accountController = TextEditingController(text: existing?.account ?? 'Cash');
    _paymentMethodController = TextEditingController(text: existing?.paymentMethod ?? 'Cash');
    _merchantController = TextEditingController(text: existing?.merchant ?? '');
    _noteController = TextEditingController(text: existing?.note ?? '');
    _receiptController = TextEditingController(text: existing?.receiptFile ?? '');
    _taxRelevant = existing?.taxRelevant ?? initialCategory?.isTaxRelevant ?? false;
    _businessRelated = existing?.businessRelated ?? initialCategory?.businessDefault ?? false;
    _recurring = existing?.recurring ?? false;
    _reimbursable = existing?.reimbursable ?? false;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _categoryController.dispose();
    _accountController.dispose();
    _paymentMethodController.dispose();
    _merchantController.dispose();
    _noteController.dispose();
    _receiptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final quickCategories = widget.categories.where((item) => item.type == _type).take(8).toList(growable: false);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 20),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            Row(
              children: [
                _IconBox(icon: widget.transaction == null ? Icons.add_card_rounded : Icons.edit_outlined),
                const SizedBox(width: 12),
                Expanded(child: Text(widget.transaction == null ? 'Add transaction' : 'Edit transaction', style: _titleStyle(size: 22))),
              ],
            ),
            const SizedBox(height: 16),
            SegmentedButton<ExpenseTransactionType>(
              segments: const [
                ButtonSegment(value: ExpenseTransactionType.expense, label: Text('Expense'), icon: Icon(Icons.north_east_rounded)),
                ButtonSegment(value: ExpenseTransactionType.income, label: Text('Income'), icon: Icon(Icons.south_west_rounded)),
              ],
              selected: {_type},
              onSelectionChanged: (selection) => setState(() => _type = selection.first),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount', prefixIcon: Icon(Icons.payments_outlined)),
              validator: (value) {
                final amount = double.tryParse(value?.replaceAll(',', '').trim() ?? '');
                if (amount == null || amount <= 0) return 'Enter a valid amount.';
                return null;
              },
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: quickCategories
                  .map((category) => ActionChip(
                        label: Text(category.title),
                        onPressed: () {
                          setState(() {
                            _categoryController.text = category.title;
                            _taxRelevant = category.isTaxRelevant;
                            _businessRelated = category.businessDefault;
                          });
                        },
                      ))
                  .toList(growable: false),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _categoryController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: _type == ExpenseTransactionType.income ? 'Income category' : 'Expense category',
                prefixIcon: const Icon(Icons.category_outlined),
              ),
              validator: (value) => value == null || value.trim().isEmpty ? 'Category is required.' : null,
            ),
            const SizedBox(height: 12),
            ExpansionTile(
              initiallyExpanded: _advanced,
              onExpansionChanged: (value) => setState(() => _advanced = value),
              tilePadding: EdgeInsets.zero,
              title: Text('Advanced details', style: _titleStyle(size: 15)),
              children: [
                const SizedBox(height: 8),
                TextFormField(controller: _accountController, decoration: const InputDecoration(labelText: 'Account', prefixIcon: Icon(Icons.account_balance_wallet_outlined))),
                const SizedBox(height: 12),
                TextFormField(controller: _paymentMethodController, decoration: const InputDecoration(labelText: 'Payment method', prefixIcon: Icon(Icons.credit_card_rounded))),
                const SizedBox(height: 12),
                _DatePickerTile(date: _selectedDate, onTap: _pickDate),
                const SizedBox(height: 12),
                TextFormField(controller: _merchantController, decoration: const InputDecoration(labelText: 'Merchant optional', prefixIcon: Icon(Icons.storefront_outlined))),
                const SizedBox(height: 12),
                TextFormField(controller: _noteController, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Note optional', prefixIcon: Icon(Icons.notes_outlined))),
                if (widget.receiptEnabled) ...[
                  const SizedBox(height: 12),
                  TextFormField(controller: _receiptController, decoration: const InputDecoration(labelText: 'Receipt file URL optional', prefixIcon: Icon(Icons.attach_file_rounded))),
                ],
                const SizedBox(height: 10),
                SwitchListTile.adaptive(value: _taxRelevant, onChanged: (value) => setState(() => _taxRelevant = value), title: const Text('Useful for tax')),
                SwitchListTile.adaptive(value: _businessRelated, onChanged: (value) => setState(() => _businessRelated = value), title: const Text('Business expense')),
                SwitchListTile.adaptive(value: _recurring, onChanged: (value) => setState(() => _recurring = value), title: const Text('Recurring')),
                SwitchListTile.adaptive(value: _reimbursable, onChanged: (value) => setState(() => _reimbursable = value), title: const Text('Reimbursable')),
              ],
            ),
            const SizedBox(height: 18),
            AppButton(label: widget.transaction == null ? 'Save transaction' : 'Update transaction', icon: Icons.check_rounded, onPressed: _save),
            const SizedBox(height: 4),
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
    setState(() => _selectedDate = DateTime(pickedDate.year, pickedDate.month, pickedDate.day));
  }

  void _save() {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    final existing = widget.transaction;
    final transaction = ExpenseTransaction(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      type: _type,
      amount: double.parse(_amountController.text.replaceAll(',', '').trim()),
      category: _categoryController.text.trim(),
      account: _accountController.text.trim().isEmpty ? 'Cash' : _accountController.text.trim(),
      paymentMethod: _paymentMethodController.text.trim().isEmpty ? 'Cash' : _paymentMethodController.text.trim(),
      merchant: _merchantController.text.trim().isEmpty ? null : _merchantController.text.trim(),
      date: _selectedDate,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      taxRelevant: _taxRelevant,
      businessRelated: _businessRelated,
      recurring: _recurring,
      reimbursable: _reimbursable,
      receiptFile: _receiptController.text.trim().isEmpty ? null : _receiptController.text.trim(),
      createdFromGuest: existing?.createdFromGuest ?? false,
      synced: existing?.synced ?? false,
    );

    widget.onSave(transaction);
    Navigator.of(context).pop();
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
        decoration: const InputDecoration(labelText: 'Date', prefixIcon: Icon(Icons.calendar_month_outlined)),
        child: Text(DateFormat('dd MMM yyyy').format(date), style: _titleStyle(size: 14)),
      ),
    );
  }
}

class _TrackerSectionHeader extends StatelessWidget {
  const _TrackerSectionHeader({required this.title, required this.subtitle, required this.icon});
  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _IconBox(icon: icon),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: _titleStyle(size: 18)),
              const SizedBox(height: 3),
              Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: _bodyStyle()),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, required this.icon});
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
        border: Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.07)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBox(icon: icon, size: 32),
          const SizedBox(height: 10),
          Text(label, style: _bodyStyle()),
          const SizedBox(height: 4),
          Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: _titleStyle(size: 14)),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({required this.label, required this.icon, this.value, this.valueLabel});
  final String label;
  final double? value;
  final String? valueLabel;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _IconBox(icon: icon, size: 32),
        const SizedBox(width: 10),
        Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _bodyStyle())),
        Flexible(child: Text(valueLabel ?? _money(value ?? 0), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: _titleStyle(size: 14))),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.label, required this.amount, required this.percentage});
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
            Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: _bodyStyle())),
            Flexible(child: Text('${_money(amount)} · $percentLabel', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.right, style: _titleStyle(size: 13))),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(value: percentage.clamp(0, 1), minHeight: 6, borderRadius: BorderRadius.circular(999)),
      ],
    );
  }
}

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primaryRed.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.10)),
      ),
      child: Text(label, style: const TextStyle(color: AppTheme.primaryRed, fontSize: 11, fontWeight: FontWeight.w900)),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon, this.size = 42});
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.primaryRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(size >= 40 ? 15 : 12),
        border: Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.08)),
      ),
      child: Icon(icon, color: AppTheme.primaryRed, size: size >= 40 ? 22 : 18),
    );
  }
}

class _TrackerLoadingView extends StatelessWidget {
  const _TrackerLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 128),
      children: [
        for (var index = 0; index < 5; index++) ...[
          PremiumCard(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(width: 46, height: 46, decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16))),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(width: double.infinity, height: 14, decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(999))),
                      const SizedBox(height: 10),
                      Container(width: 150, height: 11, decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(999))),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (index != 4) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

TextStyle _titleStyle({required double size}) {
  return TextStyle(color: AppTheme.textPrimary, fontSize: size, fontWeight: FontWeight.w900);
}

TextStyle _bodyStyle() {
  return const TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.35, fontWeight: FontWeight.w600);
}

IconData _iconForCategory(String value) {
  final text = value.toLowerCase();
  if (text.contains('food')) return Icons.restaurant_outlined;
  if (text.contains('fuel')) return Icons.local_gas_station_outlined;
  if (text.contains('bill') || text.contains('util')) return Icons.receipt_long_outlined;
  if (text.contains('rent')) return Icons.home_work_outlined;
  if (text.contains('shop')) return Icons.shopping_bag_outlined;
  if (text.contains('transport')) return Icons.directions_car_outlined;
  if (text.contains('health')) return Icons.health_and_safety_outlined;
  if (text.contains('education')) return Icons.school_outlined;
  if (text.contains('business')) return Icons.business_center_outlined;
  if (text.contains('tax') || text.contains('legal')) return Icons.gavel_outlined;
  if (text.contains('salary') || text.contains('income')) return Icons.payments_outlined;
  return Icons.category_outlined;
}

String _money(double value) {
  return NumberFormat.currency(locale: 'en_PK', symbol: 'PKR ', decimalDigits: 0).format(value);
}
