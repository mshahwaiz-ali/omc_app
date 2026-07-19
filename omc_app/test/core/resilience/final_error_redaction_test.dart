import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/core/network/api_error.dart';
import 'package:omc_app/core/resilience/app_failure.dart';

void main() {
  group('final UI error redaction sweep', () {
    test('server implementation details are never exposed', () {
      final failure = AppFailureClassifier.classify(
        const ApiError(
          message:
              'Traceback File "/srv/frappe/apps/omc_app/internal.py", line 42',
          statusCode: 500,
        ),
        fallbackMessage: 'Data could not be loaded.',
      );

      expect(failure.message, isNot(contains('Traceback')));
      expect(failure.message, isNot(contains('/srv/frappe')));
      expect(failure.canRetry, isTrue);
    });

    test('permission failure remains safe and non-retryable', () {
      final failure = AppFailureClassifier.classify(
        const ApiError(
          message: 'frappe.PermissionError: Not permitted',
          statusCode: 403,
        ),
      );

      expect(failure.type, AppFailureType.forbidden);
      expect(failure.message, isNot(contains('frappe.PermissionError')));
      expect(failure.canRetry, isFalse);
    });
  });
}
