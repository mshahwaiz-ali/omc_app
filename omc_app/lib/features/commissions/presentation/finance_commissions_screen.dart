import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/design_tokens.dart';
import '../../../app/theme.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/premium_card.dart';
import '../data/finance_commission_repository.dart';

class FinanceCommissionsScreen extends ConsumerStatefulWidget {
  const FinanceCommissionsScreen({super.key});

  @override
  ConsumerState<FinanceCommissionsScreen> createState() =>
      _FinanceCommissionsScreenState();
}

class _FinanceCommissionsScreenState
    extends ConsumerState<FinanceCommissionsScreen> {
  static const _statuses = <String>[
    '',
    'Calculated',
    'Held',
    'Approved',
    'Payable',
    'Paid',
    'Rejected',
    'Reversed',
  ];

  final _searchController = TextEditingController();
  final _items = <FinanceCommissionAllocation>[];
  String _status = '';
  String _evidenceStatus = '';
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int? _nextStart;
  String? _error;
  String? _mutatingId;

  @override
  void initState() {
    super.initState();
    _load(refresh: true);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) {
      _items.clear();
      _nextStart = 0;
    }
    if (refresh) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      if (_loadingMore || !_hasMore || _nextStart == null) return;
      setState(() => _loadingMore = true);
    }

    try {
      final page = await ref
          .read(financeCommissionRepositoryProvider)
          .fetchPage(
            start: refresh ? 0 : (_nextStart ?? 0),
            limit: 20,
            status: _status,
            evidenceStatus: _evidenceStatus,
            search: _searchController.text,
          );
      if (!mounted) return;
      setState(() {
        final seen = _items.map((item) => item.id).toSet();
        _items.addAll(page.items.where((item) => seen.add(item.id)));
        _hasMore = page.hasMore;
        _nextStart = page.nextStart;
      });
    } on ApiError catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _error = 'Commission operations could not be loaded right now.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _runMutation({
    required FinanceCommissionAllocation allocation,
    required Future<void> Function() action,
    required String success,
  }) async {
    if (_mutatingId != null) return;
    setState(() => _mutatingId = allocation.id);
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success)));
      await _load(refresh: true);
    } on ApiError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Commission action could not be completed right now.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _mutatingId = null);
    }
  }

  Future<void> _approve(FinanceCommissionAllocation allocation) async {
    final confirmed = await _confirm(
      title: 'Approve commission?',
      message:
          'Approval is allowed only while the backend confirms matched accounting evidence.',
      actionLabel: 'Approve',
    );
    if (!confirmed || !mounted) return;
    await _runMutation(
      allocation: allocation,
      action: () =>
          ref.read(financeCommissionRepositoryProvider).approve(allocation.id),
      success: 'Commission approved.',
    );
  }

  Future<void> _reject(FinanceCommissionAllocation allocation) async {
    final reason = await _reasonDialog();
    if (!mounted || reason == null) return;
    await _runMutation(
      allocation: allocation,
      action: () => ref
          .read(financeCommissionRepositoryProvider)
          .reject(allocationId: allocation.id, reason: reason),
      success: 'Commission rejected.',
    );
  }

  Future<void> _markPayable(FinanceCommissionAllocation allocation) async {
    final confirmed = await _confirm(
      title: 'Mark commission payable?',
      message:
          'This records that the approved commission is ready for external settlement.',
      actionLabel: 'Mark payable',
    );
    if (!confirmed || !mounted) return;
    await _runMutation(
      allocation: allocation,
      action: () => ref
          .read(financeCommissionRepositoryProvider)
          .markPayable(allocation.id),
      success: 'Commission marked payable.',
    );
  }

  Future<void> _markPaid(FinanceCommissionAllocation allocation) async {
    final input = await showModalBottomSheet<_SettlementInput>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => const _SettlementSheet(),
    );
    if (!mounted || input == null) return;
    await _runMutation(
      allocation: allocation,
      action: () => ref
          .read(financeCommissionRepositoryProvider)
          .markPaid(
            allocationId: allocation.id,
            settlementReference: input.reference,
            settledOn: input.settledOn,
          ),
      success: 'Commission marked paid.',
    );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String actionLabel,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(actionLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<String?> _reasonDialog() async {
    final controller = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Reject commission'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('A rejection reason is required for the audit trail.'),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: controller,
                  autofocus: true,
                  minLines: 3,
                  maxLines: 6,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    labelText: 'Reason',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: controller.text.trim().isEmpty
                  ? null
                  : () => Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('Reject'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Commission operations')),
      body: RefreshIndicator.adaptive(
        onRefresh: () => _load(refresh: true),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final inset = AppLayout.pageInsetFor(constraints.maxWidth);
            final horizontal = constraints.maxWidth >
                    AppLayout.generalMaxWidth + inset * 2
                ? (constraints.maxWidth - AppLayout.generalMaxWidth) / 2
                : inset;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: EdgeInsets.fromLTRB(horizontal, 14, horizontal, 100),
              children: [
                const _FinanceHeader(),
                const SizedBox(height: AppSpacing.xl),
                TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _load(refresh: true),
                  decoration: InputDecoration(
                    labelText: 'Search commission queue',
                    hintText: 'Beneficiary, customer, request or component',
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: IconButton(
                      tooltip: 'Search',
                      onPressed: () => _load(refresh: true),
                      icon: const Icon(Icons.arrow_forward_rounded),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      for (final status in _statuses) ...[
                        ChoiceChip(
                          label: Text(status.isEmpty ? 'All' : status),
                          selected: _status == status,
                          onSelected: (_) {
                            setState(() => _status = status);
                            _load(refresh: true);
                          },
                        ),
                        if (status != _statuses.last)
                          const SizedBox(width: AppSpacing.xs),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<String>(
                  initialValue: _evidenceStatus,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Accounting evidence',
                    prefixIcon: Icon(Icons.verified_outlined),
                  ),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('All evidence states')),
                    DropdownMenuItem(
                      value: 'Matched',
                      child: Text('Accounting ready'),
                    ),
                    DropdownMenuItem(
                      value: 'Review Required',
                      child: Text('Needs reconciliation review'),
                    ),
                    DropdownMenuItem(
                      value: 'Missing',
                      child: Text('Evidence missing'),
                    ),
                    DropdownMenuItem(
                      value: 'Quarantined',
                      child: Text('Reconciliation blocked'),
                    ),
                    DropdownMenuItem(value: 'Reversed', child: Text('Reversed')),
                  ],
                  onChanged: (value) {
                    setState(() => _evidenceStatus = value ?? '');
                    _load(refresh: true);
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Allocation queue',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  _hasMore
                      ? '${_items.length} allocations loaded · more available'
                      : '${_items.length} allocations loaded',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (_error != null)
                  _QueueMessage(
                    icon: Icons.cloud_off_rounded,
                    message: _error!,
                    actionLabel: 'Retry',
                    onAction: () => _load(refresh: true),
                  ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_items.isEmpty && _error == null)
                  const _QueueMessage(
                    icon: Icons.inbox_outlined,
                    message: 'No commission allocations match this queue.',
                  )
                else
                  for (var index = 0; index < _items.length; index++) ...[
                    _CommissionOperationCard(
                      allocation: _items[index],
                      busy: _mutatingId == _items[index].id,
                      onApprove: () => _approve(_items[index]),
                      onReject: () => _reject(_items[index]),
                      onMarkPayable: () => _markPayable(_items[index]),
                      onMarkPaid: () => _markPaid(_items[index]),
                    ),
                    if (index != _items.length - 1)
                      const SizedBox(height: AppSpacing.sm),
                  ],
                if (!_loading && _hasMore) ...[
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _loadingMore ? null : () => _load(),
                      icon: _loadingMore
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.expand_more_rounded),
                      label: Text(
                        _loadingMore
                            ? 'Loading allocations'
                            : 'Load more allocations',
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FinanceHeader extends StatelessWidget {
  const _FinanceHeader();

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Commission lifecycle',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Review allocations, make approved items payable, and record external settlement evidence. Accounting and ERP records remain authoritative.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommissionOperationCard extends StatelessWidget {
  const _CommissionOperationCard({
    required this.allocation,
    required this.busy,
    required this.onApprove,
    required this.onReject,
    required this.onMarkPayable,
    required this.onMarkPaid,
  });

  final FinanceCommissionAllocation allocation;
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onMarkPayable;
  final VoidCallback onMarkPaid;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(allocation.status);
    final evidenceColor = allocation.accountingReady
        ? AppTheme.success
        : allocation.evidenceStatus == 'Reversed'
        ? AppTheme.processing
        : AppTheme.warning;
    final title = allocation.serviceTitle.isNotEmpty
        ? allocation.serviceTitle
        : allocation.component.isNotEmpty
        ? allocation.component
        : 'Commission allocation';
    final beneficiary = allocation.beneficiary.isNotEmpty
        ? allocation.beneficiary
        : allocation.beneficiaryUser;
    final actions = <Widget>[
      if (allocation.canApprove)
        FilledButton.icon(
          onPressed: busy ? null : onApprove,
          icon: const Icon(Icons.check_rounded),
          label: const Text('Approve'),
        ),
      if (allocation.canReject)
        OutlinedButton.icon(
          onPressed: busy ? null : onReject,
          icon: const Icon(Icons.close_rounded),
          label: const Text('Reject'),
        ),
      if (allocation.canMarkPayable)
        FilledButton.tonalIcon(
          onPressed: busy ? null : onMarkPayable,
          icon: const Icon(Icons.payments_outlined),
          label: const Text('Mark payable'),
        ),
      if (allocation.canMarkPaid)
        FilledButton.icon(
          onPressed: busy ? null : onMarkPaid,
          icon: const Icon(Icons.verified_rounded),
          label: const Text('Record paid'),
        ),
    ];

    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _money(allocation.currency, allocation.commissionAmount),
            style: Theme.of(context).textTheme.amountSecondary,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            beneficiary.isEmpty ? allocation.id : beneficiary,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _StateBadge(
                label: allocation.status.isEmpty
                    ? 'Calculated'
                    : allocation.status,
                color: statusColor,
              ),
              _StateBadge(
                label: _evidenceLabel(allocation.evidenceStatus),
                color: evidenceColor,
              ),
            ],
          ),
          if (!allocation.accountingReady &&
              (allocation.status == 'Calculated' ||
                  allocation.status == 'Held' ||
                  allocation.status == 'Approved' ||
                  allocation.status == 'Payable')) ...[
            const SizedBox(height: AppSpacing.sm),
            const _InlineNotice(
              icon: Icons.account_balance_outlined,
              message:
                  'Accounting evidence needs reconciliation before this allocation can move forward.',
            ),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Permitted next transition',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: actions,
            ),
          ],
          if (busy) ...[
            const SizedBox(height: AppSpacing.sm),
            const LinearProgressIndicator(minHeight: 2),
          ],
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Divider(height: 1),
          ),
          Text('Record details', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          _MetaLine(
            label: 'Customer',
            value: allocation.customerName.isEmpty
                ? 'Not linked'
                : allocation.customerName,
          ),
          _MetaLine(
            label: 'Service request',
            value: allocation.serviceRequest.isEmpty
                ? 'Not linked'
                : allocation.serviceRequest,
          ),
          _MetaLine(
            label: 'Basis',
            value: _money(allocation.currency, allocation.basisAmount),
          ),
          if (allocation.commissionPercent > 0)
            _MetaLine(
              label: 'Frozen rate',
              value: '${allocation.commissionPercent.toStringAsFixed(2)}%',
            ),
          if (allocation.earnedOn.isNotEmpty)
            _MetaLine(label: 'Earned on', value: allocation.earnedOn),
          if (allocation.settlementReference.isNotEmpty)
            _MetaLine(
              label: 'Settlement reference',
              value: allocation.settlementReference,
            ),
          if (allocation.rejectionReason.isNotEmpty)
            _InlineNotice(
              icon: Icons.info_outline_rounded,
              message: 'Rejected: ${allocation.rejectionReason}',
            ),
          if (allocation.reversalReason.isNotEmpty)
            _InlineNotice(
              icon: Icons.history_rounded,
              message: 'Reversed: ${allocation.reversalReason}',
            ),
        ],
      ),
    );
  }
}

class _SettlementInput {
  const _SettlementInput({required this.reference, this.settledOn});

  final String reference;
  final String? settledOn;
}

class _SettlementSheet extends StatefulWidget {
  const _SettlementSheet();

  @override
  State<_SettlementSheet> createState() => _SettlementSheetState();
}

class _SettlementSheetState extends State<_SettlementSheet> {
  final _referenceController = TextEditingController();
  DateTime? _date;

  @override
  void dispose() {
    _referenceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg + bottomInset,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Record external settlement',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'OMC records the external accounting/payment reference here. This action does not create a Journal Entry.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _referenceController,
            autofocus: true,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Settlement reference',
              hintText: 'Bank transfer, payment voucher or accounting ref',
              prefixIcon: Icon(Icons.receipt_long_outlined),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () async {
              final selected = await showDatePicker(
                context: context,
                initialDate: _date ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now().add(const Duration(days: 30)),
              );
              if (selected != null) setState(() => _date = selected);
            },
            icon: const Icon(Icons.event_outlined),
            label: Text(
              _date == null
                  ? 'Settlement date: backend default'
                  : 'Settlement date: ${DateFormat('dd MMM yyyy').format(_date!)}',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _referenceController.text.trim().isEmpty
                  ? null
                  : () => Navigator.of(context).pop(
                        _SettlementInput(
                          reference: _referenceController.text.trim(),
                          settledOn: _date == null
                              ? null
                              : DateFormat('yyyy-MM-dd').format(_date!),
                        ),
                      ),
              child: const Text('Record commission paid'),
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueMessage extends StatelessWidget {
  const _QueueMessage({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Icon(icon, size: 32, color: AppTheme.textSecondary),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = constraints.maxWidth < 420 || textScale >= 1.5;
        final labelWidget = Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondary,
          ),
        );
        final valueWidget = SelectableText(
          value,
          style: Theme.of(context).textTheme.bodyMedium,
        );
        if (stack) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                labelWidget,
                const SizedBox(height: AppSpacing.xxs),
                valueWidget,
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 130, child: labelWidget),
              const SizedBox(width: AppSpacing.sm),
              Expanded(child: valueWidget),
            ],
          ),
        );
      },
    );
  }
}

class _InlineNotice extends StatelessWidget {
  const _InlineNotice({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppTheme.cardSoft,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppTheme.textSecondary),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
      ),
    );
  }
}

Color _statusColor(String status) {
  switch (status.trim().toLowerCase()) {
    case 'paid':
      return AppTheme.success;
    case 'payable':
      return AppTheme.info;
    case 'approved':
      return AppTheme.info;
    case 'rejected':
    case 'reversed':
      return AppTheme.danger;
    case 'held':
      return AppTheme.warning;
    default:
      return AppTheme.processing;
  }
}

String _evidenceLabel(String evidence) {
  switch (evidence.trim().toLowerCase()) {
    case 'matched':
      return 'Accounting ready';
    case 'review required':
      return 'Needs reconciliation';
    case 'missing':
      return 'Evidence missing';
    case 'quarantined':
      return 'Reconciliation blocked';
    case 'reversed':
      return 'Evidence reversed';
    default:
      return 'Evidence unverified';
  }
}

String _money(String currency, double amount) {
  return '$currency ${NumberFormat('#,##0.00').format(amount)}';
}
