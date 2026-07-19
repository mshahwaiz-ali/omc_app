import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/core/network/api_error.dart';
import 'package:omc_app/core/resilience/app_failure.dart';

void main() {
  group('profile synchronization failure mapping', () {
    test('profile refresh traceback is not exposed', () {
      final failure = AppFailureClassifier.classify(
        const ApiError(
          message: 'Traceback at /srv/frappe/apps/omc_app/profile.py',
          statusCode: 500,
        ),
        fallbackMessage: 'Profile could not be refreshed.',
      );

      expect(failure.type, AppFailureType.serverUnavailable);
      expect(failure.message, isNot(contains('/srv/frappe')));
      expect(failure.canRetry, isTrue);
    });

    test('expired profile session is classified as unauthorized', () {
      final failure = AppFailureClassifier.classify(
        const ApiError(message: 'Session expired', statusCode: 401),
      );

      expect(failure.type, AppFailureType.unauthorized);
      expect(failure.canRetry, isFalse);
    });

    test('offline profile refresh remains retryable', () {
      final failure = AppFailureClassifier.classify(
        const ApiError(message: 'SocketException: Network is unreachable'),
      );

      expect(failure.type, AppFailureType.offline);
      expect(failure.canRetry, isTrue);
    });
  });
}
