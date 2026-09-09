import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/omc_premium.dart';
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
  static const String _all = 'All';

  String _selectedIncomeType = _all;
  String _selectedFilerStatus = _all;

  static const List<String> _incomeTypeFilters = [
    _all,
    'Salary',
    'Business',
    'Rental',
  ];

  static const List<String> _filerStatusFilters = [
    _all,
    'Active Filer',
    'Late Filer',
    'Non-Filer',
  ];

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(taxCalculationRepositoryProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        surfaceTintColor: Colors.transparent,
        title: const Text('Tax estimate history'),
      ),
      body: FutureBuilder<List<TaxCalculationHistoryItem>>(
        future: repository.getHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView(message: 'Loading tax estimate history');
          }

          if (snapshot.hasError) {
            return const _StateMessage(
              icon: Icons.error_outline_rounded,
              title: 'History unavailable',
              message:
                  'Saved tax estimates could not be loaded right now. Try again from this screen.',
            );
          }

          final items = snapshot.data ?? const <TaxCalculationHistoryItem>[];
          if (items.isEmpty) {
            return const _StateMessage(
              icon: Icons.history_rounded,
              title: 'No saved estimates yet',
              message:
                  'Calculate tax while logged in to save estimates here when backend logging is enabled.',
            );
          }

          final filteredItems = items.where(_matchesFilters).toList();

          return RefreshIndicator.adaptive(
            onRefresh: () async =>
                ref.invalidate(taxCalculationRepositoryProvider),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                _HistoryFilterSummary(
                  incomeTypes: _incomeTypeFilters,
                  filerStatuses: _filerStatusFilters,
                  selectedIncomeType: _selectedIncomeType,
                  selectedFilerStatus: _selectedFilerStatus,
                  resultCount: filteredItems.length,
                  totalCount: items.length,
                  onIncomeTypeSelected: (value) {
                    setState(() => _selectedIncomeType = value);
                  },
                  onFilerStatusSelected: (value) {
                    setState(() => _selectedFilerStatus = value);
                  },
                  onClear: () {
                    setState(() {
                      _selectedIncomeType = _all;
                      _selectedFilerStatus = _all;
                    });
                  },
                ),
                const SizedBox(height: 16),
                if (filteredItems.isEmpty)
                  const _InlineEmptyState(
                    icon: Icons.filter_alt_off_rounded,
                    title: 'No estimates for these filters',
                    message:
                        'Your saved estimates still exist. Try another income type or filer status.',
                  )
                else
                  for (var index = 0;
                      index < filteredItems.length;
                      index++) ...[
                    _HistoryCard(item: filteredItems[index]),
                    if (index != filteredItems.length - 1)
                      const SizedBox(height: 10),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }

  bool _matchesFilters(TaxCalculationHistoryItem item) {
    final incomeType = item.incomeType.trim().toLowerCase();
    final filerStatus = item.filerStatus.trim().toLowerCase();

    final matchesIncomeType =
        _selectedIncomeType == _all ||
        incomeType == _selectedIncomeType.toLowerCase();

    final matchesFilerStatus =
        _selectedFilerStatus == _all ||
        filerStatus == _selectedFilerStatus.toLowerCase();

    return matchesIncomeType && matchesFilerStatus;
  }
}

class _HistoryFilterSummary extends StatelessWidget {
  const _HistoryFilterSummary({
    required this.incomeTypes,
    required this.filerStatuses,
    required this.selectedIncomeType,
    required this.selectedFilerStatus,
    required this.resultCount,
    required this.totalCount,
    required this.onIncomeTypeSelected,
    required this.onFilerStatusSelected,
    required this.onClear,
  });

  final List<String> incomeTypes;
  final List<String> filerStatuses;
  final String selectedIncomeType;
  final String selectedFilerStatus;
  final int resultCount;
  final int totalCount;
  final ValueChanged<String> onIncomeTypeSelected;
  final ValueChanged<String> onFilerStatusSelected;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final activeFilters =
        selectedIncomeType != 'All' || selectedFilerStatus != 'All';
    final countLabel = resultCount == totalCount
        ? '$totalCount estimate${totalCount == 1 ? '' : 's'}'
        : '$resultCount of $totalCount estimates';

    return PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        title: const Text(
          'Filters',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '$countLabel · $selectedIncomeType · $selectedFilerStatus',
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
            height: 1.35,
          ),
        ),
        trailing: activeFilters
            ? TextButton(onPressed: onClear, child: const Text('Clear'))
            : const Icon(Icons.expand_more_rounded),
        children: [
          _FilterGroup(
            title: 'Income type',
            values: incomeTypes,
            selectedValue: selectedIncomeType,
            onSelected: onIncomeTypeSelected,
          ),
          const SizedBox(height: 16),
          _FilterGroup(
            title: 'Filer status',
            values: filerStatuses,
            selectedValue: selectedFilerStatus,
            onSelected: onFilerStatusSelected,
          ),
        ],
      ),
    );
  }
}

class _FilterGroup extends StatelessWidget {
  const _FilterGroup({
    required this.title,
    required this.values,
    required this.selectedValue,
    required this.onSelected,
  });

  final String title;
  final List<String> values;
  final String selectedValue;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final value in values)
              ChoiceChip(
                label: Text(value),
                selected: selectedValue == value,
                onSelected: (_) => onSelected(value),
              ),
          ],
        ),
      ],
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.item});

  final TaxCalculationHistoryItem item;

  @override
  Widget build(BuildContext context) {
    final taxYear = item.taxYear.trim().isEmpty ? 'Tax year not labelled' : item.taxYear.trim();
    final date = item.createdOn.trim();
    final linkedRequest = item.linkedServiceRequest.trim();

    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _MetaPill(label: taxYear),
              if (date.isNotEmpty) _MetaPill(label: date),
              if (item.incomeType.trim().isNotEmpty)
                _MetaPill(label: item.incomeType.trim()),
              if (item.filerStatus.trim().isNotEmpty)
                _MetaPill(label: item.filerStatus.trim()),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Estimated annual tax',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _formatMoney(item.estimatedAnnualTax),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 28,
              height: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Annual income ${_formatMoney(item.annualIncome)}',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: EdgeInsets.zero,
            title: const Text(
              'Estimate details',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            children: [
              _KeyValue(
                label: 'Monthly tax',
                value: _formatMoney(item.monthlyTax),
              ),
              _KeyValue(
                label: 'Effective rate',
                value: '${item.effectiveTaxRate.toStringAsFixed(2)}%',
              ),
              if (linkedRequest.isNotEmpty)
                _KeyValue(
                  label: 'Linked service request',
                  value: linkedRequest,
                  strong: true,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.processingSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.processing,
          fontSize: 13,
          height: 1.35,
        ),
      ),
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
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 15,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: strong ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineEmptyState extends StatelessWidget {
  const _InlineEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          OmcIconBadge(
            icon: icon,
            color: AppTheme.textSecondary,
            size: 44,
            iconSize: 22,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 15,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

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
            OmcIconBadge(
              icon: icon,
              color: AppTheme.textSecondary,
              size: 48,
              iconSize: 24,
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 21,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 15,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

String _formatMoney(double value) {
  final negative = value < 0;
  final rounded = value.abs().round().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < rounded.length; index++) {
    final positionFromEnd = rounded.length - index;
    buffer.write(rounded[index]);
    if (positionFromEnd > 1 && positionFromEnd % 3 == 1) buffer.write(',');
  }
  return 'PKR ${negative ? '-' : ''}${buffer.toString()}';
}
