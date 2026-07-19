import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/core/network/api_error.dart';
import 'package:omc_app/core/resilience/app_failure.dart';

void main() {
  group('detail and mutation failure mapping', () {
    test('receipt upload never exposes backend trace details', () {
      final failure = AppFailureClassifier.classify(
        const ApiError(
          message: 'Traceback at /srv/frappe/apps/omc_app/payment.py',
          statusCode: 503,
        ),
        fallbackMessage: 'Receipt upload failed.',
      );

      expect(failure.type, AppFailureType.serverUnavailable);
      expect(failure.message, isNot(contains('/srv/frappe')));
      expect(failure.canRetry, isTrue);
    });

    test('deleted detail records are non-retryable', () {
      final failure = AppFailureClassifier.classify(
        const ApiError(
          message: 'OMC Notification NOTIF-404 not found',
          statusCode: 404,
        ),
      );

      expect(failure.type, AppFailureType.notFound);
      expect(failure.canRetry, isFalse);
    });

    test('permission denial is safe and non-retryable', () {
      final failure = AppFailureClassifier.classify(
        const ApiError(
          message: 'Permission denied for OMC Service Payment',
          statusCode: 403,
        ),
      );

      expect(failure.type, AppFailureType.forbidden);
      expect(failure.message, isNot(contains('OMC Service Payment')));
      expect(failure.canRetry, isFalse);
    });

    test('temporary mutation timeout remains retryable', () {
      final failure = AppFailureClassifier.classify(
        const ApiError(message: 'Gateway timeout', statusCode: 504),
        fallbackMessage: 'The update could not be completed.',
      );

      expect(failure.type, AppFailureType.serverUnavailable);
      expect(failure.canRetry, isTrue);
    });
  });
}
