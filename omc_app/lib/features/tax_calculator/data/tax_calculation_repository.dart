import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/frappe_client.dart';

final taxCalculationRepositoryProvider = Provider<TaxCalculationRepository>((ref) {
  return TaxCalculationRepository(frappeClient: ref.watch(frappeClientProvider));
});

enum TaxIncomeType { salary, business, rental }

enum TaxIncomeMode { monthly, annual }

enum TaxFilerStatus { activeFiler, lateFiler, nonFiler }

extension TaxIncomeTypeX on TaxIncomeType {
  String get key => switch (this) {
    TaxIncomeType.salary => 'salary',
    TaxIncomeType.business => 'business',
    TaxIncomeType.rental => 'rental',
  };

  String get label => switch (this) {
    TaxIncomeType.salary => 'Salary',
    TaxIncomeType.business => 'Business',
    TaxIncomeType.rental => 'Rental',
  };
}

extension TaxIncomeModeX on TaxIncomeMode {
  String get key => this == TaxIncomeMode.monthly ? 'monthly' : 'annual';
  String get label => this == TaxIncomeMode.monthly ? 'Monthly' : 'Annual';
}

extension TaxFilerStatusX on TaxFilerStatus {
  String get key => switch (this) {
    TaxFilerStatus.activeFiler => 'active_filer',
    TaxFilerStatus.lateFiler => 'late_filer',
    TaxFilerStatus.nonFiler => 'non_filer',
  };

  String get label => switch (this) {
    TaxFilerStatus.activeFiler => 'Active Filer',
    TaxFilerStatus.lateFiler => 'Late Filer',
    TaxFilerStatus.nonFiler => 'Non-Filer',
  };
}

class TaxCalculatorConfig {
  const TaxCalculatorConfig({
    required this.enabled,
    this.message,
    this.activeTaxYear,
    this.simpleFields = const [],
    this.advancedFields = const [],
    this.showAdvancedMode = true,
    this.showBreakdown = true,
    this.showFilerComparison = true,
    this.showTaxHealthScore = true,
    this.disclaimer = '',
    this.filingDeadlineAlert = '',
    this.recommendedNextSteps = const [],
    this.requiredDocuments = const [],
    this.cta = const TaxCta(),
  });

  final bool enabled;
  final String? message;
  final TaxYearInfo? activeTaxYear;
  final List<TaxInputField> simpleFields;
  final List<TaxInputField> advancedFields;
  final bool showAdvancedMode;
  final bool showBreakdown;
  final bool showFilerComparison;
  final bool showTaxHealthScore;
  final String disclaimer;
  final String filingDeadlineAlert;
  final List<String> recommendedNextSteps;
  final List<String> requiredDocuments;
  final TaxCta cta;

  factory TaxCalculatorConfig.fromJson(Map<String, dynamic> json) {
    final settings = _map(json['settings']);
    return TaxCalculatorConfig(
      enabled: _bool(json['enabled'], fallback: true),
      message: _string(json['message']),
      activeTaxYear: json['active_tax_year'] is Map
          ? TaxYearInfo.fromJson(_map(json['active_tax_year']))
          : null,
      simpleFields: _list(json['simple_fields'])
          .map((item) => TaxInputField.fromJson(_map(item)))
          .toList(growable: false),
      advancedFields: _list(json['advanced_fields'])
          .map((item) => TaxInputField.fromJson(_map(item)))
          .toList(growable: false),
      showAdvancedMode: _bool(settings['show_advanced_mode'], fallback: true),
      showBreakdown: _bool(settings['show_breakdown'], fallback: true),
      showFilerComparison: _bool(settings['show_filer_comparison'], fallback: true),
      showTaxHealthScore: _bool(settings['show_tax_health_score'], fallback: true),
      disclaimer: _string(json['disclaimer']) ?? '',
      filingDeadlineAlert: _string(json['filing_deadline_alert']) ?? '',
      recommendedNextSteps: _strings(json['recommended_next_steps']),
      requiredDocuments: _strings(json['required_documents']),
      cta: json['cta'] is Map ? TaxCta.fromJson(_map(json['cta'])) : const TaxCta(),
    );
  }
}

class TaxYearInfo {
  const TaxYearInfo({
    required this.name,
    required this.title,
    required this.currency,
    required this.verified,
    this.lastVerifiedOn = '',
    this.publicNote = '',
  });

  final String name;
  final String title;
  final String currency;
  final bool verified;
  final String lastVerifiedOn;
  final String publicNote;

  factory TaxYearInfo.fromJson(Map<String, dynamic> json) {
    return TaxYearInfo(
      name: _string(json['name']) ?? '',
      title: _string(json['title'] ?? json['tax_year']) ?? '',
      currency: _string(json['currency']) ?? 'PKR',
      verified: _bool(json['verified']),
      lastVerifiedOn: _string(json['last_verified_on']) ?? '',
      publicNote: _string(json['public_note']) ?? '',
    );
  }
}

class TaxInputField {
  const TaxInputField({
    required this.fieldKey,
    required this.label,
    required this.inputType,
    required this.incomeType,
    required this.mode,
    required this.isRequired,
    this.defaultValue = '',
    this.options = const [],
    this.helpText = '',
  });

  final String fieldKey;
  final String label;
  final String inputType;
  final String incomeType;
  final String mode;
  final bool isRequired;
  final String defaultValue;
  final List<String> options;
  final String helpText;

  bool appliesTo(TaxIncomeType selectedType) {
    final normalized = incomeType.toLowerCase().replaceAll(' ', '_');
    return normalized == 'all' || normalized == selectedType.key;
  }

  factory TaxInputField.fromJson(Map<String, dynamic> json) {
    return TaxInputField(
      fieldKey: _string(json['field_key']) ?? '',
      label: _string(json['label']) ?? '',
      inputType: (_string(json['input_type']) ?? 'number').toLowerCase(),
      incomeType: (_string(json['income_type']) ?? 'all').toLowerCase(),
      mode: (_string(json['mode']) ?? 'advanced').toLowerCase(),
      isRequired: _bool(json['is_required']),
      defaultValue: _string(json['default_value']) ?? '',
      options: _strings(json['options']),
      helpText: _string(json['help_text']) ?? '',
    );
  }
}

class TaxCalculationInput {
  const TaxCalculationInput({
    required this.incomeType,
    required this.incomeMode,
    required this.incomeAmount,
    required this.filerStatus,
    this.taxYear,
    this.advancedInputs = const {},
  });

  final TaxIncomeType incomeType;
  final TaxIncomeMode incomeMode;
  final double incomeAmount;
  final TaxFilerStatus filerStatus;
  final String? taxYear;
  final Map<String, dynamic> advancedInputs;

  Map<String, dynamic> toJson() {
    return {
      if (taxYear != null && taxYear!.trim().isNotEmpty) 'tax_year': taxYear,
      'income_type': incomeType.key,
      'income_mode': incomeMode.key,
      'income_amount': incomeAmount,
      'filer_status': filerStatus.key,
      'advanced_inputs': advancedInputs,
    };
  }
}

class TaxCalculationResult {
  const TaxCalculationResult({
    required this.annualIncome,
    required this.taxableIncome,
    required this.estimatedAnnualTax,
    required this.monthlyTax,
    required this.monthlyTakeHome,
    required this.effectiveTaxRate,
    this.breakdown = const {},
    this.comparison,
    this.taxHealth,
    this.insights = const [],
    this.recommendedNextSteps = const [],
    this.source,
    this.cta = const TaxCta(),
    this.calculationLog,
    this.note,
  });

  final double annualIncome;
  final double taxableIncome;
  final double estimatedAnnualTax;
  final double monthlyTax;
  final double monthlyTakeHome;
  final double effectiveTaxRate;
  final Map<String, dynamic> breakdown;
  final TaxComparison? comparison;
  final TaxHealth? taxHealth;
  final List<TaxInsight> insights;
  final List<String> recommendedNextSteps;
  final TaxSource? source;
  final TaxCta cta;
  final String? calculationLog;
  final String? note;

  double get monthlyIncome => annualIncome / 12;
  double get yearlyTax => estimatedAnnualTax;
  double get monthlyAfterTax => monthlyTakeHome;
  double get yearlyAfterTax => annualIncome - estimatedAnnualTax;
  bool get isBackendResult => true;

  factory TaxCalculationResult.fromJson(Map<String, dynamic> json) {
    return TaxCalculationResult(
      annualIncome: _double(json['annual_income'] ?? json['yearly_income']),
      taxableIncome: _double(json['taxable_income']),
      estimatedAnnualTax: _double(json['estimated_annual_tax'] ?? json['yearly_tax'] ?? json['annual_tax']),
      monthlyTax: _double(json['monthly_tax']),
      monthlyTakeHome: _double(json['monthly_take_home'] ?? json['monthly_after_tax']),
      effectiveTaxRate: _double(json['effective_tax_rate']),
      breakdown: _map(json['breakdown']),
      comparison: json['comparison'] is Map ? TaxComparison.fromJson(_map(json['comparison'])) : null,
      taxHealth: json['tax_health'] is Map ? TaxHealth.fromJson(_map(json['tax_health'])) : null,
      insights: _list(json['insights']).map((item) => TaxInsight.fromJson(_map(item))).toList(growable: false),
      recommendedNextSteps: _strings(json['recommended_next_steps']),
      source: json['source'] is Map ? TaxSource.fromJson(_map(json['source'])) : null,
      cta: json['cta'] is Map ? TaxCta.fromJson(_map(json['cta'])) : const TaxCta(),
      calculationLog: _string(json['calculation_log']),
      note: _string(json['note']),
    );
  }
}

class TaxComparison {
  const TaxComparison({required this.activeFilerTax, required this.nonFilerTax, required this.possibleDifference});

  final double activeFilerTax;
  final double nonFilerTax;
  final double possibleDifference;

  factory TaxComparison.fromJson(Map<String, dynamic> json) {
    return TaxComparison(
      activeFilerTax: _double(json['active_filer_tax']),
      nonFilerTax: _double(json['non_filer_tax']),
      possibleDifference: _double(json['possible_difference']),
    );
  }
}

class TaxHealth {
  const TaxHealth({required this.score, required this.reason});

  final String score;
  final String reason;

  factory TaxHealth.fromJson(Map<String, dynamic> json) {
    return TaxHealth(score: _string(json['score']) ?? 'Medium', reason: _string(json['reason']) ?? '');
  }
}

class TaxInsight {
  const TaxInsight({
    required this.severity,
    required this.title,
    required this.message,
    this.actionLabel = '',
    this.actionType = 'None',
    this.linkedService = '',
    this.linkedArticle = '',
  });

  final String severity;
  final String title;
  final String message;
  final String actionLabel;
  final String actionType;
  final String linkedService;
  final String linkedArticle;

  factory TaxInsight.fromJson(Map<String, dynamic> json) {
    return TaxInsight(
      severity: _string(json['severity']) ?? 'Medium',
      title: _string(json['title']) ?? '',
      message: _string(json['message']) ?? '',
      actionLabel: _string(json['action_label']) ?? '',
      actionType: _string(json['action_type']) ?? 'None',
      linkedService: _string(json['linked_service']) ?? '',
      linkedArticle: _string(json['linked_article']) ?? '',
    );
  }
}

class TaxSource {
  const TaxSource({required this.taxYear, required this.verified, this.lastVerifiedOn = '', this.publicNote = ''});

  final String taxYear;
  final bool verified;
  final String lastVerifiedOn;
  final String publicNote;

  factory TaxSource.fromJson(Map<String, dynamic> json) {
    return TaxSource(
      taxYear: _string(json['tax_year']) ?? '',
      verified: _bool(json['verified']),
      lastVerifiedOn: _string(json['last_verified_on']) ?? '',
      publicNote: _string(json['public_note']) ?? '',
    );
  }
}

class TaxCta {
  const TaxCta({this.title = '', this.button = '', this.linkedService = ''});

  final String title;
  final String button;
  final String linkedService;

  factory TaxCta.fromJson(Map<String, dynamic> json) {
    return TaxCta(
      title: _string(json['title']) ?? '',
      button: _string(json['button']) ?? '',
      linkedService: _string(json['linked_service']) ?? '',
    );
  }
}

class StartTaxServiceResult {
  const StartTaxServiceResult({required this.serviceRequest, required this.message});

  final String serviceRequest;
  final String message;

  factory StartTaxServiceResult.fromJson(Map<String, dynamic> json) {
    return StartTaxServiceResult(
      serviceRequest: _string(json['service_request']) ?? '',
      message: _string(json['message']) ?? 'Tax filing service request created successfully.',
    );
  }
}

class TaxEstimatePdfResult {
  const TaxEstimatePdfResult({required this.fileName, required this.fileUrl, required this.message});

  final String fileName;
  final String fileUrl;
  final String message;

  factory TaxEstimatePdfResult.fromJson(Map<String, dynamic> json) {
    return TaxEstimatePdfResult(
      fileName: _string(json['file_name']) ?? '',
      fileUrl: _string(json['file_url']) ?? '',
      message: _string(json['message']) ?? 'Tax estimate PDF generated successfully.',
    );
  }
}

class TaxShareResult {
  const TaxShareResult({required this.message, required this.calculationLog, required this.linkedServiceRequest});

  final String message;
  final String calculationLog;
  final String linkedServiceRequest;

  factory TaxShareResult.fromJson(Map<String, dynamic> json) {
    return TaxShareResult(
      message: _string(json['message']) ?? 'Tax estimate shared with OMC consultant.',
      calculationLog: _string(json['calculation_log']) ?? '',
      linkedServiceRequest: _string(json['linked_service_request']) ?? '',
    );
  }
}

class TaxCalculationHistoryItem {
  const TaxCalculationHistoryItem({
    required this.name,
    required this.createdOn,
    required this.taxYear,
    required this.incomeType,
    required this.filerStatus,
    required this.annualIncome,
    required this.estimatedAnnualTax,
    required this.monthlyTax,
    required this.effectiveTaxRate,
    this.linkedServiceRequest = '',
  });

  final String name;
  final String createdOn;
  final String taxYear;
  final String incomeType;
  final String filerStatus;
  final double annualIncome;
  final double estimatedAnnualTax;
  final double monthlyTax;
  final double effectiveTaxRate;
  final String linkedServiceRequest;

  factory TaxCalculationHistoryItem.fromJson(Map<String, dynamic> json) {
    return TaxCalculationHistoryItem(
      name: _string(json['name']) ?? '',
      createdOn: _string(json['created_on']) ?? '',
      taxYear: _string(json['tax_year']) ?? '',
      incomeType: _string(json['income_type']) ?? '',
      filerStatus: _string(json['filer_status']) ?? '',
      annualIncome: _double(json['annual_income']),
      estimatedAnnualTax: _double(json['estimated_annual_tax']),
      monthlyTax: _double(json['monthly_tax']),
      effectiveTaxRate: _double(json['effective_tax_rate']),
      linkedServiceRequest: _string(json['linked_service_request']) ?? '',
    );
  }
}

class TaxCalculationRepository {
  const TaxCalculationRepository({required this.frappeClient});

  final FrappeClient frappeClient;

  Future<TaxCalculatorConfig> getConfig() async {
    final response = await frappeClient.getMethod(ApiConfig.taxCalculatorConfigMethod);
    return TaxCalculatorConfig.fromJson(_unwrap(response));
  }

  Future<TaxCalculationResult> calculate(TaxCalculationInput input) async {
    final response = await frappeClient.postMethod(ApiConfig.taxCalculatorMethod, data: input.toJson());
    return TaxCalculationResult.fromJson(_unwrap(response));
  }

  Future<StartTaxServiceResult> startServiceFromCalculation({required String calculationLog, required String service}) async {
    final response = await frappeClient.postMethod(
      ApiConfig.startTaxServiceFromCalculationMethod,
      data: {'calculation_log': calculationLog, 'service': service},
    );
    return StartTaxServiceResult.fromJson(_unwrap(response));
  }

  Future<List<TaxCalculationHistoryItem>> getHistory({int limit = 20}) async {
    final response = await frappeClient.getMethod(
      ApiConfig.taxCalculationHistoryMethod,
      queryParameters: {'limit': limit},
    );
    return _list(_unwrap(response)['items'])
        .map((item) => TaxCalculationHistoryItem.fromJson(_map(item)))
        .toList(growable: false);
  }

  Future<TaxEstimatePdfResult> downloadEstimatePdf(String calculationLog) async {
    final response = await frappeClient.postMethod(
      ApiConfig.downloadTaxEstimatePdfMethod,
      data: {'calculation_log': calculationLog},
    );
    return TaxEstimatePdfResult.fromJson(_unwrap(response));
  }

  Future<TaxShareResult> shareEstimateWithConsultant(String calculationLog) async {
    final response = await frappeClient.postMethod(
      ApiConfig.shareTaxEstimateWithConsultantMethod,
      data: {'calculation_log': calculationLog},
    );
    return TaxShareResult.fromJson(_unwrap(response));
  }
}

Map<String, dynamic> _unwrap(Map<String, dynamic> response) {
  final message = response['message'];
  if (message is Map<String, dynamic>) return message;
  if (message is Map) return _map(message);
  final data = response['data'];
  if (data is Map<String, dynamic>) return data;
  if (data is Map) return _map(data);
  return response;
}

Map<String, dynamic> _map(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, item) => MapEntry(key.toString(), item));
  return <String, dynamic>{};
}

List<dynamic> _list(Object? value) => value is List ? value : const [];

List<String> _strings(Object? value) {
  return _list(value)
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

String? _string(Object? value) {
  final text = value?.toString().trim();
  if (text == null || text.isEmpty) return null;
  return text;
}

double _double(Object? value) {
  if (value is num) return value.toDouble();
  final text = value?.toString().replaceAll(',', '').trim();
  if (text == null || text.isEmpty) return 0;
  return double.tryParse(text) ?? 0;
}

bool _bool(Object? value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().trim().toLowerCase();
  if (text == null || text.isEmpty) return fallback;
  if (text == '1' || text == 'true' || text == 'yes') return true;
  if (text == '0' || text == 'false' || text == 'no') return false;
  return fallback;
}
