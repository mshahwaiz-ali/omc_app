import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/premium_card.dart';

enum TaxIncomeType { salary, rental, soleProprietor }

class TaxCalculatorScreen extends StatefulWidget {
  const TaxCalculatorScreen({super.key});

  @override
  State<TaxCalculatorScreen> createState() => _TaxCalculatorScreenState();
}

class _TaxCalculatorScreenState extends State<TaxCalculatorScreen> {
  final _incomeController = TextEditingController();

  TaxIncomeType _incomeType = TaxIncomeType.salary;
  double? _monthlyIncome;
  double? _estimatedMonthlyTax;
  double? _estimatedYearlyTax;

  @override
  void dispose() {
    _incomeController.dispose();
    super.dispose();
  }

  void _calculate() {
    final rawValue = _incomeController.text.replaceAll(',', '').trim();
    final monthlyIncome = double.tryParse(rawValue);

    if (monthlyIncome == null || monthlyIncome <= 0) {
      setState(() {
        _monthlyIncome = null;
        _estimatedMonthlyTax = null;
        _estimatedYearlyTax = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid monthly income.')),
      );
      return;
    }

    // Local UI estimate only.
    // Production: replace this with backend-driven OMC/Frappe tax slab API.
    final yearlyIncome = monthlyIncome * 12;
    final estimatedYearlyTax = _estimateDemoTax(yearlyIncome);
    final estimatedMonthlyTax = estimatedYearlyTax / 12;

    setState(() {
      _monthlyIncome = monthlyIncome;
      _estimatedMonthlyTax = estimatedMonthlyTax;
      _estimatedYearlyTax = estimatedYearlyTax;
    });
  }

  double _estimateDemoTax(double yearlyIncome) {
    if (yearlyIncome <= 600000) return 0;
    if (yearlyIncome <= 1200000) return (yearlyIncome - 600000) * 0.05;
    if (yearlyIncome <= 2200000) {
      return 30000 + ((yearlyIncome - 1200000) * 0.15);
    }
    if (yearlyIncome <= 3200000) {
      return 180000 + ((yearlyIncome - 2200000) * 0.25);
    }
    if (yearlyIncome <= 4100000) {
      return 430000 + ((yearlyIncome - 3200000) * 0.30);
    }
    return 700000 + ((yearlyIncome - 4100000) * 0.35);
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
    final monthlyIncome = _monthlyIncome;
    final monthlyTax = _estimatedMonthlyTax;
    final yearlyTax = _estimatedYearlyTax;
    final yearlyIncome = monthlyIncome == null ? null : monthlyIncome * 12;

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
            'Estimate tax from monthly income. Final production calculation will use OMC backend slabs.',
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
                  keyboardType: TextInputType.number,
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
                  label: 'Calculate Estimate',
                  icon: Icons.calculate_rounded,
                  onPressed: _calculate,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          if (monthlyIncome == null || monthlyTax == null || yearlyTax == null)
            const _EmptyCalculatorState()
          else
            _TaxResultCard(
              monthlyIncome: _money(monthlyIncome),
              yearlyIncome: _money(yearlyIncome!),
              monthlyTax: _money(monthlyTax),
              yearlyTax: _money(yearlyTax),
              monthlyAfterTax: _money(monthlyIncome - monthlyTax),
              yearlyAfterTax: _money(yearlyIncome - yearlyTax),
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
            'This screen is prepared for backend-driven tax slabs in the next integration phase.',
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
  });

  final String monthlyIncome;
  final String yearlyIncome;
  final String monthlyTax;
  final String yearlyTax;
  final String monthlyAfterTax;
  final String yearlyAfterTax;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Estimated Result',
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
              color: Colors.amber.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
              'Development estimate only. Production calculation must use backend tax slabs.',
              style: TextStyle(
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
