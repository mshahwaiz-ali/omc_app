import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
  final Map<String, TextEditingController> _advancedControllers = {};
  final Map<String, bool> _toggleValues = {};
  final Map<String, String> _selectValues = {};

  TaxCalculatorConfig? _config;
  TaxCalculationResult? _result;
  TaxIncomeType _incomeType = TaxIncomeType.salary;
  TaxIncomeMode _incomeMode = TaxIncomeMode.monthly;
  TaxFilerStatus _filerStatus = TaxFilerStatus.activeFiler;
  bool _isLoadingConfig = true;
  bool _isCalculating = false;
  bool _isStartingService = false;
  bool _showAdvanced = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void dispose() {
    _incomeController.dispose();
    for (final controller in _advancedControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() {
      _isLoadingConfig = true;
      _errorMessage = null;
    });

    try {
      final config = await ref.read(taxCalculationRepositoryProvider).getConfig();
      if (!mounted) return;
      setState(() {
        _config = config;
        _isLoadingConfig = false;
      });
      _syncDynamicFieldState(config);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLoadingConfig = false;
        _errorMessage = 'Unable to load calculator configuration right now.';
      });
    }
  }

  void _syncDynamicFieldState(TaxCalculatorConfig config) {
    final fields = [...config.simpleFields, ...config.advancedFields];
    for (final field in fields) {
      if (field.inputType == 'toggle') {
        _toggleValues.putIfAbsent(field.fieldKey, () => field.defaultValue == '1');
      } else if (field.inputType == 'select') {
        _selectValues.putIfAbsent(
          field.fieldKey,
          () => field.defaultValue.isNotEmpty
              ? field.defaultValue
              : field.options.isNotEmpty
              ? field.options.first
              : '',
        );
      } else {
        _advancedControllers.putIfAbsent(
          field.fieldKey,
          () => TextEditingController(text: field.defaultValue),
        );
      }
    }
  }

  List<TaxInputField> _visibleAdvancedFields(TaxCalculatorConfig config) {
    return config.advancedFields
        .where((field) => field.appliesTo(_incomeType))
        .toList(growable: false);
  }

  Map<String, dynamic> _advancedInputs(TaxCalculatorConfig config) {
    final values = <String, dynamic>{};
    for (final field in _visibleAdvancedFields(config)) {
      if (field.inputType == 'toggle') {
        values[field.fieldKey] = _toggleValues[field.fieldKey] == true ? 1 : 0;
      } else if (field.inputType == 'select') {
        final value = _selectValues[field.fieldKey]?.trim();
        if (value != null && value.isNotEmpty) values[field.fieldKey] = value;
      } else {
        final value = _advancedControllers[field.fieldKey]?.text.trim();
        if (value != null && value.isNotEmpty) {
          values[field.fieldKey] = value.replaceAll(',', '');
        }
      }
    }
    return values;
  }

  Future<void> _calculate() async {
    final config = _config;
    if (config == null) return;

    final rawValue = _incomeController.text.replaceAll(',', '').trim();
    final incomeAmount = double.tryParse(rawValue);

    if (incomeAmount == null || incomeAmount <= 0) {
      setState(() => _result = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid income amount.')),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isCalculating = true);

    try {
      final result = await ref.read(taxCalculationRepositoryProvider).calculate(
            TaxCalculationInput(
              taxYear: config.activeTaxYear?.name,
              incomeType: _incomeType,
              incomeMode: _incomeMode,
              incomeAmount: incomeAmount,
              filerStatus: _filerStatus,
              advancedInputs: _advancedInputs(config),
            ),
          );

      if (!mounted) return;
      setState(() => _result = result);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to calculate tax. Check backend slabs/settings.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isCalculating = false);
    }
  }

  Future<void> _startService() async {
    final result = _result;
    final service = result?.cta.linkedService.trim() ?? '';
    final log = result?.calculationLog?.trim() ?? '';

    if (log.isEmpty || service.isEmpty) {
      context.go('/signup');
      return;
    }

    setState(() => _isStartingService = true);
    try {
      final response = await ref
          .read(taxCalculationRepositoryProvider)
          .startServiceFromCalculation(calculationLog: log, service: service);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.message)),
      );
      if (response.serviceRequest.isNotEmpty) {
        context.go('/my-services/${Uri.encodeComponent(response.serviceRequest)}');
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to start service from estimate.')),
      );
    } finally {
      if (mounted) setState(() => _isStartingService = false);
    }
  }

  String _money(double value, {String currency = 'PKR'}) {
    final rounded = value.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < rounded.length; i++) {
      final positionFromEnd = rounded.length - i;
      buffer.write(rounded[i]);
      if (positionFromEnd > 1 && positionFromEnd % 3 == 1) buffer.write(',');
    }
    return '$currency $buffer';
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    final taxYear = config?.activeTaxYear;
    final currency = taxYear?.currency ?? 'PKR';

    return SafeArea(
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 112),
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
            'Estimate your tax using OMC configured tax rules.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          if (_isLoadingConfig)
            const _LoadingCard()
          else if (_errorMessage != null)
            _ErrorCard(message: _errorMessage!, onRetry: _loadConfig)
          else if (config == null || !config.enabled)
            _ErrorCard(
              message: config?.message ?? 'Tax calculator is currently disabled.',
              onRetry: _loadConfig,
            )
          else ...[
            _TaxHeroCard(taxYear: taxYear, badgeLabel: 'Verified slabs'),
            if (config.filingDeadlineAlert.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              _InfoStrip(
                icon: Icons.campaign_outlined,
                text: config.filingDeadlineAlert,
              ),
            ],
            const SizedBox(height: 16),
            _InputCard(
              incomeController: _incomeController,
              incomeType: _incomeType,
              incomeMode: _incomeMode,
              filerStatus: _filerStatus,
              isCalculating: _isCalculating,
              onIncomeTypeChanged: (value) {
                setState(() {
                  _incomeType = value;
                  _result = null;
                });
              },
              onIncomeModeChanged: (value) {
                setState(() {
                  _incomeMode = value;
                  _result = null;
                });
              },
              onFilerStatusChanged: (value) {
                setState(() {
                  _filerStatus = value;
                  _result = null;
                });
              },
              onCalculate: _calculate,
            ),
            if (config.showAdvancedMode && _visibleAdvancedFields(config).isNotEmpty) ...[
              const SizedBox(height: 14),
              _AdvancedFieldsCard(
                expanded: _showAdvanced,
                fields: _visibleAdvancedFields(config),
                controllers: _advancedControllers,
                toggleValues: _toggleValues,
                selectValues: _selectValues,
                onToggleExpanded: () => setState(() => _showAdvanced = !_showAdvanced),
                onChanged: () => setState(() => _result = null),
              ),
            ],
            const SizedBox(height: 18),
            if (_result == null)
              const _EmptyCalculatorState()
            else ...[
              _MainResultCard(
                result: _result!,
                currency: currency,
                money: _money,
              ),
              if (config.showBreakdown && _result!.breakdown.isNotEmpty) ...[
                const SizedBox(height: 14),
                _BreakdownCard(
                  breakdown: _result!.breakdown,
                  currency: currency,
                  money: _money,
                ),
              ],
              if (config.showFilerComparison && _result!.comparison != null) ...[
                const SizedBox(height: 14),
                _ComparisonCard(
                  comparison: _result!.comparison!,
                  currency: currency,
                  money: _money,
                ),
              ],
              if (config.showTaxHealthScore && _result!.taxHealth != null) ...[
                const SizedBox(height: 14),
                _TaxHealthCard(health: _result!.taxHealth!),
              ],
              if (_result!.insights.isNotEmpty) ...[
                const SizedBox(height: 14),
                _InsightsCard(insights: _result!.insights),
              ],
              if (_result!.recommendedNextSteps.isNotEmpty ||
                  config.recommendedNextSteps.isNotEmpty) ...[
                const SizedBox(height: 14),
                _NextStepsCard(
                  steps: _result!.recommendedNextSteps.isNotEmpty
                      ? _result!.recommendedNextSteps
                      : config.recommendedNextSteps,
                ),
              ],
              if (config.requiredDocuments.isNotEmpty) ...[
                const SizedBox(height: 14),
                _RequiredDocumentsCard(documents: config.requiredDocuments),
              ],
              const SizedBox(height: 14),
              _CtaCard(
                cta: _result!.cta,
                isLoading: _isStartingService,
                onPressed: _startService,
              ),
              const SizedBox(height: 14),
              _InfoStrip(
                icon: Icons.verified_outlined,
                text: _result!.note ?? config.disclaimer,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _TaxHeroCard extends StatelessWidget {
  const _TaxHeroCard({required this.taxYear, required this.badgeLabel});

  final TaxYearInfo? taxYear;
  final String badgeLabel;

  @override
  Widget build(BuildContext context) {
    final title = taxYear?.title.trim().isNotEmpty == true
        ? taxYear!.title
        : 'Tax Year';
    final currency = taxYear?.currency ?? 'PKR';

    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.calculate_rounded,
                  color: AppTheme.primaryRed,
                  size: 29,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$title · $currency',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      taxYear?.publicNote.trim().isNotEmpty == true
                          ? taxYear!.publicNote
                          : 'Based on OMC configured slabs.',
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
          ),
          const SizedBox(height: 14),
          _Pill(
            icon: Icons.verified_outlined,
            label: taxYear?.verified == true ? badgeLabel : 'Backend configured',
          ),
        ],
      ),
    );
  }
}

class _InputCard extends StatelessWidget {
  const _InputCard({
    required this.incomeController,
    required this.incomeType,
    required this.incomeMode,
    required this.filerStatus,
    required this.isCalculating,
    required this.onIncomeTypeChanged,
    required this.onIncomeModeChanged,
    required this.onFilerStatusChanged,
    required this.onCalculate,
  });

  final TextEditingController incomeController;
  final TaxIncomeType incomeType;
  final TaxIncomeMode incomeMode;
  final TaxFilerStatus filerStatus;
  final bool isCalculating;
  final ValueChanged<TaxIncomeType> onIncomeTypeChanged;
  final ValueChanged<TaxIncomeMode> onIncomeModeChanged;
  final ValueChanged<TaxFilerStatus> onFilerStatusChanged;
  final VoidCallback onCalculate;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionHeader(
            title: 'Income details',
            subtitle: 'Simple calculator mode for quick estimate.',
            icon: Icons.tune_rounded,
          ),
          const SizedBox(height: 14),
          SegmentedButton<TaxIncomeType>(
            segments: const [
              ButtonSegment(value: TaxIncomeType.salary, label: Text('Salary')),
              ButtonSegment(value: TaxIncomeType.business, label: Text('Business')),
              ButtonSegment(value: TaxIncomeType.rental, label: Text('Rental')),
            ],
            selected: {incomeType},
            onSelectionChanged: (values) => onIncomeTypeChanged(values.first),
          ),
          const SizedBox(height: 14),
          SegmentedButton<TaxIncomeMode>(
            segments: const [
              ButtonSegment(value: TaxIncomeMode.monthly, label: Text('Monthly')),
              ButtonSegment(value: TaxIncomeMode.annual, label: Text('Annual')),
            ],
            selected: {incomeMode},
            onSelectionChanged: (values) => onIncomeModeChanged(values.first),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: incomeController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onCalculate(),
            decoration: InputDecoration(
              labelText: incomeMode == TaxIncomeMode.monthly
                  ? 'Monthly income'
                  : 'Annual income',
              hintText: incomeMode == TaxIncomeMode.monthly
                  ? 'Example: 250000'
                  : 'Example: 3000000',
              prefixIcon: const Icon(Icons.payments_outlined),
            ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<TaxFilerStatus>(
            segments: const [
              ButtonSegment(value: TaxFilerStatus.activeFiler, label: Text('Active')),
              ButtonSegment(value: TaxFilerStatus.lateFiler, label: Text('Late')),
              ButtonSegment(value: TaxFilerStatus.nonFiler, label: Text('Non')),
            ],
            selected: {filerStatus},
            onSelectionChanged: (values) => onFilerStatusChanged(values.first),
          ),
          const SizedBox(height: 18),
          AppButton(
            label: isCalculating ? 'Calculating...' : 'Calculate Tax',
            icon: Icons.calculate_rounded,
            isLoading: isCalculating,
            onPressed: isCalculating ? null : onCalculate,
          ),
        ],
      ),
    );
  }
}

class _AdvancedFieldsCard extends StatelessWidget {
  const _AdvancedFieldsCard({
    required this.expanded,
    required this.fields,
    required this.controllers,
    required this.toggleValues,
    required this.selectValues,
    required this.onToggleExpanded,
    required this.onChanged,
  });

  final bool expanded;
  final List<TaxInputField> fields;
  final Map<String, TextEditingController> controllers;
  final Map<String, bool> toggleValues;
  final Map<String, String> selectValues;
  final VoidCallback onToggleExpanded;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(0),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: onToggleExpanded,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const Icon(Icons.add_circle_outline, color: AppTheme.primaryRed),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Refine calculation',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Icon(expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Column(
                children: [
                  for (final field in fields) ...[
                    _DynamicInputField(
                      field: field,
                      controller: controllers[field.fieldKey],
                      toggleValue: toggleValues[field.fieldKey] == true,
                      selectValue: selectValues[field.fieldKey],
                      onToggleChanged: (value) {
                        toggleValues[field.fieldKey] = value;
                        onChanged();
                      },
                      onSelectChanged: (value) {
                        if (value != null) selectValues[field.fieldKey] = value;
                        onChanged();
                      },
                      onTextChanged: (_) => onChanged(),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _DynamicInputField extends StatelessWidget {
  const _DynamicInputField({
    required this.field,
    this.controller,
    required this.toggleValue,
    this.selectValue,
    required this.onToggleChanged,
    required this.onSelectChanged,
    required this.onTextChanged,
  });

  final TaxInputField field;
  final TextEditingController? controller;
  final bool toggleValue;
  final String? selectValue;
  final ValueChanged<bool> onToggleChanged;
  final ValueChanged<String?> onSelectChanged;
  final ValueChanged<String> onTextChanged;

  @override
  Widget build(BuildContext context) {
    if (field.inputType == 'toggle') {
      return SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(field.label, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: field.helpText.isEmpty ? null : Text(field.helpText),
        value: toggleValue,
        onChanged: onToggleChanged,
      );
    }

    if (field.inputType == 'select') {
      return DropdownButtonFormField<String>(
        value: selectValue?.isNotEmpty == true ? selectValue : null,
        decoration: InputDecoration(
          labelText: field.label,
          helperText: field.helpText.isEmpty ? null : field.helpText,
        ),
        items: field.options
            .map((option) => DropdownMenuItem(value: option, child: Text(option)))
            .toList(growable: false),
        onChanged: onSelectChanged,
      );
    }

    return TextField(
      controller: controller,
      keyboardType: field.inputType == 'number'
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      onChanged: onTextChanged,
      decoration: InputDecoration(
        labelText: field.label,
        helperText: field.helpText.isEmpty ? null : field.helpText,
        prefixIcon: field.inputType == 'number'
            ? const Icon(Icons.add_card_outlined)
            : const Icon(Icons.text_fields_rounded),
      ),
    );
  }
}

class _MainResultCard extends StatelessWidget {
  const _MainResultCard({
    required this.result,
    required this.currency,
    required this.money,
  });

  final TaxCalculationResult result;
  final String currency;
  final String Function(double value, {String currency}) money;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Pill(icon: Icons.verified_outlined, label: 'OMC VERIFIED'),
          const SizedBox(height: 14),
          const Text(
            'Estimated Annual Tax',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            money(result.estimatedAnnualTax, currency: currency),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MetricTile(label: 'Annual Income', value: money(result.annualIncome, currency: currency)),
              _MetricTile(label: 'Monthly Tax', value: money(result.monthlyTax, currency: currency)),
              _MetricTile(label: 'Take-home', value: money(result.monthlyTakeHome, currency: currency)),
              _MetricTile(label: 'Effective Rate', value: '${result.effectiveTaxRate.toStringAsFixed(2)}%'),
            ],
          ),
        ],
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({
    required this.breakdown,
    required this.currency,
    required this.money,
  });

  final Map<String, dynamic> breakdown;
  final String currency;
  final String Function(double value, {String currency}) money;

  double _num(String key) {
    final value = breakdown[key];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return _ResultSection(
      title: 'Breakdown',
      icon: Icons.receipt_long_outlined,
      children: [
        _ResultRow(label: 'Slab Used', value: breakdown['slab_label']?.toString() ?? '-'),
        _ResultRow(label: 'Fixed Tax', value: money(_num('fixed_tax'), currency: currency)),
        _ResultRow(label: 'Rate', value: '${_num('rate_percent').toStringAsFixed(2)}%'),
        _ResultRow(label: 'Amount Above Threshold', value: money(_num('amount_over'), currency: currency)),
        _ResultRow(label: 'Tax Before Credits', value: money(_num('tax_before_credits'), currency: currency)),
        _ResultRow(label: 'Tax Credits', value: money(_num('credits'), currency: currency)),
        _ResultRow(label: 'Final Estimated Tax', value: money(_num('final_tax'), currency: currency)),
      ],
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({
    required this.comparison,
    required this.currency,
    required this.money,
  });

  final TaxComparison comparison;
  final String currency;
  final String Function(double value, {String currency}) money;

  @override
  Widget build(BuildContext context) {
    return _ResultSection(
      title: 'Filer vs Non-Filer',
      icon: Icons.compare_arrows_rounded,
      children: [
        _ResultRow(label: 'Active Filer', value: money(comparison.activeFilerTax, currency: currency)),
        _ResultRow(label: 'Non-Filer', value: money(comparison.nonFilerTax, currency: currency)),
        _ResultRow(label: 'Possible Difference', value: money(comparison.possibleDifference, currency: currency)),
      ],
    );
  }
}

class _TaxHealthCard extends StatelessWidget {
  const _TaxHealthCard({required this.health});

  final TaxHealth health;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.health_and_safety_outlined, color: AppTheme.primaryRed),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tax Readiness: ${health.score}',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  health.reason,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
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

class _InsightsCard extends StatelessWidget {
  const _InsightsCard({required this.insights});

  final List<TaxInsight> insights;

  @override
  Widget build(BuildContext context) {
    return _ResultSection(
      title: 'Result insights',
      icon: Icons.lightbulb_outline,
      children: [
        for (final insight in insights)
          _InsightTile(insight: insight),
      ],
    );
  }
}

class _InsightTile extends StatelessWidget {
  const _InsightTile({required this.insight});

  final TaxInsight insight;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            insight.title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            insight.message,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _NextStepsCard extends StatelessWidget {
  const _NextStepsCard({required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return _ResultSection(
      title: 'Recommended next steps',
      icon: Icons.checklist_rounded,
      children: [
        for (var i = 0; i < steps.length; i++)
          _ResultRow(label: '${i + 1}', value: steps[i]),
      ],
    );
  }
}

class _RequiredDocumentsCard extends StatelessWidget {
  const _RequiredDocumentsCard({required this.documents});

  final List<String> documents;

  @override
  Widget build(BuildContext context) {
    return _ResultSection(
      title: 'Documents to keep ready',
      icon: Icons.folder_copy_outlined,
      children: [
        for (final document in documents)
          _ResultRow(label: 'Required', value: document),
      ],
    );
  }
}

class _CtaCard extends StatelessWidget {
  const _CtaCard({required this.cta, required this.isLoading, required this.onPressed});

  final TaxCta cta;
  final bool isLoading;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            cta.title.isNotEmpty ? cta.title : 'Need OMC to verify and file this?',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          AppButton(
            label: isLoading
                ? 'Starting...'
                : cta.button.isNotEmpty
                ? cta.button
                : 'Start Tax Filing Service',
            icon: Icons.arrow_forward_rounded,
            isLoading: isLoading,
            onPressed: isLoading ? null : onPressed,
          ),
        ],
      ),
    );
  }
}

class _ResultSection extends StatelessWidget {
  const _ResultSection({required this.title, required this.icon, required this.children});

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(title: title, subtitle: '', icon: icon),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle, required this.icon});

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primaryRed, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    height: 1.3,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
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

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.primaryRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppTheme.primaryRed),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.primaryRed,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoStrip extends StatelessWidget {
  const _InfoStrip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppTheme.primaryRed.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryRed, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
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
            'The app will call Frappe and calculate using OMC configured tax years, slabs, fields, guidance, and CTA rules.',
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

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const PremiumCard(
      padding: EdgeInsets.all(22),
      child: Row(
        children: [
          SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 14),
          Expanded(child: Text('Loading backend calculator configuration...')),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            message,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
