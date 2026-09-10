import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/effective_capabilities_provider.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/app_labeled_field.dart';
import '../../../core/diagnostics/omc_widget_keys.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/omc_premium.dart';
import '../../../core/widgets/premium_card.dart';
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
  final Map<String, FocusNode> _advancedFocusNodes = {};
  final Map<String, dynamic> _advancedValues = {};

  TaxIncomeType _incomeType = TaxIncomeType.salary;
  TaxIncomeMode _incomeMode = TaxIncomeMode.monthly;
  TaxFilerStatus _filerStatus = TaxFilerStatus.activeFiler;
  TaxCalculationResult? _result;
  bool _showAdvanced = false;
  bool _isCalculating = false;
  bool _isStartingService = false;
  AppFailure? _calculationFailure;
  String? _validationMessage;
  String? _invalidAdvancedFieldKey;
  String? _selectedTaxYear;
  late Future<TaxCalculatorConfig> _configFuture;

  @override
  void initState() {
    super.initState();
    _configFuture = ref.read(taxCalculationRepositoryProvider).getConfig();
  }

  void _retryConfig() {
    setState(() {
      _configFuture = ref
          .read(taxCalculationRepositoryProvider)
          .getConfig(taxYear: _selectedTaxYear);
    });
  }

  Future<void> _refreshConfig() async {
    final future = ref
        .read(taxCalculationRepositoryProvider)
        .getConfig(taxYear: _selectedTaxYear);
    setState(() => _configFuture = future);
    await future;
  }

  @override
  void dispose() {
    _amountController.dispose();
    for (final controller in _advancedControllers.values) {
      controller.dispose();
    }
    for (final focusNode in _advancedFocusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(taxCalculationRepositoryProvider);
    final authState = ref.watch(authControllerProvider);
    final capabilities = ref.watch(effectiveCapabilitiesProvider);

    return Scaffold(
      key: OmcWidgetKeys.taxScreen,
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text('Tax calculator'),
        actions: [
          if (_canOpenHistory(authState, capabilities))
            IconButton(
              tooltip: 'Calculation history',
              icon: const Icon(Icons.history_rounded),
              onPressed: () => context.push('/tax-calculator/history'),
            ),
        ],
      ),
      body: FutureBuilder<TaxCalculatorConfig>(
        future: _configFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView(message: 'Loading tax calculator');
          }

          if (snapshot.hasError) {
            return OmcPagePadding(
              topPadding: 20,
              bottomPadding: 20,
              child: AppErrorState.fromError(
                error: snapshot.error!,
                onRetry: _retryConfig,
                fallbackTitle: 'We could not load the tax calculator',
                fallbackMessage:
                    'Check your connection and try loading the calculator again.',
              ),
            );
          }

          final config = snapshot.data;
          if (config == null) {
            return OmcPagePadding(
              topPadding: 20,
              bottomPadding: 20,
              child: AppErrorState(
                title: 'Calculator settings unavailable',
                message:
                    'The calculator settings are incomplete. Try again, or contact OMC support if this continues.',
                onRetry: _retryConfig,
              ),
            );
          }

          if (!config.enabled) {
            return OmcPagePadding(
              topPadding: 20,
              bottomPadding: 20,
              child: AppConfigurationState(
                title: config.stateTitle,
                message: config.stateMessage,
              ),
            );
          }

          if (config.activeTaxYear == null) {
            return const OmcPagePadding(
              topPadding: 20,
              bottomPadding: 20,
              child: AppConfigurationState(
                title: 'Tax calculator is not configured',
                message:
                    'No active tax year is available. Please contact OMC support or ask an administrator to configure one.',
              ),
            );
          }

          _syncAdvancedDefaults(config.advancedFields);
          final activeAdvancedFields = config.advancedFields
              .where((field) => field.appliesTo(_incomeType))
              .toList(growable: false);
          final currency = config.activeTaxYear!.currency.trim().isEmpty
              ? 'PKR'
              : config.activeTaxYear!.currency.trim();

          return RefreshIndicator.adaptive(
            onRefresh: _refreshConfig,
            child: OmcPageListView(
              topPadding: 8,
              bottomPadding: 40,
              children: [
                _TaxYearSection(
                  config: config,
                  selectedTaxYear:
                      _selectedTaxYear ?? config.activeTaxYear?.name,
                  onTaxYearChanged: (value) {
                    if (value == null || value == _selectedTaxYear) return;
                    setState(() {
                      _selectedTaxYear = value;
                      _result = null;
                      _validationMessage = null;
                      _invalidAdvancedFieldKey = null;
                      _calculationFailure = null;
                      _advancedValues.clear();
                      for (final controller in _advancedControllers.values) {
                        controller.dispose();
                      }
                      _advancedControllers.clear();
                      for (final focusNode in _advancedFocusNodes.values) {
                        focusNode.dispose();
                      }
                      _advancedFocusNodes.clear();
                      _configFuture = ref
                          .read(taxCalculationRepositoryProvider)
                          .getConfig(taxYear: value);
                    });
                  },
                ),
                const SizedBox(height: 24),
                const _SectionHeader(
                  title: 'Income details',
                  subtitle:
                      'Enter the values used for this server-calculated estimate.',
                ),
                const SizedBox(height: 10),
                _IncomeSection(
                  incomeType: _incomeType,
                  incomeMode: _incomeMode,
                  filerStatus: _filerStatus,
                  amountController: _amountController,
                  currency: currency,
                  onIncomeTypeChanged: (value) {
                    setState(() {
                      _incomeType = value;
                      _result = null;
                      _validationMessage = null;
                      _invalidAdvancedFieldKey = null;
                      _calculationFailure = null;
                    });
                  },
                  onIncomeModeChanged: (value) {
                    setState(() {
                      _incomeMode = value;
                      _result = null;
                      _validationMessage = null;
                      _calculationFailure = null;
                    });
                  },
                  onFilerStatusChanged: (value) {
                    setState(() {
                      _filerStatus = value;
                      _result = null;
                      _validationMessage = null;
                      _calculationFailure = null;
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
                    focusNodeFor: _advancedFocusNodeFor,
                    values: _advancedValues,
                    invalidFieldKey: _invalidAdvancedFieldKey,
                    currency: currency,
                    onToggle: () =>
                        setState(() => _showAdvanced = !_showAdvanced),
                    onChanged: (key, value) {
                      setState(() {
                        _advancedValues[key] = value;
                        _result = null;
                        if (_invalidAdvancedFieldKey == key) {
                          _invalidAdvancedFieldKey = null;
                          _validationMessage = null;
                        }
                      });
                    },
                  ),
                ],
                if (_validationMessage != null) ...[
                  const SizedBox(height: 12),
                  _NoticeCard(
                    icon: Icons.warning_amber_rounded,
                    title: 'Check calculation input',
                    message: _validationMessage!,
                    tone: AppTheme.warning,
                  ),
                ],
                const SizedBox(height: 16),
                AppButton(
                  label: 'Calculate tax',
                  icon: Icons.calculate_rounded,
                  isLoading: _isCalculating,
                  onPressed: _isCalculating
                      ? null
                      : () => _calculate(repository, config),
                ),
                if (_calculationFailure != null) ...[
                  const SizedBox(height: 12),
                  AppErrorState(
                    title: _calculationFailure!.title,
                    message: _calculationFailure!.message,
                    onRetry: _calculationFailure!.canRetry
                        ? () => _calculate(repository, config)
                        : null,
                    compact: true,
                  ),
                ],
                if (_result != null) ...[
                  const SizedBox(height: 28),
                  _ResultSection(
                    result: _result!,
                    config: config,
                    authState: authState,
                    capabilities: capabilities,
                    currency: currency,
                    isStartingService: _isStartingService,
                    onCtaPressed: () =>
                        _handleCta(repository, config, authState, capabilities),
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
      _advancedFocusNodes.putIfAbsent(field.fieldKey, () => FocusNode());
    }
  }

  FocusNode _advancedFocusNodeFor(TaxInputField field) {
    return _advancedFocusNodes.putIfAbsent(field.fieldKey, () => FocusNode());
  }

  bool _advancedFieldMissing(TaxInputField field) {
    if (!field.isRequired) return false;
    final type = field.inputType.toLowerCase();
    if (type == 'toggle' || type == 'check') return false;
    if (type == 'select') {
      return (_advancedValues[field.fieldKey]?.toString().trim() ?? '').isEmpty;
    }
    return (_advancedControllers[field.fieldKey]?.text.trim() ?? '').isEmpty;
  }

  void _focusAdvancedField(TaxInputField field) {
    final focusNode = _advancedFocusNodeFor(field);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      focusNode.requestFocus();
      final fieldContext = focusNode.context;
      if (fieldContext != null) {
        Scrollable.ensureVisible(
          fieldContext,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: 0.2,
        );
      }
    });
  }

  Future<void> _calculate(
    TaxCalculationRepository repository,
    TaxCalculatorConfig config,
  ) async {
    final amount = _parseAmount(_amountController.text);
    if (amount <= 0) {
      setState(() {
        _validationMessage = 'Enter a valid income amount greater than zero.';
        _calculationFailure = null;
      });
      return;
    }

    final activeAdvancedFields = config.advancedFields
        .where((field) => field.appliesTo(_incomeType))
        .toList(growable: false);
    TaxInputField? firstMissingAdvanced;
    for (final field in activeAdvancedFields) {
      if (_advancedFieldMissing(field)) {
        firstMissingAdvanced = field;
        break;
      }
    }
    final missingAdvanced = firstMissingAdvanced;
    if (missingAdvanced != null) {
      setState(() {
        _showAdvanced = true;
        _invalidAdvancedFieldKey = missingAdvanced.fieldKey;
        _validationMessage =
            '${missingAdvanced.label} is required for this calculation.';
        _calculationFailure = null;
      });
      _focusAdvancedField(missingAdvanced);
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
      _validationMessage = null;
      _invalidAdvancedFieldKey = null;
      _calculationFailure = null;
    });

    try {
      final result = await repository.calculate(
        TaxCalculationInput(
          incomeType: _incomeType,
          incomeMode: _incomeMode,
          incomeAmount: amount,
          filerStatus: _filerStatus,
          taxYear: _selectedTaxYear ?? config.activeTaxYear?.name,
          advancedInputs: selectedAdvancedInputs,
        ),
      );
      if (!mounted) return;
      setState(() {
        _result = result;
        _calculationFailure = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _result = null;
        _calculationFailure = AppFailureClassifier.classify(error);
      });
    } finally {
      if (mounted) setState(() => _isCalculating = false);
    }
  }

  Future<void> _handleCta(
    TaxCalculationRepository repository,
    TaxCalculatorConfig config,
    AuthState authState,
    AuthCapabilities capabilities,
  ) async {
    final result = _result;
    if (result == null) return;

    if (authState.status == AuthStatus.guest ||
        authState.status == AuthStatus.unauthenticated) {
      context.push('/signup');
      return;
    }

    if (capabilities.isPending || capabilities.isRejected) {
      context.push('/under-review');
      return;
    }

    if (!capabilities.canCreateServiceRequest && !capabilities.isInternal) {
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
            'This estimate could not be saved, so a service request cannot be started from it. Please calculate again.',
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
          content: Text(
            'No tax filing service is linked to this calculator yet. Please contact OMC support.',
          ),
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
      final failure = AppFailureClassifier.classify(error);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
    } finally {
      if (mounted) setState(() => _isStartingService = false);
    }
  }
}

class _TaxYearSection extends StatelessWidget {
  const _TaxYearSection({
    required this.config,
    required this.selectedTaxYear,
    required this.onTaxYearChanged,
  });

  final TaxCalculatorConfig config;
  final String? selectedTaxYear;
  final ValueChanged<String?> onTaxYearChanged;

  @override
  Widget build(BuildContext context) {
    final active = config.activeTaxYear;
    final years = config.availableTaxYears.isEmpty
        ? <TaxYearInfo>[?active]
        : config.availableTaxYears;
    final currentValue = years.any((item) => item.name == selectedTaxYear)
        ? selectedTaxYear
        : active?.name;

    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Tax year & rules',
            subtitle:
                'Select the backend tax-year configuration for this estimate.',
          ),
          const SizedBox(height: 16),
          AppLabeledField(
            label: 'Tax year',
            child: DropdownButtonFormField<String>(
              initialValue: currentValue,
              isExpanded: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.calendar_month_outlined),
              ),
              items: years
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.name,
                      child: Text(item.title),
                    ),
                  )
                  .toList(growable: false),
              onChanged: years.length > 1 ? onTaxYearChanged : null,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _InfoPill(
                icon: active?.verified == true
                    ? Icons.verified_rounded
                    : Icons.rule_rounded,
                label: active == null
                    ? 'Configured tax rules'
                    : '${active.currency} · ${active.verified ? 'Verified rules' : 'Configured rules'}',
              ),
              if (config.filingDeadlineAlert.trim().isNotEmpty)
                _InfoPill(
                  icon: Icons.event_available_rounded,
                  label: config.filingDeadlineAlert.trim(),
                ),
            ],
          ),
          if (active?.publicNote.trim().isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Text(
              active!.publicNote.trim(),
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _IncomeSection extends StatelessWidget {
  const _IncomeSection({
    required this.incomeType,
    required this.incomeMode,
    required this.filerStatus,
    required this.amountController,
    required this.currency,
    required this.onIncomeTypeChanged,
    required this.onIncomeModeChanged,
    required this.onFilerStatusChanged,
  });

  final TaxIncomeType incomeType;
  final TaxIncomeMode incomeMode;
  final TaxFilerStatus filerStatus;
  final TextEditingController amountController;
  final String currency;
  final ValueChanged<TaxIncomeType> onIncomeTypeChanged;
  final ValueChanged<TaxIncomeMode> onIncomeModeChanged;
  final ValueChanged<TaxFilerStatus> onFilerStatusChanged;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ChoiceGroup<TaxIncomeType>(
            title: 'Income type',
            selected: incomeType,
            values: TaxIncomeType.values,
            label: (value) => value.label,
            onChanged: onIncomeTypeChanged,
          ),
          const SizedBox(height: 20),
          _ChoiceGroup<TaxIncomeMode>(
            title: 'Income mode',
            selected: incomeMode,
            values: TaxIncomeMode.values,
            label: (value) => value.label,
            onChanged: onIncomeModeChanged,
          ),
          const SizedBox(height: 20),
          AppLabeledField(
            label: incomeMode == TaxIncomeMode.monthly
                ? 'Monthly income amount'
                : 'Annual income amount',
            child: TextField(
              controller: amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
              ],
              decoration: InputDecoration(prefixText: '$currency '),
            ),
          ),
          const SizedBox(height: 20),
          _ChoiceGroup<TaxFilerStatus>(
            title: 'Filer status',
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
    required this.focusNodeFor,
    required this.values,
    required this.invalidFieldKey,
    required this.currency,
    required this.onToggle,
    required this.onChanged,
  });

  final bool expanded;
  final List<TaxInputField> fields;
  final Map<String, TextEditingController> controllers;
  final FocusNode Function(TaxInputField field) focusNodeFor;
  final Map<String, dynamic> values;
  final String? invalidFieldKey;
  final String currency;
  final VoidCallback onToggle;
  final void Function(String key, dynamic value) onChanged;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: _SectionHeader(
                      title: 'Refine calculation',
                      subtitle:
                          'Optional backend-configured fields for this income type.',
                    ),
                  ),
                  const SizedBox(width: 8),
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
            const SizedBox(height: 16),
            for (var index = 0; index < fields.length; index++) ...[
              _AdvancedField(
                field: fields[index],
                controller: controllers[fields[index].fieldKey]!,
                focusNode: focusNodeFor(fields[index]),
                value: values[fields[index].fieldKey],
                invalid: invalidFieldKey == fields[index].fieldKey,
                currency: currency,
                onChanged: (value) => onChanged(fields[index].fieldKey, value),
              ),
              if (index != fields.length - 1) const SizedBox(height: 16),
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
    required this.focusNode,
    required this.value,
    required this.invalid,
    required this.currency,
    required this.onChanged,
  });

  final TaxInputField field;
  final TextEditingController controller;
  final FocusNode focusNode;
  final dynamic value;
  final bool invalid;
  final String currency;
  final ValueChanged<dynamic> onChanged;

  @override
  Widget build(BuildContext context) {
    final type = field.inputType.toLowerCase();
    if (type == 'toggle' || type == 'check') {
      return SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: Text(
          field.label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        ),
        subtitle: field.helpText.isEmpty
            ? null
            : Text(
                field.helpText,
                style: const TextStyle(fontSize: 14, height: 1.4),
              ),
        value:
            value == true ||
            value?.toString() == '1' ||
            value?.toString().toLowerCase() == 'true',
        onChanged: onChanged,
      );
    }

    if (type == 'select' && field.options.isNotEmpty) {
      return AppLabeledField(
        label: field.label,
        isRequired: field.isRequired,
        child: DropdownButtonFormField<String>(
          focusNode: focusNode,
          initialValue: field.options.contains(value)
              ? value?.toString()
              : null,
          isExpanded: true,
          decoration: InputDecoration(
            helperText: field.helpText.isEmpty ? null : field.helpText,
            errorText: invalid ? '${field.label} is required.' : null,
          ),
          items: field.options
              .map(
                (option) =>
                    DropdownMenuItem(value: option, child: Text(option)),
              )
              .toList(growable: false),
          onChanged: onChanged,
        ),
      );
    }

    return AppLabeledField(
      label: field.label,
      isRequired: field.isRequired,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: type == 'number'
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        inputFormatters: type == 'number'
            ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]'))]
            : null,
        onChanged: (raw) =>
            onChanged(type == 'number' ? _parseAmount(raw) : raw),
        decoration: InputDecoration(
          helperText: field.helpText.isEmpty ? null : field.helpText,
          errorText: invalid ? '${field.label} is required.' : null,
          prefixText: type == 'number' ? '$currency ' : null,
        ),
      ),
    );
  }
}

class _ResultSection extends StatelessWidget {
  const _ResultSection({
    required this.result,
    required this.config,
    required this.authState,
    required this.capabilities,
    required this.currency,
    required this.isStartingService,
    required this.onCtaPressed,
  });

  final TaxCalculationResult result;
  final TaxCalculatorConfig config;
  final AuthState authState;
  final AuthCapabilities capabilities;
  final String currency;
  final bool isStartingService;
  final VoidCallback onCtaPressed;

  @override
  Widget build(BuildContext context) {
    final cta = result.cta.button.trim().isNotEmpty ? result.cta : config.cta;
    final ctaTitle = _ctaTitleFor(authState, capabilities, cta.title);
    final ctaButton = _ctaButtonFor(authState, capabilities, cta.button);
    final source = result.source;
    final note = (result.note ?? config.disclaimer).trim();
    final steps = result.recommendedNextSteps.isNotEmpty
        ? result.recommendedNextSteps
        : config.recommendedNextSteps;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionHeader(
          title: 'Your estimate',
          subtitle:
              'Calculated by the backend using the selected tax configuration.',
        ),
        const SizedBox(height: 10),
        PremiumCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Estimated annual tax',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 15),
              ),
              const SizedBox(height: 5),
              Text(
                _formatMoney(result.estimatedAnnualTax, currency),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 28,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 18),
              _ResultMetricRow(
                label: 'Monthly tax',
                value: _formatMoney(result.monthlyTax, currency),
              ),
              const Divider(height: 20),
              _ResultMetricRow(
                label: 'Effective tax rate',
                value: '${result.effectiveTaxRate.toStringAsFixed(2)}%',
              ),
              const Divider(height: 20),
              _ResultMetricRow(
                label: 'Monthly take-home',
                value: _formatMoney(result.monthlyTakeHome, currency),
              ),
              const Divider(height: 20),
              _ResultMetricRow(
                label: 'Annual income',
                value: _formatMoney(result.annualIncome, currency),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _ResultDetails(
          result: result,
          config: config,
          currency: currency,
          steps: steps,
          note: note,
        ),
        if (source != null) ...[
          const SizedBox(height: 12),
          _NoticeCard(
            icon: source.verified
                ? Icons.verified_outlined
                : Icons.rule_outlined,
            title: source.taxYear.trim().isEmpty
                ? 'Calculation source'
                : 'Calculation source · ${source.taxYear}',
            message: [
              if (source.publicNote.trim().isNotEmpty) source.publicNote.trim(),
              if (source.lastVerifiedOn.trim().isNotEmpty)
                'Last verified ${source.lastVerifiedOn.trim()}',
            ].join('\n'),
            tone: source.verified ? AppTheme.success : AppTheme.processing,
          ),
        ],
        const SizedBox(height: 16),
        PremiumCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                ctaTitle,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 17,
                  height: 1.3,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              AppButton(
                label: ctaButton,
                icon: Icons.arrow_forward_rounded,
                isLoading: isStartingService,
                onPressed: isStartingService ? null : onCtaPressed,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ResultDetails extends StatelessWidget {
  const _ResultDetails({
    required this.result,
    required this.config,
    required this.currency,
    required this.steps,
    required this.note,
  });

  final TaxCalculationResult result;
  final TaxCalculatorConfig config;
  final String currency;
  final List<String> steps;
  final String note;

  @override
  Widget build(BuildContext context) {
    final hasBreakdown = config.showBreakdown && result.breakdown.isNotEmpty;
    final hasComparison =
        config.showFilerComparison && result.comparison != null;
    final hasGuidance =
        (config.showTaxHealthScore && result.taxHealth != null) ||
        steps.isNotEmpty ||
        result.insights.isNotEmpty ||
        config.requiredDocuments.isNotEmpty ||
        note.isNotEmpty;

    if (!hasBreakdown && !hasComparison && !hasGuidance) {
      return const SizedBox.shrink();
    }

    return PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Column(
        children: [
          if (hasBreakdown)
            ExpansionTile(
              title: const Text('Tax breakdown'),
              subtitle: const Text('Slab and taxable-income details'),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              children: [_BreakdownContent(result: result, currency: currency)],
            ),
          if (hasComparison)
            ExpansionTile(
              title: const Text('Filer comparison'),
              subtitle: const Text('Backend filer/non-filer comparison'),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              children: [
                _ComparisonContent(
                  comparison: result.comparison!,
                  currency: currency,
                ),
              ],
            ),
          if (hasGuidance)
            ExpansionTile(
              title: const Text('Guidance & notes'),
              subtitle: const Text('Readiness, next steps and estimate notes'),
              childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
              children: [
                if (config.showTaxHealthScore && result.taxHealth != null)
                  _GuidanceBlock(
                    title: 'Tax readiness · ${result.taxHealth!.score}',
                    body: result.taxHealth!.reason,
                  ),
                if (steps.isNotEmpty)
                  _NumberedList(title: 'Recommended next steps', items: steps),
                if (config.requiredDocuments.isNotEmpty)
                  _BulletList(
                    title: 'Required documents',
                    items: config.requiredDocuments,
                  ),
                for (final insight in result.insights)
                  _GuidanceBlock(
                    title: insight.title.trim().isEmpty
                        ? 'Tax insight'
                        : insight.title.trim(),
                    body: insight.message,
                  ),
                if (note.isNotEmpty)
                  _GuidanceBlock(title: 'Estimate note', body: note),
              ],
            ),
        ],
      ),
    );
  }
}

class _BreakdownContent extends StatelessWidget {
  const _BreakdownContent({required this.result, required this.currency});

  final TaxCalculationResult result;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final data = result.breakdown;
    return Column(
      children: [
        _KeyValue(
          label: 'Slab used',
          value: data['slab_label']?.toString() ?? '-',
        ),
        _KeyValue(
          label: 'Taxable income',
          value: _formatMoney(_num(data['taxable_income']), currency),
        ),
        _KeyValue(
          label: 'Fixed tax',
          value: _formatMoney(_num(data['fixed_tax']), currency),
        ),
        _KeyValue(
          label: 'Rate',
          value: '${_num(data['rate_percent']).toStringAsFixed(2)}%',
        ),
        _KeyValue(
          label: 'Tax before credits',
          value: _formatMoney(_num(data['tax_before_credits']), currency),
        ),
        _KeyValue(
          label: 'Credits',
          value: _formatMoney(_num(data['credits']), currency),
        ),
        const Divider(height: 20),
        _KeyValue(
          label: 'Final estimated tax',
          value: _formatMoney(result.estimatedAnnualTax, currency),
          strong: true,
        ),
      ],
    );
  }
}

class _ComparisonContent extends StatelessWidget {
  const _ComparisonContent({required this.comparison, required this.currency});

  final TaxComparison comparison;
  final String currency;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _KeyValue(
          label: 'Active filer',
          value: _formatMoney(comparison.activeFilerTax, currency),
        ),
        _KeyValue(
          label: 'Non-filer',
          value: _formatMoney(comparison.nonFilerTax, currency),
        ),
        const Divider(height: 20),
        _KeyValue(
          label: 'Possible difference',
          value: _formatMoney(comparison.possibleDifference, currency),
          strong: true,
        ),
      ],
    );
  }
}

class _ChoiceGroup<T> extends StatelessWidget {
  const _ChoiceGroup({
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
                selected: value == selected,
                showCheckmark: true,
                label: Text(label(value)),
                onSelected: (_) => onChanged(value),
              ),
          ],
        ),
      ],
    );
  }
}

class _ResultMetricRow extends StatelessWidget {
  const _ResultMetricRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 15),
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 21,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.processingSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.processing),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.processing,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
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
    required this.tone,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tone, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (message.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    message.trim(),
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GuidanceBlock extends StatelessWidget {
  const _GuidanceBlock({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (body.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              body.trim(),
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NumberedList extends StatelessWidget {
  const _NumberedList({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          for (var index = 0; index < items.length; index++)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 24,
                    child: Text(
                      '${index + 1}.',
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      items[index],
                      style: const TextStyle(fontSize: 15, height: 1.4),
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

class _BulletList extends StatelessWidget {
  const _BulletList({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          for (final item in items)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Text('•', style: TextStyle(fontSize: 16)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item,
                      style: const TextStyle(fontSize: 15, height: 1.4),
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

bool _canOpenHistory(AuthState authState, AuthCapabilities capabilities) {
  return authState.status == AuthStatus.authenticated && !capabilities.isGuest;
}

String _ctaTitleFor(
  AuthState authState,
  AuthCapabilities capabilities,
  String configuredTitle,
) {
  if (authState.status == AuthStatus.guest ||
      authState.status == AuthStatus.unauthenticated) {
    return configuredTitle.trim().isNotEmpty
        ? configuredTitle
        : 'Want to save this estimate?';
  }
  if (capabilities.isPending) return 'Account approval is pending';
  if (capabilities.isRejected) {
    return 'Contact OMC to review your account';
  }
  return configuredTitle.trim().isNotEmpty
      ? configuredTitle
      : 'Need OMC to verify and file this?';
}

String _ctaButtonFor(
  AuthState authState,
  AuthCapabilities capabilities,
  String configuredButton,
) {
  if (authState.status == AuthStatus.guest ||
      authState.status == AuthStatus.unauthenticated) {
    return configuredButton.trim().isNotEmpty
        ? configuredButton
        : 'Create Account';
  }
  if (capabilities.isPending || capabilities.isRejected) {
    return 'View Account Status';
  }
  return configuredButton.trim().isNotEmpty
      ? configuredButton
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

String _formatMoney(double value, String currency) {
  final negative = value < 0;
  final rounded = value.abs().round().toString();
  final buffer = StringBuffer();
  for (var index = 0; index < rounded.length; index++) {
    final positionFromEnd = rounded.length - index;
    buffer.write(rounded[index]);
    if (positionFromEnd > 1 && positionFromEnd % 3 == 1) buffer.write(',');
  }
  return '${currency.trim().isEmpty ? 'PKR' : currency.trim()} ${negative ? '-' : ''}${buffer.toString()}';
}
