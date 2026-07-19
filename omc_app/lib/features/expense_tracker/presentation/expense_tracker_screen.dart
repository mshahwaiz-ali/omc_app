import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/app_back_header.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_empty_state.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../../profile/data/profile_repository.dart';
import '../data/expense_tracker_repository.dart';
import '../domain/expense_transaction.dart';

final expenseTrackerConfigProvider = FutureProvider<ExpenseTrackerConfig>((
  ref,
) {
  return ref.watch(expenseTrackerRepositoryProvider).fetchConfig();
});

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

  Future<ExpenseTransaction> add(
    ExpenseTransaction transaction, {
    required bool sync,
  }) async {
    final current = state.value ?? const <ExpenseTransaction>[];
    var nextTransaction = transaction;

    if (sync) {
      final synced = await _repository.createSyncedTransaction(transaction);
      if (synced != null) nextTransaction = synced.copyWith(synced: true);
    }

    final next = _sort([nextTransaction, ...current]);
    state = AsyncData(next);
    await _repository.saveTransactions(next);
    return nextTransaction;
  }

  Future<ExpenseTransaction> updateTransaction(
    ExpenseTransaction transaction, {
    required bool sync,
  }) async {
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
    return nextTransaction;
  }

  Future<void> attachReceipt({
    required ExpenseTransaction transaction,
    required PlatformFile file,
    required bool sync,
  }) async {
    if (!sync) return;

    final fileUrl = await _repository.uploadReceiptFile(
      entryId: transaction.id,
      fileName: file.name,
      filePath: file.path,
      fileBytes: file.bytes,
    );

    if (fileUrl.trim().isEmpty) {
      throw StateError('Receipt uploaded but no file URL was returned.');
    }

    await updateTransaction(
      transaction.copyWith(receiptFile: fileUrl, synced: true),
      sync: true,
    );
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
    final profile = ref
        .watch(profileSummaryProvider)
        .maybeWhen(data: (profile) => profile, orElse: () => null);
    final authState = ref.watch(authControllerProvider);
    final capabilities = profile?.capabilities ?? authState.capabilities;
    final accessMode = _resolveAccessMode(capabilities);
    final config =
        ref.watch(expenseTrackerConfigProvider).value ??
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
      backgroundColor: const Color(0xFFF7F8FB),
      appBar: AppBackHeader(
        title: 'Expense Tracker',
        subtitle: 'Track income, expenses and tax-ready records',
        fallbackRoute: '/home',
        action: PopupMenuButton<String>(
          tooltip: 'More actions',
          icon: const Icon(Icons.more_horiz_rounded),
          onSelected: (value) {
            final transactions =
                transactionsAsync.value ?? const <ExpenseTransaction>[];
            if (value == 'refresh') {
              if (shouldSync) {
                ref.read(expenseTransactionsProvider.notifier).loadSynced();
              } else {
                ref.read(expenseTransactionsProvider.notifier).reloadLocal();
              }
            }
            if (value == 'export') _showExportDialog(context, transactions);
            if (value == 'import') _showImportDialog(context, ref);
            if (value == 'sync') {
              ref.read(expenseTransactionsProvider.notifier).bulkSync();
            }
            if (value == 'clear') _confirmClearAll(context, ref);
          },
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'refresh',
              child: Text(
                shouldSync ? 'Load cloud data' : 'Refresh local data',
              ),
            ),
            const PopupMenuItem(
              value: 'export',
              child: Text('Export backup JSON'),
            ),
            if (!shouldSync)
              const PopupMenuItem(
                value: 'import',
                child: Text('Import backup JSON'),
              ),
            if (shouldSync)
              const PopupMenuItem(
                value: 'sync',
                child: Text('Sync local entries now'),
              ),
            const PopupMenuItem(
              value: 'clear',
              child: Text('Clear local data'),
            ),
          ],
        ),
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
            onManualEntry: () => _showTransactionSheet(
              context,
              ref,
              accessMode: accessMode,
              config: config,
              sync: shouldSync,
            ),
            onQuickAdd: (category) => _showTransactionSheet(
              context,
              ref,
              accessMode: accessMode,
              config: config,
              sync: shouldSync,
              initialCategory: category,
            ),
            onSync: shouldSync
                ? () =>
                      ref.read(expenseTransactionsProvider.notifier).bulkSync()
                : null,
            onEdit: (transaction) => _showTransactionSheet(
              context,
              ref,
              accessMode: accessMode,
              config: config,
              sync: shouldSync,
              transaction: transaction,
            ),
            onDelete: (id) =>
                _confirmDeleteTransaction(context, ref, id, sync: shouldSync),
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
        onAttachReceipt: accessMode == ExpenseTrackerAccessMode.approvedSync
            ? (saved, file) => ref
                  .read(expenseTransactionsProvider.notifier)
                  .attachReceipt(transaction: saved, file: file, sync: sync)
            : null,
        onSave: (next) async {
          final controller = ref.read(expenseTransactionsProvider.notifier);
          if (transaction == null) {
            return controller.add(next, sync: sync);
          }
          return controller.updateTransaction(next, sync: sync);
        },
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
                  throw const FormatException('Backup must be a list.');
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
        content: Text(
          sync
              ? 'This transaction will be archived in your OMC account.'
              : 'This transaction will be removed from the local tracker.',
        ),
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
        content: const Text(
          'Only local cache is cleared. Cloud records are not deleted.',
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

    if (shouldClear == true) {
      ref.read(expenseTransactionsProvider.notifier).clearAll();
    }
  }
}

class _ExpenseTrackerBody extends StatefulWidget {
  const _ExpenseTrackerBody({
    required this.accessMode,
    required this.config,
    required this.transactions,
    required this.onManualEntry,
    required this.onQuickAdd,
    required this.onEdit,
    required this.onDelete,
    this.onSync,
  });

  final ExpenseTrackerAccessMode accessMode;
  final ExpenseTrackerConfig config;
  final List<ExpenseTransaction> transactions;
  final VoidCallback onManualEntry;
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
        .take(8)
        .toList(growable: false);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 148),
      children: [
        _AccessBanner(
          mode: widget.accessMode,
          count: widget.transactions.length,
          guestLimit: widget.config.guestLimit,
          onSync: widget.onSync,
        ),
        const SizedBox(height: 12),
        _HeroSummaryCard(stats: allStats),
        const SizedBox(height: 12),
        _QuickAddPanel(
          categories: visibleCategories,
          onManualEntry: widget.onManualEntry,
          onSelected: widget.onQuickAdd,
        ),
        const SizedBox(height: 12),
        _TaxReadyCard(stats: allStats),
        const SizedBox(height: 14),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Transactions',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            _FilterChips(
              selected: _filter,
              onChanged: (filter) => setState(() => _filter = filter),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _MonthSummaryCard(title: _filter.label, stats: filteredStats),
        if (filteredTransactions.isNotEmpty) ...[
          const SizedBox(height: 10),
          _CategorySummaryCard(transactions: filteredTransactions),
        ],
        const SizedBox(height: 10),
        if (widget.transactions.isEmpty)
          PremiumEmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No transactions yet',
            message:
                'Add income or an expense to start building your tax-ready record.',
            actionLabel: 'Add transaction',
            onAction: widget.onManualEntry,
          )
        else if (filteredTransactions.isEmpty)
          const PremiumEmptyState(
            icon: Icons.filter_alt_off_outlined,
            title: 'No transactions in this period',
            message: 'Choose another period to view your entries.',
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

  factory _TrackerStats.fromTransactions(
    List<ExpenseTransaction> transactions,
  ) {
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
        'Local mode',
        '$count of $guestLimit entries used',
      ),
      ExpenseTrackerAccessMode.pendingLocal => (
        Icons.hourglass_top_rounded,
        'Local tracker',
        'Cloud sync activates after approval',
      ),
      ExpenseTrackerAccessMode.approvedSync => (
        Icons.cloud_done_outlined,
        'Cloud tracker active',
        'Entries and receipts can sync with OMC',
      ),
      _ => (
        Icons.lock_outline_rounded,
        'Tracker unavailable',
        'This account cannot use the customer tracker',
      ),
    };

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1E4EA)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F6),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(data.$1, size: 18, color: const Color(0xFF555B64)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.$2, style: _titleStyle(size: 13)),
                const SizedBox(height: 2),
                Text(data.$3, style: _bodyStyle(size: 10.5)),
              ],
            ),
          ),
          if (mode == ExpenseTrackerAccessMode.approvedSync && onSync != null)
            IconButton(
              tooltip: 'Sync local entries',
              visualDensity: VisualDensity.compact,
              onPressed: onSync,
              icon: const Icon(Icons.sync_rounded, size: 20),
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
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E6EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Current month',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(_money(stats.balance), style: _titleStyle(size: 25)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _CompactStat(
                  label: 'Income',
                  value: _money(stats.income),
                  icon: Icons.south_west_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CompactStat(
                  label: 'Expenses',
                  value: _money(stats.expenses),
                  icon: Icons.north_east_rounded,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _CompactStat(
                  label: 'Entries',
                  value: '${stats.transactionCount}',
                  icon: Icons.receipt_long_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CompactStat extends StatelessWidget {
  const _CompactStat({
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9EBEF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: const Color(0xFF646A73)),
          const SizedBox(height: 7),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAddPanel extends StatelessWidget {
  const _QuickAddPanel({
    required this.categories,
    required this.onManualEntry,
    required this.onSelected,
  });

  final List<ExpenseTrackerCategory> categories;
  final VoidCallback onManualEntry;
  final ValueChanged<ExpenseTrackerCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E6EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Quick add',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              SizedBox(
                width: 142,
                height: 40,
                child: FilledButton.icon(
                  onPressed: onManualEntry,
                  icon: const Icon(Icons.add_rounded, size: 17),
                  label: const Text('Add transaction'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: categories
                .map(
                  (category) => ActionChip(
                    avatar: Icon(
                      _iconForCategory(category.title),
                      size: 15,
                      color: const Color(0xFF555B64),
                    ),
                    label: Text(category.title),
                    onPressed: () => onSelected(category),
                    side: const BorderSide(color: Color(0xFFE1E4E9)),
                    backgroundColor: Colors.white,
                    visualDensity: VisualDensity.compact,
                    labelStyle: const TextStyle(
                      color: Color(0xFF686D76),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
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

    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E6EB)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F6),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              '$score',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tax readiness · ${stats.readinessLabel}',
                  style: _titleStyle(size: 13),
                ),
                const SizedBox(height: 3),
                Text(
                  'Tax ${_money(stats.taxRelevantTotal)} · Business ${_money(stats.businessTotal)} · ${stats.receiptsAttached} receipts',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _bodyStyle(size: 10.5),
                ),
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
    return PopupMenuButton<_TrackerFilter>(
      tooltip: 'Choose period',
      onSelected: onChanged,
      itemBuilder: (context) => _TrackerFilter.values
          .map(
            (filter) => PopupMenuItem<_TrackerFilter>(
              value: filter,
              child: Text(filter.label),
            ),
          )
          .toList(growable: false),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: const Color(0xFFE1E4E9)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selected.label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9EBEF)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${stats.transactionCount} entries',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          Text(
            'Income ${_money(stats.income)}',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 7),
            child: Text('·', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          Text(
            'Expense ${_money(stats.expenses)}',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
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
    final expenses = transactions
        .where((item) => item.isExpense)
        .toList(growable: false);
    if (expenses.isEmpty) return const SizedBox.shrink();

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

    return SizedBox(
      height: 31,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: rows.take(5).length,
        separatorBuilder: (_, _) => const SizedBox(width: 7),
        itemBuilder: (context, index) {
          final row = rows[index];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE1E4E9)),
            ),
            child: Text(
              '${row.key}  ${_money(row.value)}',
              style: const TextStyle(
                color: Color(0xFF686D76),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
    required this.onEdit,
    required this.onDelete,
  });

  final ExpenseTransaction transaction;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isIncome = transaction.isIncome;
    final title = transaction.merchant?.trim().isNotEmpty == true
        ? transaction.merchant!.trim()
        : transaction.category;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E6EB)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F6),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              isIncome
                  ? Icons.south_west_rounded
                  : _iconForCategory(transaction.category),
              color: const Color(0xFF555B64),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _titleStyle(size: 13),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${isIncome ? '+' : '-'}${_money(transaction.amount)}',
                      style: TextStyle(
                        color: isIncome
                            ? const Color(0xFF26734D)
                            : AppTheme.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${DateFormat('dd MMM yyyy').format(transaction.date)} · ${transaction.account} · ${transaction.paymentMethod}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _bodyStyle(size: 10),
                ),
                if ((transaction.note ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    transaction.note!.trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _bodyStyle(size: 10),
                  ),
                ],
                const SizedBox(height: 6),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    if (transaction.taxRelevant) const _MiniChip(label: 'Tax'),
                    if (transaction.businessRelated)
                      const _MiniChip(label: 'Business'),
                    if ((transaction.receiptFile ?? '').trim().isNotEmpty)
                      const _MiniChip(label: 'Receipt'),
                    if (transaction.synced) const _MiniChip(label: 'Synced'),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Transaction actions',
            icon: const Icon(Icons.more_vert_rounded, size: 19),
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'archive') onDelete();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'archive', child: Text('Archive')),
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
    this.onAttachReceipt,
  });

  final List<ExpenseTrackerCategory> categories;
  final bool receiptEnabled;
  final Future<ExpenseTransaction> Function(ExpenseTransaction) onSave;
  final ExpenseTransaction? transaction;
  final ExpenseTrackerCategory? initialCategory;
  final Future<void> Function(
    ExpenseTransaction transaction,
    PlatformFile file,
  )?
  onAttachReceipt;

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
  PlatformFile? _selectedReceiptFile;

  @override
  void initState() {
    super.initState();
    final existing = widget.transaction;
    final initialCategory = widget.initialCategory;
    _type =
        existing?.type ??
        initialCategory?.type ??
        ExpenseTransactionType.expense;
    _selectedDate = existing?.date ?? DateTime.now();
    _amountController = TextEditingController(
      text: existing == null ? '' : existing.amount.toStringAsFixed(0),
    );
    _categoryController = TextEditingController(
      text: existing?.category ?? initialCategory?.title ?? '',
    );
    _accountController = TextEditingController(
      text: existing?.account ?? 'Cash',
    );
    _paymentMethodController = TextEditingController(
      text: existing?.paymentMethod ?? 'Cash',
    );
    _merchantController = TextEditingController(text: existing?.merchant ?? '');
    _noteController = TextEditingController(text: existing?.note ?? '');
    _receiptController = TextEditingController(
      text: existing?.receiptFile ?? '',
    );
    _taxRelevant =
        existing?.taxRelevant ?? initialCategory?.isTaxRelevant ?? false;
    _businessRelated =
        existing?.businessRelated ?? initialCategory?.businessDefault ?? false;
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
    final quickCategories = widget.categories
        .where((item) => item.type == _type)
        .take(8)
        .toList(growable: false);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 20),
      child: Form(
        key: _formKey,
        child: ListView(
          shrinkWrap: true,
          children: [
            Row(
              children: [
                _IconBox(
                  icon: widget.transaction == null
                      ? Icons.add_card_rounded
                      : Icons.edit_outlined,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.transaction == null
                        ? 'Add transaction'
                        : 'Edit transaction',
                    style: _titleStyle(size: 22),
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
              onSelectionChanged: (selection) =>
                  setState(() => _type = selection.first),
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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: quickCategories
                  .map(
                    (category) => ActionChip(
                      label: Text(category.title),
                      onPressed: () {
                        setState(() {
                          _categoryController.text = category.title;
                          _taxRelevant = category.isTaxRelevant;
                          _businessRelated = category.businessDefault;
                        });
                      },
                    ),
                  )
                  .toList(growable: false),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _categoryController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: _type == ExpenseTransactionType.income
                    ? 'Income category'
                    : 'Expense category',
                prefixIcon: const Icon(Icons.category_outlined),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Category is required.'
                  : null,
            ),
            const SizedBox(height: 12),
            ExpansionTile(
              initiallyExpanded: _advanced,
              onExpansionChanged: (value) => setState(() => _advanced = value),
              tilePadding: EdgeInsets.zero,
              title: Text('Advanced details', style: _titleStyle(size: 15)),
              children: [
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _accountController.text.trim().isEmpty
                      ? 'Cash'
                      : _accountController.text.trim(),
                  decoration: const InputDecoration(
                    labelText: 'Account',
                    prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'Bank', child: Text('Bank')),
                    DropdownMenuItem(value: 'Card', child: Text('Card')),
                    DropdownMenuItem(value: 'Wallet', child: Text('Wallet')),
                  ],
                  onChanged: (value) {
                    if (value != null) _accountController.text = value;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _paymentMethodController.text.trim().isEmpty
                      ? 'Cash'
                      : _paymentMethodController.text.trim(),
                  decoration: const InputDecoration(
                    labelText: 'Payment method',
                    prefixIcon: Icon(Icons.credit_card_rounded),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                    DropdownMenuItem(value: 'Card', child: Text('Card')),
                    DropdownMenuItem(
                      value: 'Bank Transfer',
                      child: Text('Bank Transfer'),
                    ),
                    DropdownMenuItem(
                      value: 'Wallet',
                      child: Text('Wallet / Digital Wallet'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) _paymentMethodController.text = value;
                  },
                ),
                const SizedBox(height: 12),
                _DatePickerTile(date: _selectedDate, onTap: _pickDate),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _merchantController,
                  decoration: const InputDecoration(
                    labelText: 'Merchant optional',
                    prefixIcon: Icon(Icons.storefront_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _noteController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Note optional',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
                if (widget.receiptEnabled) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _pickReceipt,
                    icon: const Icon(Icons.attach_file_rounded),
                    label: Text(
                      _selectedReceiptFile?.name ??
                          (_receiptController.text.trim().isEmpty
                              ? 'Attach receipt'
                              : 'Replace attached receipt'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _selectedReceiptFile == null
                        ? 'Upload JPG, PNG, WEBP or PDF receipt with this transaction.'
                        : 'Selected receipt will upload when you save.',
                    style: _bodyStyle().copyWith(fontSize: 12),
                  ),
                ],
                const SizedBox(height: 10),
                SwitchListTile.adaptive(
                  value: _taxRelevant,
                  onChanged: (value) => setState(() => _taxRelevant = value),
                  title: const Text('Useful for tax'),
                ),
                SwitchListTile.adaptive(
                  value: _businessRelated,
                  onChanged: (value) =>
                      setState(() => _businessRelated = value),
                  title: const Text('Business expense'),
                ),
                SwitchListTile.adaptive(
                  value: _recurring,
                  onChanged: (value) => setState(() => _recurring = value),
                  title: const Text('Recurring'),
                ),
                SwitchListTile.adaptive(
                  value: _reimbursable,
                  onChanged: (value) => setState(() => _reimbursable = value),
                  title: const Text('Reimbursable'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            AppButton(
              label: widget.transaction == null
                  ? 'Save transaction'
                  : 'Update transaction',
              icon: Icons.check_rounded,
              onPressed: _save,
            ),
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
    setState(
      () => _selectedDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
      ),
    );
  }

  Future<void> _pickReceipt() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;

    setState(() {
      _selectedReceiptFile = result.files.first;
    });
  }

  Future<void> _save() async {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    final existing = widget.transaction;
    final transaction = ExpenseTransaction(
      id: existing?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      type: _type,
      amount: double.parse(_amountController.text.replaceAll(',', '').trim()),
      category: _categoryController.text.trim(),
      account: _accountController.text.trim().isEmpty
          ? 'Cash'
          : _accountController.text.trim(),
      paymentMethod: _paymentMethodController.text.trim().isEmpty
          ? 'Cash'
          : _paymentMethodController.text.trim(),
      merchant: _merchantController.text.trim().isEmpty
          ? null
          : _merchantController.text.trim(),
      date: _selectedDate,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      taxRelevant: _taxRelevant,
      businessRelated: _businessRelated,
      recurring: _recurring,
      reimbursable: _reimbursable,
      receiptFile: _receiptController.text.trim().isEmpty
          ? null
          : _receiptController.text.trim(),
      createdFromGuest: existing?.createdFromGuest ?? false,
      synced: existing?.synced ?? false,
    );

    final saved = await widget.onSave(transaction);

    final receipt = _selectedReceiptFile;
    if (receipt != null && widget.onAttachReceipt != null) {
      await widget.onAttachReceipt!(saved, receipt);
    }

    if (!mounted) return;
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
        decoration: const InputDecoration(
          labelText: 'Date',
          prefixIcon: Icon(Icons.calendar_month_outlined),
        ),
        child: Text(
          DateFormat('dd MMM yyyy').format(date),
          style: _titleStyle(size: 14),
        ),
      ),
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
        color: AppTheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.10)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.primary,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
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
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(size >= 40 ? 15 : 12),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.08)),
      ),
      child: Icon(icon, color: AppTheme.primary, size: size >= 40 ? 22 : 18),
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
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: double.infinity,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: 150,
                        height: 11,
                        decoration: BoxDecoration(
                          color: Theme.of(
                            context,
                          ).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
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
  return TextStyle(
    color: AppTheme.textPrimary,
    fontSize: size,
    fontWeight: FontWeight.w900,
  );
}

TextStyle _bodyStyle({double size = 12}) {
  return TextStyle(
    color: AppTheme.textSecondary,
    fontSize: size,
    height: 1.35,
    fontWeight: FontWeight.w600,
  );
}

IconData _iconForCategory(String value) {
  final text = value.toLowerCase();
  if (text.contains('food')) return Icons.restaurant_outlined;
  if (text.contains('fuel')) return Icons.local_gas_station_outlined;
  if (text.contains('bill') || text.contains('util')) {
    return Icons.receipt_long_outlined;
  }
  if (text.contains('rent')) return Icons.home_work_outlined;
  if (text.contains('shop')) return Icons.shopping_bag_outlined;
  if (text.contains('transport')) return Icons.directions_car_outlined;
  if (text.contains('health')) return Icons.health_and_safety_outlined;
  if (text.contains('education')) return Icons.school_outlined;
  if (text.contains('business')) return Icons.business_center_outlined;
  if (text.contains('tax') || text.contains('legal')) {
    return Icons.gavel_outlined;
  }
  if (text.contains('salary') || text.contains('income')) {
    return Icons.payments_outlined;
  }
  return Icons.category_outlined;
}

String _money(double value) {
  return NumberFormat.currency(
    locale: 'en_PK',
    symbol: 'PKR ',
    decimalDigits: 0,
  ).format(value);
}
