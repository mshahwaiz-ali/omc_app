import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/core/network/api_error.dart';
import 'package:omc_app/features/tax_calculator/data/tax_calculation_repository.dart';

void main() {
  test('disabled configuration exposes safe state copy', () {
    final config = TaxCalculatorConfig.fromJson(const {
      'enabled': false,
      'message': 'Tax calculator is currently disabled by an administrator.',
    });

    expect(config.enabled, isFalse);
    expect(config.stateTitle, 'Tax calculator is unavailable');
    expect(config.stateMessage, contains('disabled'));
  });

  test('missing active tax year remains explicit', () {
    final config = TaxCalculatorConfig.fromJson(const {
      'enabled': false,
      'message': 'No active tax year is available.',
    });

    expect(config.stateTitle, 'Tax calculator is not configured');
    expect(config.activeTaxYear, isNull);
  });

  test('malformed response code is classified by shared mapper contract', () {
    const error = ApiError(
      message: 'The tax calculator returned an incomplete result.',
      code: 'malformed_response',
    );

    expect(error.code, 'malformed_response');
  });
}
