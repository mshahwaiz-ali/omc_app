import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/core/network/api_error.dart';
import 'package:omc_app/core/resilience/app_failure.dart';

void main() {
  group('internal module failure mapping', () {
    test('expired internal session requires sign in instead of retry', () {
      final failure = AppFailureClassifier.classify(
        const ApiError(
          message: 'Authentication required for internal workspace',
          statusCode: 401,
        ),
      );

      expect(failure.type, AppFailureType.unauthorized);
      expect(failure.title, 'Session expired');
      expect(failure.canRetry, isFalse);
    });

    test('internal permission denial does not expose backend details', () {
      final failure = AppFailureClassifier.classify(
        const ApiError(
          message:
              'frappe.exceptions.PermissionError at /srv/frappe/apps/omc_app',
          statusCode: 403,
        ),
      );

      expect(failure.type, AppFailureType.forbidden);
      expect(failure.message, isNot(contains('/srv/frappe')));
      expect(failure.canRetry, isFalse);
    });

    test('temporary queue failure remains retryable', () {
      final failure = AppFailureClassifier.classify(
        const ApiError(message: 'Service Unavailable', statusCode: 503),
      );

      expect(failure.type, AppFailureType.serverUnavailable);
      expect(failure.canRetry, isTrue);
    });
  });
}
