import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/premium_card.dart';
import '../data/tax_calculation_repository.dart';

class TaxCalculatorScreen extends ConsumerStatefulWidget {
  const TaxCalculatorScreen({super.key});

  @override
  ConsumerState<TaxCalculatorScreen> createState() =>
      _TaxCalculatorScreenState();
}

class _TaxCalculatorScreenState extends ConsumerState<TaxCalculatorScreen> {
  final _incomeController = TextEditingController();

  TaxIncomeType _incomeType = TaxIncomeType.salary;
  TaxCalculationResult? _result;
  bool _isCalculating = false;

  @override
  void dispose() {
    _incomeController.dispose();
    super.dispose();
  }

  Future<void> _calculate() async {
    final rawValue = _incomeController.text.replaceAll(',', '').trim();
    final monthlyIncome = double.tryParse(rawValue);

    if (monthlyIncome == null || monthlyIncome <= 0) {
      setState(() {
        _result = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid monthly income.')),
      );
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isCalculating = true;
    });

    try {
      final repository = ref.read(taxCalculationRepositoryProvider);
      final result = await repository.calculate(
        TaxCalculationInput(
          incomeType: _incomeType,
          monthlyIncome: monthlyIncome,
        ),
      );

      if (!mounted) return;

      setState(() {
        _result = result;
      });
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to calculate tax right now. Please try again.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCalculating = false;
        });
      }
    }
  }

  String _money(double value) {
    final rounded = value.round().toString();
    final buffer = StringBuffer();

    for (var i = 0; i < rounded.length; i++) {
      final positionFromEnd = rounded.length - i;
      buffer.write(rounded[i]);
      if (positionFromEnd > 1 && positionFromEnd % 3 == 1) {
        buffer.write(',');
      }
    }

    return 'PKR $buffer';
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          const Text(
            'Tax Calculator',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Calculate monthly and yearly tax from income with OMC tax slabs when available.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          PremiumCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SegmentedButton<TaxIncomeType>(
                  segments: const [
                    ButtonSegment(
                      value: TaxIncomeType.salary,
                      label: Text('Salary'),
                      icon: Icon(Icons.badge_outlined),
                    ),
                    ButtonSegment(
                      value: TaxIncomeType.rental,
                      label: Text('Rental'),
                      icon: Icon(Icons.home_work_outlined),
                    ),
                    ButtonSegment(
                      value: TaxIncomeType.soleProprietor,
                      label: Text('Business'),
                      icon: Icon(Icons.storefront_outlined),
                    ),
                  ],
                  selected: {_incomeType},
                  onSelectionChanged: (values) {
                    setState(() {
                      _incomeType = values.first;
                    });
                  },
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: _incomeController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _calculate(),
                  decoration: const InputDecoration(
                    labelText: 'Monthly income',
                    hintText: 'Example: 250000',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                ),
                const SizedBox(height: 18),
                AppButton(
                  label: _isCalculating ? 'Calculating...' : 'Calculate Tax',
                  icon: Icons.calculate_rounded,
                  isLoading: _isCalculating,
                  onPressed: _isCalculating ? null : _calculate,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (result == null)
            const _EmptyCalculatorState()
          else
            _TaxResultCard(
              monthlyIncome: _money(result.monthlyIncome),
              yearlyIncome: _money(result.yearlyIncome),
              monthlyTax: _money(result.monthlyTax),
              yearlyTax: _money(result.yearlyTax),
              monthlyAfterTax: _money(result.monthlyAfterTax),
              yearlyAfterTax: _money(result.yearlyAfterTax),
              isBackendResult: result.isBackendResult,
              note: result.note,
            ),
        ],
      ),
    );
  }
}

class _EmptyCalculatorState extends StatelessWidget {
  const _EmptyCalculatorState();

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(
            Icons.calculate_outlined,
            size: 42,
            color: AppTheme.primaryRed.withValues(alpha: 0.8),
          ),
          const SizedBox(height: 12),
          const Text(
            'Enter income to view estimate',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'The calculator will use OMC tax slabs when available and show a safe estimate otherwise.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaxResultCard extends StatelessWidget {
  const _TaxResultCard({
    required this.monthlyIncome,
    required this.yearlyIncome,
    required this.monthlyTax,
    required this.yearlyTax,
    required this.monthlyAfterTax,
    required this.yearlyAfterTax,
    required this.isBackendResult,
    this.note,
  });

  final String monthlyIncome;
  final String yearlyIncome;
  final String monthlyTax;
  final String yearlyTax;
  final String monthlyAfterTax;
  final String yearlyAfterTax;
  final bool isBackendResult;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isBackendResult ? 'Verified Tax Result' : 'Estimated Tax Result',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          _ResultRow(label: 'Monthly income', value: monthlyIncome),
          _ResultRow(label: 'Monthly tax', value: monthlyTax),
          _ResultRow(label: 'Monthly after tax', value: monthlyAfterTax),
          const Divider(height: 28),
          _ResultRow(label: 'Yearly income', value: yearlyIncome),
          _ResultRow(label: 'Yearly tax', value: yearlyTax),
          _ResultRow(label: 'Yearly after tax', value: yearlyAfterTax),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isBackendResult
                  ? AppTheme.primaryRed.withValues(alpha: 0.08)
                  : Colors.amber.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              note ??
                  (isBackendResult
                      ? 'Calculated from OMC tax data.'
                      : 'Estimated calculation shown. Final tax may vary after slab verification.'),
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
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
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
