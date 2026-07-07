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
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 112),
        children: [
          const Text(
            'Tax Calculator',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Calculate monthly and yearly tax from OMC backend slabs when available. Local fallback results are unofficial estimates only.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 20),
          const _TaxCalculatorHero(),
          const SizedBox(height: 16),
          PremiumCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _CalculatorSectionHeader(
                  title: 'Income details',
                  subtitle: 'Choose income type and enter monthly income.',
                ),
                const SizedBox(height: 14),
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

class _TaxCalculatorHero extends StatelessWidget {
  const _TaxCalculatorHero();

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(22),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(21),
              border: Border.all(
                color: AppTheme.primaryRed.withValues(alpha: 0.08),
              ),
            ),
            child: const Icon(
              Icons.calculate_rounded,
              color: AppTheme.primaryRed,
              size: 30,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quick tax calculation',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Uses OMC backend tax data first. If live data is unavailable, any fallback is clearly marked as unofficial and not for filing.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CalculatorSectionHeader extends StatelessWidget {
  const _CalculatorSectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppTheme.primaryRed.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppTheme.primaryRed.withValues(alpha: 0.08),
            ),
          ),
          child: const Icon(
            Icons.tune_rounded,
            color: AppTheme.primaryRed,
            size: 20,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
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
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.receipt_long_outlined,
              size: 30,
              color: AppTheme.primaryRed,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Enter income to calculate tax',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Backend tax data is preferred. Any local fallback is an unofficial estimate only and should not be used for filing.',
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
          Row(
            children: [
              Expanded(
                child: Text(
                  isBackendResult
                      ? 'OMC verified calculation'
                      : 'Estimate only — not for filing',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _ResultSourcePill(isBackendResult: isBackendResult),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ResultMetricCard(
                  label: 'Monthly tax',
                  value: monthlyTax,
                  icon: Icons.calendar_month_outlined,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ResultMetricCard(
                  label: 'Yearly tax',
                  value: yearlyTax,
                  icon: Icons.event_note_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ResultSection(
            title: 'Monthly breakdown',
            children: [
              _ResultRow(label: 'Income', value: monthlyIncome),
              _ResultRow(label: 'Tax', value: monthlyTax),
              _ResultRow(label: 'After tax', value: monthlyAfterTax),
            ],
          ),
          const SizedBox(height: 12),
          _ResultSection(
            title: 'Yearly breakdown',
            children: [
              _ResultRow(label: 'Income', value: yearlyIncome),
              _ResultRow(label: 'Tax', value: yearlyTax),
              _ResultRow(label: 'After tax', value: yearlyAfterTax),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: isBackendResult
                  ? AppTheme.primaryRed.withValues(alpha: 0.08)
                  : Colors.amber.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isBackendResult
                    ? AppTheme.primaryRed.withValues(alpha: 0.12)
                    : Colors.amber.withValues(alpha: 0.24),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  isBackendResult
                      ? Icons.verified_outlined
                      : Icons.warning_amber_rounded,
                  color: isBackendResult
                      ? AppTheme.primaryRed
                      : Colors.amber.shade900,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    note ??
                        (isBackendResult
                            ? 'Calculated from verified OMC backend tax data. Confirm final filing figures with OMC if needed.'
                            : 'Estimate only — not for filing. Use this as a guide until OMC verifies the applicable tax slabs.'),
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
          ),
        ],
      ),
    );
  }
}

class _ResultSourcePill extends StatelessWidget {
  const _ResultSourcePill({required this.isBackendResult});

  final bool isBackendResult;

  @override
  Widget build(BuildContext context) {
    final color = isBackendResult ? AppTheme.primaryRed : Colors.amber.shade900;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isBackendResult ? 'OMC VERIFIED' : 'ESTIMATE ONLY',
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _ResultMetricCard extends StatelessWidget {
  const _ResultMetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryRed.withValues(alpha: 0.07),
              ),
            ),
            child: Icon(icon, color: AppTheme.primaryRed, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultSection extends StatelessWidget {
  const _ResultSection({required this.title, required this.children});

  final String title;
  final List<_ResultRow> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ...children,
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
