import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
              message:
                  'Calculate tax while logged in to save estimates here when backend logging is enabled.',
            );
          }

          final filteredItems = items.where(_matchesFilters).toList();

          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(taxCalculationRepositoryProvider),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              itemCount: filteredItems.length + 1,
              separatorBuilder: (_, index) =>
                  SizedBox(height: index == 0 ? 14 : 10),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _HistoryFiltersCard(
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
                  );
                }

                if (filteredItems.isEmpty) {
                  return const _InlineEmptyState(
                    icon: Icons.filter_alt_off_rounded,
                    title: 'No estimates for these filters',
                    message: 'Try another income type or filer status.',
                  );
                }

                return _HistoryCard(item: filteredItems[index - 1]);
              },
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

class _HistoryFiltersCard extends StatelessWidget {
  const _HistoryFiltersCard({
    required this.incomeTypes,
    required this.filerStatuses,
    required this.selectedIncomeType,
    required this.selectedFilerStatus,
    required this.resultCount,
    required this.totalCount,
    required this.onIncomeTypeSelected,
    required this.onFilerStatusSelected,
  });

  final List<String> incomeTypes;
  final List<String> filerStatuses;
  final String selectedIncomeType;
  final String selectedFilerStatus;
  final int resultCount;
  final int totalCount;
  final ValueChanged<String> onIncomeTypeSelected;
  final ValueChanged<String> onFilerStatusSelected;

  @override
  Widget build(BuildContext context) {
    final countLabel = resultCount == totalCount
        ? '$totalCount estimate${totalCount == 1 ? '' : 's'}'
        : '$resultCount of $totalCount estimates';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.65),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Filter estimates',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ),
                Text(
                  countLabel,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _FilterRow(
              title: 'Income type',
              values: incomeTypes,
              selectedValue: selectedIncomeType,
              onSelected: onIncomeTypeSelected,
            ),
            const SizedBox(height: 12),
            _FilterRow(
              title: 'Filer status',
              values: filerStatuses,
              selectedValue: selectedFilerStatus,
              onSelected: onFilerStatusSelected,
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
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
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              for (final value in values) ...[
                _FilterChip(
                  label: value,
                  selected: selectedValue == value,
                  onTap: () => onSelected(value),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: colorScheme.primaryContainer,
      labelStyle: TextStyle(
        color: selected
            ? colorScheme.onPrimaryContainer
            : colorScheme.onSurface,
        fontWeight: FontWeight.w800,
      ),
      side: BorderSide(
        color: selected
            ? colorScheme.primary.withValues(alpha: 0.35)
            : colorScheme.outlineVariant.withValues(alpha: 0.8),
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
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Icon(icon, size: 34),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
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
        side: BorderSide(
          color: Theme.of(
            context,
          ).colorScheme.outlineVariant.withValues(alpha: 0.65),
        ),
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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                if (item.linkedServiceRequest.trim().isNotEmpty)
                  const Icon(Icons.task_alt_rounded, size: 18),
              ],
            ),
            if (item.createdOn.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                item.createdOn,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Chip(
                  label: item.incomeType.isEmpty ? 'Income' : item.incomeType,
                ),
                _Chip(
                  label: item.filerStatus.isEmpty
                      ? 'Filer Status'
                      : item.filerStatus,
                ),
              ],
            ),
            const SizedBox(height: 14),
            _KeyValue(
              label: 'Annual Income',
              value: _formatMoney(item.annualIncome),
            ),
            _KeyValue(
              label: 'Estimated Annual Tax',
              value: _formatMoney(item.estimatedAnnualTax),
              strong: true,
            ),
            _KeyValue(
              label: 'Monthly Tax',
              value: _formatMoney(item.monthlyTax),
            ),
            _KeyValue(
              label: 'Effective Rate',
              value: '${item.effectiveTaxRate.toStringAsFixed(2)}%',
            ),
            if (item.linkedServiceRequest.trim().isNotEmpty) ...[
              const Divider(height: 20),
              _KeyValue(
                label: 'Linked Service Request',
                value: item.linkedServiceRequest,
                strong: true,
              ),
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
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSecondaryContainer,
          fontWeight: FontWeight.w700,
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
              style: TextStyle(
                fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
              ),
            ),
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
            Icon(icon, size: 46),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              textAlign: TextAlign.center,
            ),
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
  return text
      .replaceFirst('Exception: ', '')
      .replaceFirst('DioException [bad response]: ', '');
}
