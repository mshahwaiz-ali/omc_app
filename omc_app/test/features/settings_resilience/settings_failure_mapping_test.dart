import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/core/network/api_error.dart';
import 'package:omc_app/core/resilience/app_failure.dart';

void main() {
  group('settings failure mapping', () {
    test('preference backend trace is not exposed', () {
      final failure = AppFailureClassifier.classify(
        const ApiError(
          message: 'Traceback at /srv/frappe/apps/omc_app/settings.py',
          statusCode: 500,
        ),
        fallbackMessage: 'Preferences could not be loaded.',
      );

      expect(failure.type, AppFailureType.serverUnavailable);
      expect(failure.message, isNot(contains('/srv/frappe')));
      expect(failure.canRetry, isTrue);
    });

    test('forbidden account request is not retryable', () {
      final failure = AppFailureClassifier.classify(
        const ApiError(
          message: 'Not permitted to create support request',
          statusCode: 403,
        ),
      );

      expect(failure.type, AppFailureType.forbidden);
      expect(failure.canRetry, isFalse);
    });

    test('offline preference save remains retryable', () {
      final failure = AppFailureClassifier.classify(
        const ApiError(message: 'SocketException: Failed host lookup'),
      );

      expect(failure.type, AppFailureType.offline);
      expect(failure.canRetry, isTrue);
    });
  });
}
