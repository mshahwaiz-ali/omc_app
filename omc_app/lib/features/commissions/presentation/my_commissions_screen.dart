import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/app_labeled_field.dart';
import '../../../core/widgets/premium_card.dart';
import '../data/commission_repository.dart';

class MyCommissionsScreen extends ConsumerStatefulWidget {
  const MyCommissionsScreen({super.key});

  @override
  ConsumerState<MyCommissionsScreen> createState() =>
      _MyCommissionsScreenState();
}

class _MyCommissionsScreenState extends ConsumerState<MyCommissionsScreen> {
  final _items = <CommissionEarning>[];
  final _periodController = TextEditingController();
  final _customerController = TextEditingController();
  final _serviceController = TextEditingController();
  List<CommissionSummary> _summaries = const [];
  String _status = '';
  bool _loading = true;
  bool _hasMore = false;
  int _nextStart = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load(refresh: true);
  }

  @override
  void dispose() {
    _periodController.dispose();
    _customerController.dispose();
    _serviceController.dispose();
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) {
      _items.clear();
      _nextStart = 0;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (refresh) {
        _summaries = await ref.read(commissionSummaryLoaderProvider)(
          periodMonth: _periodController.text.trim(),
        );
      }
      final page = await ref.read(commissionPageLoaderProvider)(
        start: _nextStart,
        limit: 20,
        periodMonth: _periodController.text.trim(),
        status: _status,
        customerProfile: _customerController.text.trim(),
        service: _serviceController.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _hasMore = page.hasMore;
        _nextStart = page.nextStart;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  bool get _hasFilters =>
      _periodController.text.trim().isNotEmpty ||
      _customerController.text.trim().isNotEmpty ||
      _serviceController.text.trim().isNotEmpty ||
      _status.isNotEmpty;

  void _clearFilters() {
    _periodController.clear();
    _customerController.clear();
    _serviceController.clear();
    setState(() => _status = '');
    _load(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('My commissions')),
      body: RefreshIndicator.adaptive(
        onRefresh: () => _load(refresh: true),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final inset = AppLayout.pageInsetFor(constraints.maxWidth);
            final horizontal =
                constraints.maxWidth > AppLayout.generalMaxWidth + inset * 2
                ? (constraints.maxWidth - AppLayout.generalMaxWidth) / 2
                : inset;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                horizontal,
                16,
                horizontal,
                AppSpacing.xl,
              ),
              children: [
                Text(
                  'Commission totals',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Amounts remain separated by currency.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (_summaries.isEmpty && !_loading)
                  Text(
                    'No commission summary is available for the selected period.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  )
                else
                  for (var index = 0; index < _summaries.length; index++) ...[
                    _CurrencySummary(summary: _summaries[index]),
                    if (index != _summaries.length - 1)
                      const SizedBox(height: AppSpacing.sm),
                  ],
                const SizedBox(height: AppSpacing.xl),
                _CommissionFilters(
                  periodController: _periodController,
                  customerController: _customerController,
                  serviceController: _serviceController,
                  status: _status,
                  onStatusChanged: (value) => setState(() => _status = value),
                  apply: () => _load(refresh: true),
                  clear: _clearFilters,
                  hasFilters: _hasFilters,
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'Earnings',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      _hasMore
                          ? '${_items.length} loaded · more available'
                          : '${_items.length} loaded',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                if (_error != null)
                  _ErrorCard(
                    message: _error!,
                    retry: () => _load(refresh: true),
                  ),
                if (!_loading && _items.isEmpty && _error == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppSpacing.xl,
                    ),
                    child: Text(
                      _hasFilters
                          ? 'No commission earnings match the current filters.'
                          : 'No commission earnings yet.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                for (var index = 0; index < _items.length; index++) ...[
                  _CommissionRow(item: _items[index]),
                  if (index != _items.length - 1)
                    const SizedBox(height: AppSpacing.sm),
                ],
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(AppSpacing.xl),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (!_loading && _hasMore) ...[
                  const SizedBox(height: AppSpacing.md),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _load,
                      child: const Text('Load more earnings'),
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

class _CurrencySummary extends StatelessWidget {
  const _CurrencySummary({required this.summary});

  final CommissionSummary summary;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            summary.currency,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          LayoutBuilder(
            builder: (context, constraints) {
              final textScale = MediaQuery.textScalerOf(context).scale(1);
              final stack = constraints.maxWidth < 360 || textScale >= 1.5;
              final outstanding = _AmountValue(
                label: 'Outstanding',
                currency: summary.currency,
                value: summary.outstanding,
              );
              final settled = _AmountValue(
                label: 'Settled',
                currency: summary.currency,
                value: summary.settled,
              );
              if (stack) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    outstanding,
                    const SizedBox(height: AppSpacing.md),
                    settled,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: outstanding),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(child: settled),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AmountValue extends StatelessWidget {
  const _AmountValue({
    required this.label,
    required this.currency,
    required this.value,
  });

  final String label;
  final String currency;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          '$currency ${value.toStringAsFixed(2)}',
          style: Theme.of(context).textTheme.amountSecondary,
        ),
      ],
    );
  }
}

class _CommissionFilters extends StatelessWidget {
  const _CommissionFilters({
    required this.periodController,
    required this.customerController,
    required this.serviceController,
    required this.status,
    required this.onStatusChanged,
    required this.apply,
    required this.clear,
    required this.hasFilters,
  });

  final TextEditingController periodController;
  final TextEditingController customerController;
  final TextEditingController serviceController;
  final String status;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback apply;
  final VoidCallback clear;
  final bool hasFilters;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        childrenPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        title: Text(
          hasFilters ? 'Filters applied' : 'Filters',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Text(
          _filterSummary(),
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
        ),
        children: [
          AppLabeledField(
            label: 'Status',
            child: DropdownButtonFormField<String>(
              initialValue: status,
              isExpanded: true,
              decoration: const InputDecoration(),
              items: const [
                DropdownMenuItem(value: '', child: Text('All statuses')),
                DropdownMenuItem(value: 'Earned', child: Text('Outstanding')),
                DropdownMenuItem(value: 'Settled', child: Text('Settled')),
                DropdownMenuItem(value: 'Reversed', child: Text('Reversed')),
              ],
              onChanged: (value) => onStatusChanged(value ?? ''),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppLabeledField(
            label: 'Earned month',
            child: TextField(
              controller: periodController,
              decoration: const InputDecoration(hintText: 'YYYY-MM'),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppLabeledField(
            label: 'Customer profile',
            child: TextField(
              controller: customerController,
              decoration: const InputDecoration(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppLabeledField(
            label: 'Service',
            child: TextField(
              controller: serviceController,
              decoration: const InputDecoration(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              TextButton(onPressed: clear, child: const Text('Clear')),
              FilledButton(
                onPressed: apply,
                child: const Text('Apply filters'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _filterSummary() {
    final values = <String>[
      if (status.isNotEmpty) status,
      if (periodController.text.trim().isNotEmpty) periodController.text.trim(),
      if (customerController.text.trim().isNotEmpty) 'Customer',
      if (serviceController.text.trim().isNotEmpty) 'Service',
    ];
    return values.isEmpty ? 'All commission earnings' : values.join(' · ');
  }
}

class _CommissionRow extends StatelessWidget {
  const _CommissionRow({required this.item});

  final CommissionEarning item;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () =>
          context.push('/my-commissions/${Uri.encodeComponent(item.id)}'),
      semanticLabel:
          '${item.currency} ${item.amount.toStringAsFixed(2)}. ${item.status}. ${item.customer}. ${item.serviceLabel}. Open commission details.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  '${item.currency} ${item.amount.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.amountSecondary,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _StatusBadge(label: item.status),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(item.customer, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            item.serviceLabel,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            item.earnedOn,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final normalized = label.trim().toLowerCase();
    final (color, background) = switch (normalized) {
      'settled' => (AppTheme.success, AppTheme.successSoft),
      'reversed' => (AppTheme.danger, AppTheme.dangerSoft),
      _ => (AppTheme.processing, AppTheme.processingSoft),
    };
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.retry});

  final String message;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Commissions unavailable',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(onPressed: retry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
