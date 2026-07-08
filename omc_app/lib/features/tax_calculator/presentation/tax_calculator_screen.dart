import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../data/tax_calculation_repository.dart';

class TaxCalculatorScreen extends ConsumerStatefulWidget {
  const TaxCalculatorScreen({super.key});

  @override
  ConsumerState<TaxCalculatorScreen> createState() =>
      _TaxCalculatorScreenState();
}

class _TaxCalculatorScreenState extends ConsumerState<TaxCalculatorScreen> {
  final _amountController = TextEditingController();
  final Map<String, TextEditingController> _advancedControllers = {};
  final Map<String, dynamic> _advancedValues = {};

  TaxIncomeType _incomeType = TaxIncomeType.salary;
  TaxIncomeMode _incomeMode = TaxIncomeMode.monthly;
  TaxFilerStatus _filerStatus = TaxFilerStatus.activeFiler;
  TaxCalculationResult? _result;
  bool _showAdvanced = false;
  bool _isCalculating = false;
  bool _isStartingService = false;
  String? _error;

  @override
  void dispose() {
    _amountController.dispose();
    for (final controller in _advancedControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(taxCalculationRepositoryProvider);
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tax Calculator'),
        actions: [
          if (_canOpenHistory(authState))
            IconButton(
              tooltip: 'Calculation history',
              icon: const Icon(Icons.history_rounded),
              onPressed: () => context.push('/tax-calculator/history'),
            ),
        ],
      ),
      body: FutureBuilder<TaxCalculatorConfig>(
        future: repository.getConfig(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return _StateMessage(
              icon: Icons.error_outline_rounded,
              title: 'Calculator unavailable',
              message: _friendlyError(snapshot.error),
              actionLabel: 'Try again',
              onAction: () => setState(() {}),
            );
          }

          final config = snapshot.data;
          if (config == null || !config.enabled) {
            return _StateMessage(
              icon: Icons.calculate_outlined,
              title: 'Calculator unavailable',
              message:
                  config?.message ?? 'Tax calculator is currently disabled.',
            );
          }

          _syncAdvancedDefaults(config.advancedFields);
          final activeAdvancedFields = config.advancedFields
              .where((field) => field.appliesTo(_incomeType))
              .toList(growable: false);

          return RefreshIndicator(
            onRefresh: () async => setState(() {}),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
              children: [
                _HeaderCard(config: config),
                const SizedBox(height: 14),
                _InputCard(
                  incomeType: _incomeType,
                  incomeMode: _incomeMode,
                  filerStatus: _filerStatus,
                  amountController: _amountController,
                  onIncomeTypeChanged: (value) {
                    setState(() {
                      _incomeType = value;
                      _result = null;
                      _error = null;
                    });
                  },
                  onIncomeModeChanged: (value) {
                    setState(() {
                      _incomeMode = value;
                      _result = null;
                      _error = null;
                    });
                  },
                  onFilerStatusChanged: (value) {
                    setState(() {
                      _filerStatus = value;
                      _result = null;
                      _error = null;
                    });
                  },
                ),
                if (config.showAdvancedMode &&
                    activeAdvancedFields.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _AdvancedSection(
                    expanded: _showAdvanced,
                    fields: activeAdvancedFields,
                    controllers: _advancedControllers,
                    values: _advancedValues,
                    onToggle: () =>
                        setState(() => _showAdvanced = !_showAdvanced),
                    onChanged: (key, value) {
                      _advancedValues[key] = value;
                      _result = null;
                    },
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _NoticeCard(
                    icon: Icons.warning_amber_rounded,
                    title: 'Check calculation input',
                    message: _error!,
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _isCalculating
                      ? null
                      : () => _calculate(repository, config),
                  icon: _isCalculating
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.calculate_rounded),
                  label: Text(
                    _isCalculating ? 'Calculating...' : 'Calculate Tax',
                  ),
                ),
                if (_result != null) ...[
                  const SizedBox(height: 18),
                  _ResultSection(
                    result: _result!,
                    config: config,
                    authState: authState,
                    isStartingService: _isStartingService,
                    onCtaPressed: () =>
                        _handleCta(repository, config, authState),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  void _syncAdvancedDefaults(List<TaxInputField> fields) {
    for (final field in fields) {
      if (!_advancedControllers.containsKey(field.fieldKey)) {
        final controller = TextEditingController(text: field.defaultValue);
        _advancedControllers[field.fieldKey] = controller;
        if (field.defaultValue.trim().isNotEmpty) {
          _advancedValues[field.fieldKey] = field.defaultValue;
        }
      }
    }
  }

  Future<void> _calculate(
    TaxCalculationRepository repository,
    TaxCalculatorConfig config,
  ) async {
    final amount = _parseAmount(_amountController.text);
    if (amount <= 0) {
      setState(() => _error = 'Enter a valid income amount greater than zero.');
      return;
    }

    final selectedAdvancedInputs = <String, dynamic>{};
    for (final entry in _advancedValues.entries) {
      final value = entry.value;
      if (value is String && value.trim().isEmpty) continue;
      selectedAdvancedInputs[entry.key] = value;
    }

    setState(() {
      _isCalculating = true;
      _error = null;
    });

    try {
      final result = await repository.calculate(
        TaxCalculationInput(
          incomeType: _incomeType,
          incomeMode: _incomeMode,
          incomeAmount: amount,
          filerStatus: _filerStatus,
          taxYear: config.activeTaxYear?.name,
          advancedInputs: selectedAdvancedInputs,
        ),
      );
      if (!mounted) return;
      setState(() => _result = result);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _isCalculating = false);
    }
  }

  Future<void> _handleCta(
    TaxCalculationRepository repository,
    TaxCalculatorConfig config,
    AuthState authState,
  ) async {
    final result = _result;
    if (result == null) return;

    if (authState.status == AuthStatus.guest ||
        authState.status == AuthStatus.unauthenticated) {
      context.push('/signup');
      return;
    }

    if (authState.capabilities.isPending || authState.capabilities.isRejected) {
      context.push('/under-review');
      return;
    }

    if (!authState.capabilities.canCreateServiceRequest &&
        !authState.capabilities.isInternal) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your account cannot start a service request yet.'),
        ),
      );
      return;
    }

    final calculationLog = result.calculationLog;
    if (calculationLog == null || calculationLog.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Calculation was not saved by backend, so service cannot be started from this estimate.',
          ),
        ),
      );
      return;
    }

    final service = result.cta.linkedService.trim().isNotEmpty
        ? result.cta.linkedService.trim()
        : config.cta.linkedService.trim();
    if (service.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tax filing service is linked in backend settings.'),
        ),
      );
      return;
    }

    setState(() => _isStartingService = true);
    try {
      final created = await repository.startServiceFromCalculation(
        calculationLog: calculationLog,
        service: service,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(created.message)));
      if (created.serviceRequest.trim().isNotEmpty) {
        context.push(
          '/my-services/${Uri.encodeComponent(created.serviceRequest)}',
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_friendlyError(error))));
    } finally {
      if (mounted) setState(() => _isStartingService = false);
    }
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.config});

  final TaxCalculatorConfig config;

  @override
  Widget build(BuildContext context) {
    final year = config.activeTaxYear;
    final verifiedText = year?.verified == true
        ? 'Verified slabs'
        : 'Backend configured';
    final badgeText = year == null
        ? 'OMC configured tax rules'
        : '${year.title} · ${year.currency} · $verifiedText';

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  Icons.calculate_rounded,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tax Calculator',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text('Estimate your tax using OMC configured rules.'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Chip(icon: Icons.verified_rounded, label: badgeText),
              if (config.filingDeadlineAlert.trim().isNotEmpty)
                _Chip(
                  icon: Icons.event_available_rounded,
                  label: config.filingDeadlineAlert.trim(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InputCard extends StatelessWidget {
  const _InputCard({
    required this.incomeType,
    required this.incomeMode,
    required this.filerStatus,
    required this.amountController,
    required this.onIncomeTypeChanged,
    required this.onIncomeModeChanged,
    required this.onFilerStatusChanged,
  });

  final TaxIncomeType incomeType;
  final TaxIncomeMode incomeMode;
  final TaxFilerStatus filerStatus;
  final TextEditingController amountController;
  final ValueChanged<TaxIncomeType> onIncomeTypeChanged;
  final ValueChanged<TaxIncomeMode> onIncomeModeChanged;
  final ValueChanged<TaxFilerStatus> onFilerStatusChanged;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Simple Calculator',
            subtitle: 'Fast estimate for guests and customers.',
          ),
          const SizedBox(height: 14),
          _SegmentBlock<TaxIncomeType>(
            title: 'Income Type',
            selected: incomeType,
            values: TaxIncomeType.values,
            label: (value) => value.label,
            onChanged: onIncomeTypeChanged,
          ),
          const SizedBox(height: 14),
          _SegmentBlock<TaxIncomeMode>(
            title: 'Income Mode',
            selected: incomeMode,
            values: TaxIncomeMode.values,
            label: (value) => value.label,
            onChanged: onIncomeModeChanged,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
            ],
            decoration: InputDecoration(
              labelText: incomeMode == TaxIncomeMode.monthly
                  ? 'Monthly Income Amount'
                  : 'Annual Income Amount',
              prefixText: 'PKR ',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 14),
          _SegmentBlock<TaxFilerStatus>(
            title: 'Filer Status',
            selected: filerStatus,
            values: TaxFilerStatus.values,
            label: (value) => value.label,
            onChanged: onFilerStatusChanged,
          ),
        ],
      ),
    );
  }
}

class _AdvancedSection extends StatelessWidget {
  const _AdvancedSection({
    required this.expanded,
    required this.fields,
    required this.controllers,
    required this.values,
    required this.onToggle,
    required this.onChanged,
  });

  final bool expanded;
  final List<TaxInputField> fields;
  final Map<String, TextEditingController> controllers;
  final Map<String, dynamic> values;
  final VoidCallback onToggle;
  final void Function(String key, dynamic value) onChanged;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  const Expanded(
                    child: _SectionTitle(
                      title: 'Refine calculation',
                      subtitle: 'Optional fields change by income type.',
                    ),
                  ),
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                  ),
                ],
              ),
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 14),
            for (final field in fields) ...[
              _AdvancedField(
                field: field,
                controller: controllers[field.fieldKey]!,
                value: values[field.fieldKey],
                onChanged: (value) => onChanged(field.fieldKey, value),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }
}

class _AdvancedField extends StatelessWidget {
  const _AdvancedField({
    required this.field,
    required this.controller,
    required this.value,
    required this.onChanged,
  });

  final TaxInputField field;
  final TextEditingController controller;
  final dynamic value;
  final ValueChanged<dynamic> onChanged;

  @override
  Widget build(BuildContext context) {
    final type = field.inputType.toLowerCase();
    if (type == 'toggle' || type == 'check') {
      return SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(field.label),
        subtitle: field.helpText.isEmpty ? null : Text(field.helpText),
        value:
            value == true ||
            value?.toString() == '1' ||
            value?.toString().toLowerCase() == 'true',
        onChanged: onChanged,
      );
    }

    if (type == 'select' && field.options.isNotEmpty) {
      return DropdownButtonFormField<String>(
        initialValue: field.options.contains(value) ? value?.toString() : null,
        decoration: InputDecoration(
          labelText: field.label,
          helperText: field.helpText.isEmpty ? null : field.helpText,
          border: const OutlineInputBorder(),
        ),
        items: field.options
            .map(
              (option) => DropdownMenuItem(value: option, child: Text(option)),
            )
            .toList(growable: false),
        onChanged: onChanged,
      );
    }

    return TextField(
      controller: controller,
      keyboardType: type == 'number'
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: type == 'number'
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))]
          : null,
      onChanged: (raw) => onChanged(type == 'number' ? _parseAmount(raw) : raw),
      decoration: InputDecoration(
        labelText: field.label,
        helperText: field.helpText.isEmpty ? null : field.helpText,
        prefixText: type == 'number' ? 'PKR ' : null,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _ResultSection extends StatelessWidget {
  const _ResultSection({
    required this.result,
    required this.config,
    required this.authState,
    required this.isStartingService,
    required this.onCtaPressed,
  });

  final TaxCalculationResult result;
  final TaxCalculatorConfig config;
  final AuthState authState;
  final bool isStartingService;
  final VoidCallback onCtaPressed;

  @override
  Widget build(BuildContext context) {
    final cta = result.cta.button.trim().isNotEmpty ? result.cta : config.cta;
    final ctaTitle = _ctaTitleFor(authState, cta.title);
    final ctaButton = _ctaButtonFor(authState, cta.button);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Estimated Annual Tax',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                _formatMoney(result.estimatedAnnualTax),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _MetricTile(
                    label: 'Annual Income',
                    value: _formatMoney(result.annualIncome),
                  ),
                  _MetricTile(
                    label: 'Monthly Tax',
                    value: _formatMoney(result.monthlyTax),
                  ),
                  _MetricTile(
                    label: 'Monthly Take-home',
                    value: _formatMoney(result.monthlyTakeHome),
                  ),
                  _MetricTile(
                    label: 'Effective Rate',
                    value: '${result.effectiveTaxRate.toStringAsFixed(2)}%',
                  ),
                ],
              ),
            ],
          ),
        ),
        if (config.showBreakdown && result.breakdown.isNotEmpty) ...[
          const SizedBox(height: 12),
          _BreakdownCard(result: result),
        ],
        if (config.showFilerComparison && result.comparison != null) ...[
          const SizedBox(height: 12),
          _ComparisonCard(comparison: result.comparison!),
        ],
        if (config.showTaxHealthScore && result.taxHealth != null) ...[
          const SizedBox(height: 12),
          _NoticeCard(
            icon: Icons.health_and_safety_rounded,
            title: 'Tax Readiness: ${result.taxHealth!.score}',
            message: result.taxHealth!.reason,
          ),
        ],
        if (result.recommendedNextSteps.isNotEmpty ||
            config.recommendedNextSteps.isNotEmpty) ...[
          const SizedBox(height: 12),
          _StepsCard(
            steps: result.recommendedNextSteps.isNotEmpty
                ? result.recommendedNextSteps
                : config.recommendedNextSteps,
          ),
        ],
        if (result.insights.isNotEmpty) ...[
          const SizedBox(height: 12),
          for (final insight in result.insights) ...[
            _NoticeCard(
              icon: Icons.tips_and_updates_rounded,
              title: insight.title,
              message: insight.message,
            ),
            const SizedBox(height: 12),
          ],
        ],
        if ((result.note ?? config.disclaimer).trim().isNotEmpty) ...[
          _NoticeCard(
            icon: Icons.info_outline_rounded,
            title: 'Estimate note',
            message: (result.note ?? config.disclaimer).trim(),
          ),
          const SizedBox(height: 12),
        ],
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ctaTitle,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                onPressed: isStartingService ? null : onCtaPressed,
                icon: isStartingService
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.arrow_forward_rounded),
                label: Text(isStartingService ? 'Starting...' : ctaButton),
              ),
            ],
          ),
        ),
        const SizedBox(height: 220),
      ],
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.result});

  final TaxCalculationResult result;

  @override
  Widget build(BuildContext context) {
    final data = result.breakdown;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Tax Breakdown',
            subtitle: 'Backend slab calculation details.',
          ),
          const SizedBox(height: 12),
          _KeyValue(
            label: 'Slab Used',
            value: data['slab_label']?.toString() ?? '-',
          ),
          _KeyValue(
            label: 'Taxable Income',
            value: _formatMoney(_num(data['taxable_income'])),
          ),
          _KeyValue(
            label: 'Fixed Tax',
            value: _formatMoney(_num(data['fixed_tax'])),
          ),
          _KeyValue(
            label: 'Rate',
            value: '${_num(data['rate_percent']).toStringAsFixed(2)}%',
          ),
          _KeyValue(
            label: 'Tax Before Credits',
            value: _formatMoney(_num(data['tax_before_credits'])),
          ),
          _KeyValue(
            label: 'Credits',
            value: _formatMoney(_num(data['credits'])),
          ),
          const Divider(height: 20),
          _KeyValue(
            label: 'Final Estimated Tax',
            value: _formatMoney(result.estimatedAnnualTax),
            strong: true,
          ),
        ],
      ),
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  const _ComparisonCard({required this.comparison});

  final TaxComparison comparison;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Filer vs Non-Filer',
            subtitle: 'See the possible tax difference.',
          ),
          const SizedBox(height: 12),
          _KeyValue(
            label: 'Active Filer',
            value: _formatMoney(comparison.activeFilerTax),
          ),
          _KeyValue(
            label: 'Non-Filer',
            value: _formatMoney(comparison.nonFilerTax),
          ),
          const Divider(height: 20),
          _KeyValue(
            label: 'Possible Difference',
            value: _formatMoney(comparison.possibleDifference),
            strong: true,
          ),
        ],
      ),
    );
  }
}

class _StepsCard extends StatelessWidget {
  const _StepsCard({required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Recommended next steps',
            subtitle: 'Guidance from OMC backend.',
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < steps.length; index++)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${index + 1}.',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(steps[index])),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _SegmentBlock<T> extends StatelessWidget {
  const _SegmentBlock({
    required this.title,
    required this.selected,
    required this.values,
    required this.label,
    required this.onChanged,
  });

  final String title;
  final T selected;
  final List<T> values;
  final String Function(T value) label;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: SegmentedButton<T>(
            showSelectedIcon: false,
            segments: values
                .map(
                  (value) => ButtonSegment<T>(
                    value: value,
                    label: Text(label(value), overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(growable: false),
            selected: {selected},
            onSelectionChanged: (selection) => onChanged(selection.first),
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
    return Container(
      width: MediaQuery.sizeOf(context).width > 420 ? 170 : double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                if (message.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(message.trim()),
                ],
              ],
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
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

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
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

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
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 15,
            color: Theme.of(context).colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSecondaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
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
    final style = TextStyle(
      fontWeight: strong ? FontWeight.w900 : FontWeight.w600,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(value, textAlign: TextAlign.end, style: style),
          ),
        ],
      ),
    );
  }
}

bool _canOpenHistory(AuthState authState) {
  return authState.status == AuthStatus.authenticated &&
      !authState.capabilities.isGuest;
}

String _ctaTitleFor(AuthState authState, String backendTitle) {
  if (authState.status == AuthStatus.guest ||
      authState.status == AuthStatus.unauthenticated) {
    return backendTitle.trim().isNotEmpty
        ? backendTitle
        : 'Want to save this estimate?';
  }
  if (authState.capabilities.isPending) return 'Account approval is pending';
  if (authState.capabilities.isRejected) {
    return 'Contact OMC to review your account';
  }
  return backendTitle.trim().isNotEmpty
      ? backendTitle
      : 'Need OMC to verify and file this?';
}

String _ctaButtonFor(AuthState authState, String backendButton) {
  if (authState.status == AuthStatus.guest ||
      authState.status == AuthStatus.unauthenticated) {
    return backendButton.trim().isNotEmpty ? backendButton : 'Create Account';
  }
  if (authState.capabilities.isPending || authState.capabilities.isRejected) {
    return 'View Account Status';
  }
  return backendButton.trim().isNotEmpty
      ? backendButton
      : 'Start Tax Filing Service';
}

double _parseAmount(String raw) {
  return double.tryParse(raw.replaceAll(',', '').trim()) ?? 0;
}

double _num(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString().replaceAll(',', '').trim() ?? '') ??
      0;
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
