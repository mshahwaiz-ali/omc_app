import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/frappe_client.dart';

final taxCalculationRepositoryProvider = Provider<TaxCalculationRepository>((
  ref,
) {
  return TaxCalculationRepository(
    frappeClient: ref.watch(frappeClientProvider),
  );
});

enum TaxIncomeType { salary, rental, soleProprietor }

class TaxCalculationInput {
  const TaxCalculationInput({
    required this.incomeType,
    required this.monthlyIncome,
  });

  final TaxIncomeType incomeType;
  final double monthlyIncome;

  String get incomeTypeKey {
    switch (incomeType) {
      case TaxIncomeType.salary:
        return 'salary';
      case TaxIncomeType.rental:
        return 'rental';
      case TaxIncomeType.soleProprietor:
        return 'sole_proprietor';
    }
  }
}

class TaxCalculationResult {
  const TaxCalculationResult({
    required this.monthlyIncome,
    required this.yearlyIncome,
    required this.monthlyTax,
    required this.yearlyTax,
    required this.monthlyAfterTax,
    required this.yearlyAfterTax,
    required this.isBackendResult,
    this.note,
  });

  final double monthlyIncome;
  final double yearlyIncome;
  final double monthlyTax;
  final double yearlyTax;
  final double monthlyAfterTax;
  final double yearlyAfterTax;
  final bool isBackendResult;
  final String? note;
}

class TaxCalculationRepository {
  const TaxCalculationRepository({required this.frappeClient});

  final FrappeClient frappeClient;

  Future<TaxCalculationResult> calculate(TaxCalculationInput input) async {
    try {
      final response = await frappeClient.postMethod(
        ApiConfig.taxCalculatorMethod,
        data: {
          'income_type': input.incomeTypeKey,
          'monthly_income': input.monthlyIncome,
          'yearly_income': input.monthlyIncome * 12,
        },
      );

      final result = _mapBackendResult(response, input);
      if (result != null) return result;

      return _localEstimate(
        input,
        backendMessage:
            'OMC tax service did not return complete verified slab data, so this is an unofficial local estimate. Please verify with OMC before filing.',
      );
    } on ApiError catch (error) {
      return _localEstimate(
        input,
        backendMessage:
            '${error.message} Showing an unofficial local estimate only; do not treat this as a verified tax result.',
      );
    } catch (_) {
      return _localEstimate(
        input,
        backendMessage:
            'Showing an unofficial local estimate only. Final tax may vary after OMC slab verification.',
      );
    }
  }

  TaxCalculationResult? _mapBackendResult(
    Map<String, dynamic> response,
    TaxCalculationInput input,
  ) {
    final message = response['message'];
    final raw = message is Map<String, dynamic>
        ? message
        : response['data'] is Map<String, dynamic>
        ? response['data'] as Map<String, dynamic>
        : response;

    final monthlyTax = _doubleOrNull(
      raw['monthly_tax'] ?? raw['tax_per_month'],
    );
    final yearlyTax = _doubleOrNull(raw['yearly_tax'] ?? raw['annual_tax']);

    if (monthlyTax == null && yearlyTax == null) return null;

    final yearlyIncome =
        _doubleOrNull(raw['yearly_income'] ?? raw['annual_income']) ??
        input.monthlyIncome * 12;
    final monthlyIncome =
        _doubleOrNull(raw['monthly_income']) ?? yearlyIncome / 12;
    final resolvedYearlyTax = yearlyTax ?? monthlyTax! * 12;
    final resolvedMonthlyTax = monthlyTax ?? resolvedYearlyTax / 12;
    final isVerifiedBackendResult = _isVerifiedBackendResult(raw);

    return TaxCalculationResult(
      monthlyIncome: monthlyIncome,
      yearlyIncome: yearlyIncome,
      monthlyTax: resolvedMonthlyTax,
      yearlyTax: resolvedYearlyTax,
      monthlyAfterTax:
          _doubleOrNull(raw['monthly_after_tax']) ??
          monthlyIncome - resolvedMonthlyTax,
      yearlyAfterTax:
          _doubleOrNull(raw['yearly_after_tax']) ??
          yearlyIncome - resolvedYearlyTax,
      isBackendResult: isVerifiedBackendResult,
      note:
          _stringOrNull(raw['note'] ?? raw['remarks']) ??
          (isVerifiedBackendResult
              ? null
              : 'Unofficial backend estimate only. Do not use this result for filing until OMC verifies the applicable tax slabs.'),
    );
  }

  TaxCalculationResult _localEstimate(
    TaxCalculationInput input, {
    String? backendMessage,
  }) {
    final monthlyIncome = input.monthlyIncome;
    final yearlyIncome = monthlyIncome * 12;
    final yearlyTax = _estimateLocalTax(yearlyIncome);
    final monthlyTax = yearlyTax / 12;

    return TaxCalculationResult(
      monthlyIncome: monthlyIncome,
      yearlyIncome: yearlyIncome,
      monthlyTax: monthlyTax,
      yearlyTax: yearlyTax,
      monthlyAfterTax: monthlyIncome - monthlyTax,
      yearlyAfterTax: yearlyIncome - yearlyTax,
      isBackendResult: false,
      note:
          backendMessage ??
          'Showing an unofficial local estimate only. Final tax may vary after OMC slab verification.',
    );
  }

  double _estimateLocalTax(double yearlyIncome) {
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

  bool _isVerifiedBackendResult(Map<String, dynamic> raw) {
    final explicitVerified =
        raw['is_verified'] ?? raw['verified'] ?? raw['is_backend_verified'];
    if (explicitVerified != null) return _boolOrFalse(explicitVerified);

    final source = _stringOrNull(
      raw['source'] ?? raw['result_source'] ?? raw['calculation_source'],
    )?.toLowerCase();
    if (source != null) {
      if (source.contains('estimate') ||
          source.contains('fallback') ||
          source.contains('unofficial')) {
        return false;
      }
      if (source.contains('verified') || source.contains('official')) {
        return true;
      }
    }

    final note = _stringOrNull(raw['note'] ?? raw['remarks'])?.toLowerCase();
    if (note != null &&
        (note.contains('estimate') ||
            note.contains('unofficial') ||
            note.contains('not for filing'))) {
      return false;
    }

    return true;
  }

  bool _boolOrFalse(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;

    final normalized = value.toString().trim().toLowerCase();
    return normalized == '1' ||
        normalized == 'true' ||
        normalized == 'yes' ||
        normalized == 'verified' ||
        normalized == 'official';
  }

  double? _doubleOrNull(dynamic value) {
    if (value is num) return value.toDouble();

    final cleaned = value?.toString().replaceAll(',', '').trim();
    if (cleaned == null || cleaned.isEmpty) return null;

    return double.tryParse(cleaned);
  }

  String? _stringOrNull(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }
}
