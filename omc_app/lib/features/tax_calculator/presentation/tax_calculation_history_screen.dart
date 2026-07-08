import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/premium_card.dart';
import '../data/tax_calculation_repository.dart';

class TaxCalculationHistoryScreen extends ConsumerStatefulWidget {
  const TaxCalculationHistoryScreen({super.key});

  @override
  ConsumerState<TaxCalculationHistoryScreen> createState() =>
      _TaxCalculationHistoryScreenState();
}

class _TaxCalculationHistoryScreenState
    extends ConsumerState<TaxCalculationHistoryScreen> {
  late Future<List<TaxCalculationHistoryItem>> _future;

  @override
  void initState() {
    super.initState();
    _future = _loadHistory();
  }

  Future<List<TaxCalculationHistoryItem>> _loadHistory() {
    return ref.read(taxCalculationRepositoryProvider).getHistory();
  }

  void _reload() {
    setState(() {
      _future = _loadHistory();
    });
  }

  String _money(double value) {
    final rounded = value.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < rounded.length; i++) {
      final positionFromEnd = rounded.length - i;
      buffer.write(rounded[i]);
      if (positionFromEnd > 1 && positionFromEnd % 3 == 1) buffer.write(',');
    }
    return 'PKR $buffer';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: FutureBuilder<List<TaxCalculationHistoryItem>>(
        future: _future,
        builder: (context, snapshot) {
          final items = snapshot.data ?? const <TaxCalculationHistoryItem>[];
          return ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 112),
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Tax Estimates',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Your saved calculator estimates from OMC backend.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              if (snapshot.connectionState == ConnectionState.waiting)
                const PremiumCard(
                  padding: EdgeInsets.all(22),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      SizedBox(width: 14),
                      Expanded(child: Text('Loading tax estimate history...')),
                    ],
                  ),
                )
              else if (snapshot.hasError)
                PremiumCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Unable to load estimate history.',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(
                        onPressed: _reload,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              else if (items.isEmpty)
                const PremiumCard(
                  padding: EdgeInsets.all(22),
                  child: Column(
                    children: [
                      Icon(
                        Icons.history_rounded,
                        color: AppTheme.primaryRed,
                        size: 38,
                      ),
                      SizedBox(height: 12),
                      Text(
                        'No saved estimates yet',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Calculate tax while logged in to save estimates here.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              else
                for (final item in items) ...[
                  _HistoryCard(item: item, money: _money),
                  const SizedBox(height: 12),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.item, required this.money});

  final TaxCalculationHistoryItem item;
  final String Function(double value) money;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.receipt_long_outlined,
                  color: AppTheme.primaryRed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${item.incomeType} · ${item.filerStatus}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _HistoryRow(label: 'Annual income', value: money(item.annualIncome)),
          _HistoryRow(label: 'Annual tax', value: money(item.estimatedAnnualTax)),
          _HistoryRow(label: 'Monthly tax', value: money(item.monthlyTax)),
          _HistoryRow(
            label: 'Effective rate',
            value: '${item.effectiveTaxRate.toStringAsFixed(2)}%',
          ),
          if (item.linkedServiceRequest.isNotEmpty)
            _HistoryRow(label: 'Service request', value: item.linkedServiceRequest),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
