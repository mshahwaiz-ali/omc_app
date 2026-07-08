import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/tax_calculation_repository.dart';

class TaxCalculationHistoryScreen extends ConsumerWidget {
  const TaxCalculationHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(taxCalculationRepositoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tax Estimate History')),
      body: FutureBuilder<List<TaxCalculationHistoryItem>>(
        future: repository.getHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _StateMessage(
              icon: Icons.error_outline_rounded,
              title: 'History unavailable',
              message: _friendlyError(snapshot.error),
            );
          }

          final items = snapshot.data ?? const <TaxCalculationHistoryItem>[];
          if (items.isEmpty) {
            return const _StateMessage(
              icon: Icons.history_rounded,
              title: 'No saved estimates yet',
              message: 'Calculate tax while logged in to save estimates here when backend logging is enabled.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(taxCalculationRepositoryProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) => _HistoryCard(item: items[index]),
            ),
          );
        },
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.item});

  final TaxCalculationHistoryItem item;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.65)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    item.taxYear.isEmpty ? 'Saved tax estimate' : item.taxYear,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ),
                if (item.linkedServiceRequest.trim().isNotEmpty)
                  const Icon(Icons.task_alt_rounded, size: 18),
              ],
            ),
            if (item.createdOn.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(item.createdOn, style: Theme.of(context).textTheme.bodySmall),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Chip(label: item.incomeType.isEmpty ? 'Income' : item.incomeType),
                _Chip(label: item.filerStatus.isEmpty ? 'Filer Status' : item.filerStatus),
              ],
            ),
            const SizedBox(height: 14),
            _KeyValue(label: 'Annual Income', value: _formatMoney(item.annualIncome)),
            _KeyValue(label: 'Estimated Annual Tax', value: _formatMoney(item.estimatedAnnualTax), strong: true),
            _KeyValue(label: 'Monthly Tax', value: _formatMoney(item.monthlyTax)),
            _KeyValue(label: 'Effective Rate', value: '${item.effectiveTaxRate.toStringAsFixed(2)}%'),
            if (item.linkedServiceRequest.trim().isNotEmpty) ...[
              const Divider(height: 20),
              _KeyValue(label: 'Linked Service Request', value: item.linkedServiceRequest, strong: true),
            ],
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: Theme.of(context).colorScheme.onSecondaryContainer, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue({required this.label, required this.value, this.strong = false});

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(fontWeight: strong ? FontWeight.w900 : FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({required this.icon, required this.title, required this.message});

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 46),
            const SizedBox(height: 14),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

String _formatMoney(double value) {
  final rounded = value.round().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < rounded.length; index++) {
    final positionFromEnd = rounded.length - index;
    buffer.write(rounded[index]);
    if (positionFromEnd > 1 && positionFromEnd % 3 == 1) buffer.write(',');
  }
  return 'PKR ${buffer.toString()}';
}

String _friendlyError(Object? error) {
  final text = error?.toString().trim() ?? '';
  if (text.isEmpty) return 'Something went wrong. Please try again.';
  return text.replaceFirst('Exception: ', '').replaceFirst('DioException [bad response]: ', '');
}
