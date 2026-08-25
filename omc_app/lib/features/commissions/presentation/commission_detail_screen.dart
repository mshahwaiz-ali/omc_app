import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/commission_repository.dart';

final commissionDetailProvider =
    FutureProvider.family<CommissionEarning, String>((ref, id) {
      return ref.watch(commissionRepositoryProvider).fetchOne(id);
    });

class CommissionDetailScreen extends ConsumerWidget {
  const CommissionDetailScreen({super.key, required this.earningId});
  final String earningId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final value = ref.watch(commissionDetailProvider(earningId));
    return Scaffold(
      appBar: AppBar(title: const Text('Commission details')),
      body: value.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(error.toString()),
          ),
        ),
        data: (item) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _row(context, 'Status', item.status),
            _row(context, 'Origin', item.provenance),
            _row(
              context,
              'Amount',
              '${item.currency} ${item.amount.toStringAsFixed(2)}',
            ),
            _row(
              context,
              'Commission basis',
              '${item.currency} ${item.basis.toStringAsFixed(2)}',
            ),
            _row(context, 'Frozen rate', '${item.percent.toStringAsFixed(2)}%'),
            if (item.component.isNotEmpty)
              _row(context, 'Component', item.component),
            if (item.structureSnapshot.isNotEmpty)
              _row(context, 'Structure snapshot', item.structureSnapshot),
            _row(context, 'Customer', item.customer),
            if (item.service.isNotEmpty) _row(context, 'Service', item.service),
            if (item.request.isNotEmpty)
              _row(context, 'Service request', item.request),
            if (item.paymentEntry.isNotEmpty)
              _row(context, 'Payment Entry', item.paymentEntry),
            if (item.salesInvoice.isNotEmpty)
              _row(context, 'Sales Invoice', item.salesInvoice),
            if (item.legacyJournalEntry.isNotEmpty)
              _row(
                context,
                'Legacy accounting evidence',
                item.legacyJournalEntry,
              ),
            if (item.evidenceStatus.isNotEmpty)
              _row(context, 'Evidence status', item.evidenceStatus),
            _row(context, 'Earned on', item.earnedOn),
            if (item.settlement.isNotEmpty)
              _row(context, 'Settlement', item.settlement),
            if (item.reversalReason.isNotEmpty)
              _row(context, 'Reversal reason', item.reversalReason),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          SelectableText(value.isEmpty ? 'Not available' : value),
        ],
      ),
    ),
  );
}
