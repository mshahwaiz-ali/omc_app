import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/design_tokens.dart';
import '../../../app/providers/core_providers.dart';
import '../../../app/providers/effective_capabilities_provider.dart';
import '../../../app/theme.dart';
import '../../../core/diagnostics/omc_widget_keys.dart';
import '../../../core/forms/dirty_form_controller.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/app_back_header.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_empty_state.dart';
import '../../auth/application/auth_state.dart';
import '../data/expense_export.dart';
import '../data/expense_tracker_repository.dart';
import '../domain/expense_transaction.dart';
import 'expense_tracker_screen.dart'
    show expenseTrackerConfigProvider, expenseTransactionsProvider;

class ExpenseTrackerV2Screen extends ConsumerWidget {
  const ExpenseTrackerV2Screen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capabilities = ref.watch(effectiveCapabilitiesProvider);
    final accessMode = _resolveAccessMode(capabilities);
    final config =
        ref.watch(expenseTrackerConfigProvider).value ??
        ExpenseTrackerConfig.fallback();
    final transactionsAsync = ref.watch(expenseTransactionsProvider);
    final storageMode =
        ref.watch(expenseTrackerStorageModeProvider).value ??
        ExpenseTrackerStorageMode.localOnly;
    final canUseCloud =
        accessMode == ExpenseTrackerAccessMode.approvedSync &&
        config.syncAvailable;
    final shouldSync =
        canUseCloud && storageMode == ExpenseTrackerStorageMode.syncWithAccount;
    final effectiveAccessMode =
        accessMode == ExpenseTrackerAccessMode.approvedSync && !shouldSync
        ? ExpenseTrackerAccessMode.offlineApproved
        : accessMode;

    if (accessMode == ExpenseTrackerAccessMode.internalHidden) {
      return Scaffold(
        key: OmcWidgetKeys.expenseScreen,
        appBar: const AppBackHeader(
          title: 'Expense Tracker',
          fallbackRoute: '/home',
        ),
        body: const SafeArea(
          top: false,
          child: PremiumEmptyState(
            icon: Icons.admin_panel_settings_outlined,
            title: 'Customer tracker hidden',
            message:
                'Internal users use the internal workspace for customer review. Personal customer tracking is hidden by default.',
          ),
        ),
      );
    }

    return Scaffold(
      key: OmcWidgetKeys.expenseScreen,
      backgroundColor: AppTheme.background,
      appBar: AppBackHeader(
        title: 'Expense Tracker',
        subtitle: 'Income, expenses and tax-ready records',
        fallbackRoute: '/home',
        action: PopupMenuButton<String>(
          tooltip: 'Expense tracker data tools',
          icon: const Icon(Icons.more_horiz_rounded),
          onSelected: (value) async {
            final transactions =
                transactionsAsync.value ?? const <ExpenseTransaction>[];

            if (value == 'export') {
              if (shouldSync) {
                await _exportCloud(context, ref);
              } else {
                _showExportDialog(context, transactions);
              }
              return;
            }
            if (value == 'import') {
              _showImportDialog(context, ref);
              return;
            }
            if (value == 'clear') {
              _confirmClearAll(context, ref);
              return;
            }
            if (value == 'storage_local') {
              await ref
                  .read(expenseTrackerStorageModeProvider.notifier)
                  .setMode(ExpenseTrackerStorageMode.localOnly);
              await ref
                  .read(expenseTransactionsProvider.notifier)
                  .reloadLocal();
              return;
            }
            if (value == 'storage_sync') {
              await ref
                  .read(expenseTrackerStorageModeProvider.notifier)
                  .setMode(ExpenseTrackerStorageMode.syncWithAccount);
              await ref.read(expenseTransactionsProvider.notifier).bulkSync();
              return;
            }
            if (value == 'refresh') {
              if (shouldSync) {
                ref.invalidate(expenseCloudPageProvider);
              } else {
                ref.read(expenseTransactionsProvider.notifier).reloadLocal();
              }
              return;
            }
            if (value == 'sync') {
              ref.read(expenseTransactionsProvider.notifier).bulkSync();
            }
          },
          itemBuilder: (context) => [
            if (canUseCloud && !shouldSync)
              const PopupMenuItem(
                value: 'storage_sync',
                child: Text('Enable account sync'),
              ),
            if (canUseCloud && shouldSync)
              const PopupMenuItem(
                value: 'storage_local',
                child: Text('Use local-only storage'),
              ),
            PopupMenuItem(
              value: 'refresh',
              child: Text(
                shouldSync ? 'Load cloud data' : 'Refresh local data',
              ),
            ),
            const PopupMenuDivider(),
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
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'clear',
              child: Text('Clear local data'),
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: shouldSync
            ? _CloudLedgerView(
                accessMode: effectiveAccessMode,
                config: config,
                onAdd: () => _showTransactionSheet(
                  context,
                  ref,
                  accessMode: effectiveAccessMode,
                  config: config,
                  sync: true,
                ),
                onEdit: (transaction) => _showTransactionSheet(
                  context,
                  ref,
                  accessMode: effectiveAccessMode,
                  config: config,
                  sync: true,
                  transaction: transaction,
                ),
                onDelete: (id) =>
                    _confirmDeleteTransaction(context, ref, id, sync: true),
              )
            : transactionsAsync.when(
                loading: () => const _TrackerLoadingView(),
                error: (_, _) => Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: PremiumEmptyState(
                    icon: Icons.account_balance_wallet_outlined,
                    title: 'Tracker unavailable',
                    message: 'Local expense data could not be loaded.',
                    actionLabel: 'Retry',
                    onAction: () => ref
                        .read(expenseTransactionsProvider.notifier)
                        .reloadLocal(),
                  ),
                ),
                data: (transactions) => _LocalLedgerView(
                  accessMode: effectiveAccessMode,
                  config: config,
                  transactions: transactions,
                  onManualEntry: () => _showTransactionSheet(
                    context,
                    ref,
                    accessMode: effectiveAccessMode,
                    config: config,
                    sync: shouldSync,
                  ),
                  onQuickAdd: (category) => _showTransactionSheet(
                    context,
                    ref,
                    accessMode: effectiveAccessMode,
                    config: config,
                    sync: shouldSync,
                    initialCategory: category,
                  ),
                  onSync: shouldSync
                      ? () => ref
                            .read(expenseTransactionsProvider.notifier)
                            .bulkSync()
                      : null,
                  onEdit: (transaction) => _showTransactionSheet(
                    context,
                    ref,
                    accessMode: effectiveAccessMode,
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
    if (capabilities.isInternal) {
      return ExpenseTrackerAccessMode.offlineApproved;
    }
    if (capabilities.isApproved) return ExpenseTrackerAccessMode.approvedSync;
    if (capabilities.isPending) return ExpenseTrackerAccessMode.pendingLocal;
    return ExpenseTrackerAccessMode.guestLocal;
  }

  Future<void> _showTransactionSheet(
    BuildContext context,
    WidgetRef ref, {
    required ExpenseTrackerAccessMode accessMode,
    required ExpenseTrackerConfig config,
    required bool sync,
    ExpenseTrackerCategory? initialCategory,
    ExpenseTransaction? transaction,
  }) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _TransactionSheet(
        transaction: transaction,
        categories: config.categories,
        initialCategory: initialCategory,
        receiptEnabled: sync && config.receiptUploadAvailable,
        onAttachReceipt: sync && config.receiptUploadAvailable
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
    if (context.mounted) ref.invalidate(expenseCloudPageProvider);
  }

  Future<void> _exportCloud(BuildContext context, WidgetRef ref) async {
    final repository = ref.read(expenseTrackerRepositoryProvider);
    final progress = ValueNotifier<int>(0);
    final cancellation = CancelToken();
    var cancelled = false;
    final epoch = ref.read(sessionEpochProvider);
    bool isCancelled() =>
        cancelled ||
        !context.mounted ||
        ref.read(sessionEpochProvider) != epoch;
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Export account history'),
          content: ValueListenableBuilder<int>(
            valueListenable: progress,
            builder: (_, count, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LinearProgressIndicator(),
                const SizedBox(height: AppSpacing.md),
                Text('$count records prepared'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                cancelled = true;
                cancellation.cancel('Expense export cancelled');
              },
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
    final dialog = navigator.push(route);
    try {
      await exportExpensePages(
        repository.syncedPages(
          cancelToken: cancellation,
          shouldCancel: isCancelled,
        ),
        isCancelled: isCancelled,
        onProgress: (count) => progress.value = count,
      );
    } catch (_) {
      if (!isCancelled() && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Export was not completed. No partial backup was shared. Please retry.',
            ),
          ),
        );
      }
    } finally {
      cancellation.cancel('Expense export finished');
      if (navigator.mounted && route.isActive) {
        navigator.removeRoute(route);
      }
      await dialog;
      progress.dispose();
    }
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
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.formMaxWidth),
          child: SingleChildScrollView(
            child: SelectableText(
              encoded,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
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
    var importing = false;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Import backup JSON'),
          content: SizedBox(
            width: AppLayout.formMaxWidth,
            child: TextField(
              controller: controller,
              minLines: 8,
              maxLines: 12,
              enabled: !importing,
              decoration: const InputDecoration(
                labelText: 'Backup JSON',
                hintText: 'Paste exported JSON here...',
                alignLabelWithHint: true,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: importing
                  ? null
                  : () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: importing
                  ? null
                  : () async {
                      if (importing) return;

                      late final List<ExpenseTransaction> transactions;
                      try {
                        final decoded = jsonDecode(controller.text.trim());
                        if (decoded is! List) {
                          throw const FormatException('Backup must be a list.');
                        }
                        final parsed = <ExpenseTransaction>[];
                        final seenIds = <String>{};
                        for (var index = 0; index < decoded.length; index++) {
                          final raw = decoded[index];
                          if (raw is! Map) {
                            throw FormatException(
                              'Entry ${index + 1} must be a transaction object.',
                            );
                          }
                          final data = Map<String, dynamic>.from(raw);
                          final rawId =
                              data['id'] ?? data['name'] ?? data['sync_id'];
                          if (rawId?.toString().trim().isEmpty ?? true) {
                            throw FormatException(
                              'Entry ${index + 1} is missing a transaction ID.',
                            );
                          }
                          final rawType =
                              (data['transaction_type'] ?? data['type'])
                                  ?.toString()
                                  .trim()
                                  .toLowerCase();
                          if (rawType != 'income' && rawType != 'expense') {
                            throw FormatException(
                              'Entry ${index + 1} has an invalid transaction type.',
                            );
                          }
                          final rawAmount = double.tryParse(
                            data['amount']?.toString() ?? '',
                          );
                          if (rawAmount == null || rawAmount <= 0) {
                            throw FormatException(
                              'Entry ${index + 1} must have an amount greater than zero.',
                            );
                          }
                          final rawDate =
                              data['date'] ?? data['transaction_date'];
                          if (DateTime.tryParse(rawDate?.toString() ?? '') ==
                              null) {
                            throw FormatException(
                              'Entry ${index + 1} has an invalid transaction date.',
                            );
                          }
                          if (data['category']?.toString().trim().isEmpty ??
                              true) {
                            throw FormatException(
                              'Entry ${index + 1} is missing a category.',
                            );
                          }
                          final transaction = ExpenseTransaction.fromJson(data);
                          if (!seenIds.add(transaction.id)) {
                            throw FormatException(
                              'Duplicate transaction ID: ${transaction.id}.',
                            );
                          }
                          parsed.add(transaction);
                        }
                        transactions = List<ExpenseTransaction>.unmodifiable(
                          parsed,
                        );
                      } on FormatException catch (error) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              error.message.toString().trim().isEmpty
                                  ? 'Invalid backup JSON. Please check format.'
                                  : error.message.toString(),
                            ),
                          ),
                        );
                        return;
                      } catch (_) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Invalid backup JSON. Please check format.',
                            ),
                          ),
                        );
                        return;
                      }

                      setDialogState(() => importing = true);
                      try {
                        await ref
                            .read(expenseTransactionsProvider.notifier)
                            .replaceAll(transactions);

                        if (!dialogContext.mounted || !context.mounted) return;
                        Navigator.of(dialogContext).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Imported ${transactions.length} transactions.',
                            ),
                          ),
                        );
                      } catch (error) {
                        if (!context.mounted) return;
                        final failure = AppFailureClassifier.classify(
                          error,
                          fallbackTitle: 'Import not completed',
                          fallbackMessage:
                              'The backup was valid, but its transactions could not be saved right now.',
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(failure.message)),
                        );
                      } finally {
                        if (dialogContext.mounted) {
                          setDialogState(() => importing = false);
                        }
                      }
                    },
              child: importing
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Importing...'),
                      ],
                    )
                  : const Text('Import'),
            ),
          ],
        ),
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

    if (shouldDelete != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(expenseTransactionsProvider.notifier)
          .remove(id, sync: sync);
      if (!context.mounted) return;
      ref.invalidate(expenseCloudPageProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Transaction archived.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Transaction not archived',
        fallbackMessage:
            'The transaction could not be archived right now. No local data was removed.',
      );
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
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
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (shouldClear != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(expenseTransactionsProvider.notifier).clearAll();
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('Local tracker cleared.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Local data not cleared',
        fallbackMessage:
            'Local expense data could not be cleared right now. Your records remain available.',
      );
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    }
  }
}

class _LocalLedgerView extends StatefulWidget {
  const _LocalLedgerView({
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
  State<_LocalLedgerView> createState() => _LocalLedgerViewState();
}

class _LocalLedgerViewState extends State<_LocalLedgerView> {
  _TrackerPeriod _period = _TrackerPeriod.thisMonth;
  String _category = _allCategories;
  static const _allCategories = '__all__';

  @override
  Widget build(BuildContext context) {
    final periodTransactions = _filterByPeriod(widget.transactions);
    final categories =
        periodTransactions
            .map((item) => item.category.trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final filteredTransactions = periodTransactions
        .where((item) {
          return _category == _allCategories ||
              item.category.trim() == _category;
        })
        .toList(growable: false);
    final allStats = _TrackerStats.fromTransactions(widget.transactions);
    final periodStats = _TrackerStats.fromTransactions(periodTransactions);
    final quickCategories = widget.config.categories
        .where((item) => item.isExpense || item.isIncome)
        .take(8)
        .toList(growable: false);

    return RefreshIndicator.adaptive(
      onRefresh: () async {
        // The owning controller remains authoritative for local reload.
        // A pull gesture is intentionally visual-only here; header Refresh
        // retains the established repository reload operation.
      },
      notificationPredicate: (_) => false,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          _FinancialSummary(stats: allStats),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: widget.onManualEntry,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add transaction'),
            ),
          ),
          if (quickCategories.isNotEmpty) ...[
            const SizedBox(height: 8),
            _QuickAddExpansion(
              categories: quickCategories,
              onSelected: widget.onQuickAdd,
            ),
          ],
          const SizedBox(height: 22),
          const _SectionTitle(
            title: 'Transactions',
            supporting: 'Filter the ledger without changing stored records.',
          ),
          const SizedBox(height: 10),
          _LedgerFilters(
            period: _period,
            category: _category,
            categories: categories,
            allCategoryValue: _allCategories,
            onPeriodChanged: (value) {
              setState(() {
                _period = value;
                _category = _allCategories;
              });
            },
            onCategoryChanged: (value) => setState(() => _category = value),
          ),
          const SizedBox(height: 12),
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
              title: 'No transactions for these filters',
              message: 'Choose another period or category.',
            )
          else
            for (
              var index = 0;
              index < filteredTransactions.length;
              index++
            ) ...[
              _TransactionRow(
                transaction: filteredTransactions[index],
                onEdit: () => widget.onEdit(filteredTransactions[index]),
                onDelete: () => widget.onDelete(filteredTransactions[index].id),
              ),
              if (index != filteredTransactions.length - 1)
                const Divider(height: 1),
            ],
          if (periodTransactions.isNotEmpty) ...[
            const SizedBox(height: 18),
            _PeriodSummaryExpansion(
              title: _period.label,
              stats: periodStats,
              transactions: periodTransactions,
            ),
          ],
          const SizedBox(height: 18),
          _TaxRecordExpansion(stats: allStats),
          const SizedBox(height: 18),
          _StorageStatusCard(
            mode: widget.accessMode,
            count: widget.transactions.length,
            guestLimit: widget.config.guestLimit,
            onSync: widget.onSync,
          ),
        ],
      ),
    );
  }

  List<ExpenseTransaction> _filterByPeriod(
    List<ExpenseTransaction> transactions,
  ) {
    final now = DateTime.now();
    return transactions
        .where((item) {
          if (_period == _TrackerPeriod.all) return true;
          if (_period == _TrackerPeriod.thisMonth) {
            return item.date.year == now.year && item.date.month == now.month;
          }
          final lastMonth = DateTime(now.year, now.month - 1);
          return item.date.year == lastMonth.year &&
              item.date.month == lastMonth.month;
        })
        .toList(growable: false);
  }
}

enum _TrackerPeriod {
  thisMonth('This month'),
  lastMonth('Last month'),
  all('All');

  const _TrackerPeriod(this.label);
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

class _FinancialSummary extends StatelessWidget {
  const _FinancialSummary({required this.stats});
  final _TrackerStats stats;

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context).scale(1);
    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stack = constraints.maxWidth < 350 || textScaler > 1.3;
          final income = _FinancialValue(
            label: 'Income',
            value: _money(stats.income),
            icon: Icons.south_west_rounded,
          );
          final expenses = _FinancialValue(
            label: 'Expenses',
            value: _money(stats.expenses),
            icon: Icons.north_east_rounded,
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Balance',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _money(stats.balance),
                style: Theme.of(context).textTheme.amount,
              ),
              const SizedBox(height: 6),
              Text(
                '${stats.transactionCount} saved transaction${stats.transactionCount == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 18),
              if (stack) ...[
                income,
                const Divider(height: 20),
                expenses,
              ] else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: income),
                    const SizedBox(width: 20),
                    Expanded(child: expenses),
                  ],
                ),
            ],
          );
        },
      ),
    );
  }
}

class _FinancialValue extends StatelessWidget {
  const _FinancialValue({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 2),
              Text(value, style: Theme.of(context).textTheme.amountSecondary),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickAddExpansion extends StatelessWidget {
  const _QuickAddExpansion({
    required this.categories,
    required this.onSelected,
  });
  final List<ExpenseTrackerCategory> categories;
  final ValueChanged<ExpenseTrackerCategory> onSelected;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: const Text('Quick add by category'),
        subtitle: const Text('Optional shortcut to prefill a transaction'),
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: categories
                  .map(
                    (category) => ActionChip(
                      avatar: Icon(_iconForCategory(category.title), size: 18),
                      label: Text(category.title),
                      onPressed: () => onSelected(category),
                    ),
                  )
                  .toList(growable: false),
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerFilters extends StatelessWidget {
  const _LedgerFilters({
    required this.period,
    required this.category,
    required this.categories,
    required this.allCategoryValue,
    required this.onPeriodChanged,
    required this.onCategoryChanged,
  });

  final _TrackerPeriod period;
  final String category;
  final List<String> categories;
  final String allCategoryValue;
  final ValueChanged<_TrackerPeriod> onPeriodChanged;
  final ValueChanged<String> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _MenuFilter<_TrackerPeriod>(
          label: 'Period',
          valueLabel: period.label,
          values: _TrackerPeriod.values,
          itemLabel: (value) => value.label,
          onSelected: onPeriodChanged,
        ),
        _MenuFilter<String>(
          label: 'Category',
          valueLabel: category == allCategoryValue
              ? 'All categories'
              : category,
          values: [allCategoryValue, ...categories],
          itemLabel: (value) =>
              value == allCategoryValue ? 'All categories' : value,
          onSelected: onCategoryChanged,
        ),
      ],
    );
  }
}

class _MenuFilter<T> extends StatelessWidget {
  const _MenuFilter({
    required this.label,
    required this.valueLabel,
    required this.values,
    required this.itemLabel,
    required this.onSelected,
  });
  final String label;
  final String valueLabel;
  final List<T> values;
  final String Function(T value) itemLabel;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<T>(
      tooltip: '$label filter: $valueLabel',
      onSelected: onSelected,
      itemBuilder: (context) => values
          .map(
            (value) =>
                PopupMenuItem<T>(value: value, child: Text(itemLabel(value))),
          )
          .toList(growable: false),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  valueLabel,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
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
    final amount = '${isIncome ? '+' : '-'}${_money(transaction.amount)}';
    final textScaler = MediaQuery.textScalerOf(context).scale(1);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 350 || textScaler > 1.3;
          final amountWidget = Text(
            amount,
            textAlign: stacked ? TextAlign.start : TextAlign.end,
            style: Theme.of(context).textTheme.amountSecondary.copyWith(
              color: isIncome ? AppTheme.success : AppTheme.textPrimary,
            ),
          );

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.cardSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  isIncome
                      ? Icons.south_west_rounded
                      : _iconForCategory(transaction.category),
                  color: AppTheme.textSecondary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (stacked) ...[
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 5),
                      amountWidget,
                    ] else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Flexible(child: amountWidget),
                        ],
                      ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Text(
                          DateFormat('dd MMM yyyy').format(transaction.date),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          '· ${transaction.account}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          '· ${transaction.paymentMethod}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                    if ((transaction.note ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        transaction.note!.trim(),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (transaction.taxRelevant)
                          const _MetaChip(label: 'Tax relevant'),
                        if (transaction.businessRelated)
                          const _MetaChip(label: 'Business'),
                        if ((transaction.receiptFile ?? '').trim().isNotEmpty)
                          const _MetaChip(label: 'Receipt attached'),
                        if (transaction.synced)
                          const _MetaChip(label: 'Synced'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              PopupMenuButton<String>(
                tooltip: 'Transaction actions',
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'archive') onDelete();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'archive', child: Text('Archive')),
                ],
                icon: const Icon(Icons.more_vert_rounded),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.processingSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _PeriodSummaryExpansion extends StatelessWidget {
  const _PeriodSummaryExpansion({
    required this.title,
    required this.stats,
    required this.transactions,
  });
  final String title;
  final _TrackerStats stats;
  final List<ExpenseTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    final totals = <String, double>{};
    for (final transaction in transactions.where((item) => item.isExpense)) {
      totals.update(
        transaction.category,
        (value) => value + transaction.amount,
        ifAbsent: () => transaction.amount,
      );
    }
    final rows = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text('$title summary'),
          subtitle: Text('${stats.transactionCount} ledger entries'),
          children: [
            _KeyValue(label: 'Income', value: _money(stats.income)),
            _KeyValue(label: 'Expenses', value: _money(stats.expenses)),
            _KeyValue(
              label: 'Balance',
              value: _money(stats.balance),
              strong: true,
            ),
            if (rows.isNotEmpty) ...[
              const Divider(height: 22),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Expense categories',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 8),
              for (final row in rows.take(5))
                _KeyValue(label: row.key, value: _money(row.value)),
            ],
          ],
        ),
      ),
    );
  }
}

class _TaxRecordExpansion extends StatelessWidget {
  const _TaxRecordExpansion({required this.stats});
  final _TrackerStats stats;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: const Text('Tax record summary'),
          subtitle: Text(
            '${stats.readinessLabel} · score ${stats.readinessScore}',
          ),
          children: [
            _KeyValue(
              label: 'Tax-relevant expenses',
              value: _money(stats.taxRelevantTotal),
            ),
            _KeyValue(
              label: 'Business expenses',
              value: _money(stats.businessTotal),
            ),
            _KeyValue(
              label: 'Receipts attached',
              value: '${stats.receiptsAttached}',
            ),
            _KeyValue(
              label: 'Recurring entries',
              value: '${stats.recurringCount}',
            ),
          ],
        ),
      ),
    );
  }
}

class _StorageStatusCard extends StatelessWidget {
  const _StorageStatusCard({
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
        'Entries and receipts sync with your OMC account',
      ),
      ExpenseTrackerAccessMode.offlineApproved => (
        Icons.phone_iphone_rounded,
        'Local-only tracker',
        'Entries stay safely on this device',
      ),
      _ => (
        Icons.lock_outline_rounded,
        'Tracker unavailable',
        'This account cannot use the customer tracker',
      ),
    };

    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.cardSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(data.$1, size: 22, color: AppTheme.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.$2, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(data.$3, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
          if (mode == ExpenseTrackerAccessMode.approvedSync && onSync != null)
            IconButton(
              tooltip: 'Sync local entries',
              onPressed: onSync,
              icon: const Icon(Icons.sync_rounded),
            ),
        ],
      ),
    );
  }
}

class _CloudLedgerView extends ConsumerStatefulWidget {
  const _CloudLedgerView({
    required this.accessMode,
    required this.config,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final ExpenseTrackerAccessMode accessMode;
  final ExpenseTrackerConfig config;
  final VoidCallback onAdd;
  final ValueChanged<ExpenseTransaction> onEdit;
  final ValueChanged<String> onDelete;

  @override
  ConsumerState<_CloudLedgerView> createState() => _CloudLedgerViewState();
}

class _CloudLedgerViewState extends ConsumerState<_CloudLedgerView> {
  int start = 0;
  DateTime? month;

  @override
  Widget build(BuildContext context) {
    final provider = expenseCloudPageProvider((
      start: start,
      month: month == null ? null : DateFormat('yyyy-MM-01').format(month!),
    ));
    final data = ref.watch(provider);
    final local =
        ref.watch(expenseTransactionsProvider).value ??
        const <ExpenseTransaction>[];
    final pending = local.where((entry) => !entry.synced).toList();

    return data.when(
      loading: () => const _TrackerLoadingView(),
      error: (error, _) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          PremiumEmptyState(
            icon: Icons.cloud_off_outlined,
            title: 'Cloud history unavailable',
            message:
                'Retry when connected. Local and pending records remain on this device.',
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(provider),
          ),
          if (pending.isNotEmpty) ...[
            const SizedBox(height: 16),
            _PendingLocalCard(
              pending: pending,
              onSync: () => _syncPending(context),
            ),
          ],
        ],
      ),
      data: (page) => RefreshIndicator.adaptive(
        onRefresh: () async {
          ref.invalidate(provider);
          await ref.read(provider.future);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            _CloudFinancialSummary(page: page, month: month),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: widget.onAdd,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add transaction'),
              ),
            ),
            const SizedBox(height: 22),
            const _SectionTitle(
              title: 'Transactions',
              supporting: 'Cloud account history from the selected scope.',
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: () => setState(() {
                    start = 0;
                    month = null;
                  }),
                  child: const Text('All history'),
                ),
                OutlinedButton(
                  onPressed: () => setState(() {
                    start = 0;
                    month = DateTime.now();
                  }),
                  child: const Text('This month'),
                ),
                OutlinedButton(
                  onPressed: () => setState(() {
                    start = 0;
                    final now = month ?? DateTime.now();
                    month = DateTime(now.year, now.month - 1);
                  }),
                  child: const Text('Earlier month'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (page.entries.isEmpty)
              const PremiumEmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No entries in this period',
                message: 'Choose another account-history period.',
              )
            else
              for (var index = 0; index < page.entries.length; index++) ...[
                _TransactionRow(
                  transaction: page.entries[index],
                  onEdit: () => widget.onEdit(page.entries[index]),
                  onDelete: () => widget.onDelete(page.entries[index].id),
                ),
                if (index != page.entries.length - 1) const Divider(height: 1),
              ],
            const SizedBox(height: 14),
            _Pager(
              start: start,
              nextStart: page.nextStart,
              onPrevious: start == 0
                  ? null
                  : () => setState(() => start = (start - 100).clamp(0, start)),
              onNext: page.nextStart == null
                  ? null
                  : () => setState(() => start = page.nextStart!),
            ),
            if (pending.isNotEmpty) ...[
              const SizedBox(height: 18),
              _PendingLocalCard(
                pending: pending,
                onSync: () => _syncPending(context),
              ),
            ],
            const SizedBox(height: 18),
            _StorageStatusCard(
              mode: widget.accessMode,
              count: local.length,
              guestLimit: widget.config.guestLimit,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _syncPending(BuildContext context) async {
    try {
      await ref.read(expenseTransactionsProvider.notifier).bulkSync();
      ref.invalidate(expenseCloudPageProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Sync was not completed. Local entries were preserved.',
            ),
          ),
        );
      }
    }
  }
}

class _CloudFinancialSummary extends StatelessWidget {
  const _CloudFinancialSummary({required this.page, required this.month});
  final ExpenseCloudPage page;
  final DateTime? month;

  @override
  Widget build(BuildContext context) {
    final scope = month == null
        ? 'Complete account totals'
        : DateFormat('MMMM yyyy').format(month!);
    final balance = _summaryText(page.summary['balance']);
    final income = _summaryText(page.summary['income']);
    final expenses = _summaryText(page.summary['expenses']);
    final count = _summaryText(page.summary['transaction_count']);

    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(scope, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 5),
          Text(balance, style: Theme.of(context).textTheme.amount),
          const SizedBox(height: 4),
          Text(
            '$count cloud records in this scope. Pending local entries are excluded from these totals.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 18),
          _KeyValue(label: 'Income', value: income),
          _KeyValue(label: 'Expenses', value: expenses),
        ],
      ),
    );
  }
}

class _PendingLocalCard extends StatelessWidget {
  const _PendingLocalCard({required this.pending, required this.onSync});
  final List<ExpenseTransaction> pending;
  final VoidCallback onSync;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${pending.length} local entr${pending.length == 1 ? 'y' : 'ies'} waiting to sync',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          Text(
            'These records remain local until the account sync confirms them.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onSync,
            icon: const Icon(Icons.sync_rounded),
            label: const Text('Sync pending entries'),
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < pending.length; index++) ...[
            _KeyValue(
              label: pending[index].category,
              value: _money(pending[index].amount),
            ),
          ],
        ],
      ),
    );
  }
}

class _Pager extends StatelessWidget {
  const _Pager({
    required this.start,
    required this.nextStart,
    required this.onPrevious,
    required this.onNext,
  });
  final int start;
  final int? nextStart;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: onPrevious,
            child: const Text('Previous'),
          ),
        ),
        const SizedBox(width: 12),
        Text('Page ${start ~/ 100 + 1}'),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(onPressed: onNext, child: const Text('Next')),
        ),
      ],
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
  final _dirtyFormController = DirtyFormController();
  bool _isSaving = false;
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

  void _markDirty() => _dirtyFormController.markDirty();

  @override
  void dispose() {
    _amountController.dispose();
    _categoryController.dispose();
    _accountController.dispose();
    _paymentMethodController.dispose();
    _merchantController.dispose();
    _noteController.dispose();
    _receiptController.dispose();
    _dirtyFormController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final quickCategories = widget.categories
        .where((item) => item.type == _type)
        .take(8)
        .toList(growable: false);

    return UnsavedChangesGuard(
      controller: _dirtyFormController,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppLayout.formMaxWidth),
            child: Material(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.sheet),
              ),
              clipBehavior: Clip.antiAlias,
              child: Form(
                key: _formKey,
                onChanged: _markDirty,
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.border,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      widget.transaction == null
                          ? 'Add transaction'
                          : 'Edit transaction',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Save the financial entry first; optional receipt upload follows the existing account-sync rules.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 18),
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
                        _markDirty();
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
                    if (quickCategories.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: quickCategories
                            .map(
                              (category) => ActionChip(
                                label: Text(category.title),
                                onPressed: () {
                                  _markDirty();
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
                    ],
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _categoryController,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: _type == ExpenseTransactionType.income
                            ? 'Income category'
                            : 'Expense category',
                        prefixIcon: const Icon(Icons.category_outlined),
                      ),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                          ? 'Category is required.'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    Theme(
                      data: Theme.of(
                        context,
                      ).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        initiallyExpanded: _advanced,
                        onExpansionChanged: (value) =>
                            setState(() => _advanced = value),
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: EdgeInsets.zero,
                        title: const Text('Advanced details'),
                        subtitle: const Text(
                          'Account, payment method, date, receipt and tax flags',
                        ),
                        children: [
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _accountController.text.trim().isEmpty
                                ? 'Cash'
                                : _accountController.text.trim(),
                            decoration: const InputDecoration(
                              labelText: 'Account',
                              prefixIcon: Icon(
                                Icons.account_balance_wallet_outlined,
                              ),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Cash',
                                child: Text('Cash'),
                              ),
                              DropdownMenuItem(
                                value: 'Bank',
                                child: Text('Bank'),
                              ),
                              DropdownMenuItem(
                                value: 'Card',
                                child: Text('Card'),
                              ),
                              DropdownMenuItem(
                                value: 'Wallet',
                                child: Text('Wallet'),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              _markDirty();
                              _accountController.text = value;
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue:
                                _paymentMethodController.text.trim().isEmpty
                                ? 'Cash'
                                : _paymentMethodController.text.trim(),
                            decoration: const InputDecoration(
                              labelText: 'Payment method',
                              prefixIcon: Icon(Icons.credit_card_rounded),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'Cash',
                                child: Text('Cash'),
                              ),
                              DropdownMenuItem(
                                value: 'Card',
                                child: Text('Card'),
                              ),
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
                              if (value == null) return;
                              _markDirty();
                              _paymentMethodController.text = value;
                            },
                          ),
                          const SizedBox(height: 12),
                          _DatePickerField(
                            date: _selectedDate,
                            onTap: _pickDate,
                          ),
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
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                          const SizedBox(height: 10),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            value: _taxRelevant,
                            onChanged: (value) {
                              _markDirty();
                              setState(() => _taxRelevant = value);
                            },
                            title: const Text('Useful for tax'),
                          ),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            value: _businessRelated,
                            onChanged: (value) {
                              _markDirty();
                              setState(() => _businessRelated = value);
                            },
                            title: const Text('Business expense'),
                          ),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            value: _recurring,
                            onChanged: (value) {
                              _markDirty();
                              setState(() => _recurring = value);
                            },
                            title: const Text('Recurring'),
                          ),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            value: _reimbursable,
                            onChanged: (value) {
                              _markDirty();
                              setState(() => _reimbursable = value);
                            },
                            title: const Text('Reimbursable'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    AppButton(
                      label: widget.transaction == null
                          ? 'Save transaction'
                          : 'Update transaction',
                      icon: Icons.check_rounded,
                      isLoading: _isSaving,
                      onPressed: _isSaving ? null : _save,
                    ),
                  ],
                ),
              ),
            ),
          ),
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
    _markDirty();
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

    _markDirty();
    setState(() {
      _selectedReceiptFile = result.files.first;
    });
  }

  Future<void> _save() async {
    if (_isSaving) return;

    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) return;

    FocusScope.of(context).unfocus();
    _dirtyFormController.beginSubmitting();
    setState(() => _isSaving = true);

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

    try {
      final saved = await widget.onSave(transaction);
      final receipt = _selectedReceiptFile;
      if (receipt != null && widget.onAttachReceipt != null) {
        await widget.onAttachReceipt!(saved, receipt);
      }

      if (!mounted) return;
      _dirtyFormController.submissionSucceeded();
      Navigator.of(context).pop();
    } catch (error) {
      _dirtyFormController.submissionFailed();
      if (!mounted) return;

      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Transaction not saved',
        fallbackMessage:
            'The transaction could not be saved right now. Your entered details were retained.',
      );
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(failure.message)));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({required this.date, required this.onTap});
  final DateTime date;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Date',
          prefixIcon: Icon(Icons.calendar_month_outlined),
        ),
        child: Text(
          DateFormat('dd MMM yyyy').format(date),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.supporting});
  final String title;
  final String? supporting;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        if (supporting?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 4),
          Text(supporting!, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ],
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

class _TrackerLoadingView extends StatelessWidget {
  const _TrackerLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
      children: [
        PremiumCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SkeletonLine(width: 90, height: 14),
              const SizedBox(height: 10),
              const _SkeletonLine(height: 28),
              const SizedBox(height: 18),
              const _SkeletonLine(height: 18),
              const SizedBox(height: 10),
              const _SkeletonLine(width: 180, height: 18),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (var index = 0; index < 4; index++) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                _SkeletonBox(),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SkeletonLine(height: 16),
                      SizedBox(height: 8),
                      _SkeletonLine(width: 150, height: 13),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (index != 3) const Divider(height: 1),
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

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
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

String _summaryText(Object? value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? '-' : text;
}
