import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design_tokens.dart';
import '../../../app/providers/core_providers.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/premium_card.dart';
import '../data/commission_repository.dart';

final commissionDetailProvider = FutureProvider.autoDispose
    .family<CommissionEarning, String>((ref, id) {
      ref.watch(sessionEpochProvider);
      return ref.watch(commissionRepositoryProvider).fetchOne(id);
    });

class CommissionDetailScreen extends ConsumerWidget {
  const CommissionDetailScreen({super.key, required this.earningId});

  final String earningId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(commissionDetailProvider(earningId));
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Commission details')),
      body: value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Commission unavailable',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  onPressed: () =>
                      ref.invalidate(commissionDetailProvider(earningId)),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
        data: (item) => _CommissionDetailBody(item: item),
      ),
    );
  }
}

class _CommissionDetailBody extends StatelessWidget {
  const _CommissionDetailBody({required this.item});

  final CommissionEarning item;

  @override
  Widget build(BuildContext context) {
    final basisRows = <(String, String)>[
      ('Commission basis', '${item.currency} ${item.basis.toStringAsFixed(2)}'),
      ('Frozen rate', '${item.percent.toStringAsFixed(2)}%'),
      ('Customer', item.customer),
      if (item.service.isNotEmpty) ('Service', item.service),
      if (item.request.isNotEmpty) ('Service request', item.request),
      if (item.component.isNotEmpty) ('Component', item.component),
      if (item.structureSnapshot.isNotEmpty)
        ('Structure snapshot', item.structureSnapshot),
      ('Earned on', item.earnedOn),
    ];
    final evidenceRows = <(String, String)>[
      ('Origin', item.provenance),
      if (item.paymentEntry.isNotEmpty) ('Payment Entry', item.paymentEntry),
      if (item.salesInvoice.isNotEmpty) ('Sales Invoice', item.salesInvoice),
      if (item.legacyJournalEntry.isNotEmpty)
        ('Legacy accounting evidence', item.legacyJournalEntry),
      if (item.evidenceStatus.isNotEmpty)
        ('Evidence status', item.evidenceStatus),
      if (item.settlement.isNotEmpty) ('Settlement', item.settlement),
      if (item.reversalReason.isNotEmpty)
        ('Reversal reason', item.reversalReason),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final inset = AppLayout.pageInsetFor(constraints.maxWidth);
        final horizontal = constraints.maxWidth >
                AppLayout.generalMaxWidth + inset * 2
            ? (constraints.maxWidth - AppLayout.generalMaxWidth) / 2
            : inset;
        return ListView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 60),
          children: [
            _AmountCard(item: item),
            const SizedBox(height: AppSpacing.lg),
            _GroupedRows(title: 'Commission basis', rows: basisRows),
            const SizedBox(height: AppSpacing.lg),
            _GroupedRows(
              title: 'Accounting & settlement evidence',
              rows: evidenceRows,
              emptyMessage: 'No additional accounting evidence is available.',
            ),
          ],
        );
      },
    );
  }
}

class _AmountCard extends StatelessWidget {
  const _AmountCard({required this.item});

  final CommissionEarning item;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Commission amount',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          SelectableText(
            '${item.currency} ${item.amount.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.amount,
          ),
          const SizedBox(height: AppSpacing.sm),
          _StatusBadge(label: item.status),
        ],
      ),
    );
  }
}

class _GroupedRows extends StatelessWidget {
  const _GroupedRows({
    required this.title,
    required this.rows,
    this.emptyMessage,
  });

  final String title;
  final List<(String, String)> rows;
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          if (rows.isEmpty)
            Text(
              emptyMessage ?? 'Not available',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
              ),
            )
          else
            for (var index = 0; index < rows.length; index++) ...[
              _KeyValueRow(label: rows[index].$1, value: rows[index].$2),
              if (index != rows.length - 1)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Divider(height: 1),
                ),
            ],
        ],
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow({required this.label, required this.value});

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
          value.isEmpty ? 'Not available' : value,
          style: Theme.of(context).textTheme.bodyMedium,
        );
        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              labelWidget,
              const SizedBox(height: AppSpacing.xxs),
              valueWidget,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 150, child: labelWidget),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: valueWidget),
          ],
        );
      },
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
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
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
      ),
    );
  }
}
