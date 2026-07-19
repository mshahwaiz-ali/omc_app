import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/core/network/api_error.dart';
import 'package:omc_app/core/resilience/app_failure.dart';

void main() {
  group('request and support mutation resilience', () {
    test('support reply failure does not expose backend trace', () {
      final failure = AppFailureClassifier.classify(
        const ApiError(
          message: 'Traceback at /srv/frappe/apps/omc_app/support.py',
          statusCode: 500,
        ),
        fallbackMessage: 'Message could not be sent.',
      );

      expect(failure.type, AppFailureType.serverUnavailable);
      expect(failure.message, isNot(contains('/srv/frappe')));
      expect(failure.canRetry, isTrue);
    });

    test('forbidden ticket mutation is not retryable', () {
      final failure = AppFailureClassifier.classify(
        const ApiError(
          message: 'Permission denied for support ticket',
          statusCode: 403,
        ),
      );

      expect(failure.type, AppFailureType.forbidden);
      expect(failure.canRetry, isFalse);
    });

    test('missing request form service is safely classified', () {
      final failure = AppFailureClassifier.classify(
        const ApiError(message: 'Service does not exist', statusCode: 404),
      );

      expect(failure.type, AppFailureType.notFound);
      expect(failure.message, isNot(contains('Service does not exist')));
    });

    test('attachment timeout remains retryable', () {
      final failure = AppFailureClassifier.classify(
        const ApiError(message: 'Gateway timeout', statusCode: 504),
      );

      expect(failure.type, AppFailureType.serverUnavailable);
      expect(failure.canRetry, isTrue);
    });
  });
}
