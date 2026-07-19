import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/core/network/api_error.dart';
import 'package:omc_app/core/resilience/app_failure.dart';

void main() {
  group('authentication failure mapping', () {
    test('invalid credentials remain an authentication failure', () {
      final failure = AppFailureClassifier.classify(
        const ApiError(message: 'Incorrect password', statusCode: 401),
      );

      expect(failure.type, AppFailureType.unauthorized);
      expect(failure.canRetry, isFalse);
    });

    test('signup backend trace is not exposed', () {
      final failure = AppFailureClassifier.classify(
        const ApiError(
          message: 'Traceback at /srv/frappe/apps/omc_app/auth.py',
          statusCode: 500,
        ),
        fallbackMessage: 'Account could not be created.',
      );

      expect(failure.type, AppFailureType.serverUnavailable);
      expect(failure.message, isNot(contains('/srv/frappe')));
      expect(failure.canRetry, isTrue);
    });

    test('guest-session offline failure is retryable', () {
      final failure = AppFailureClassifier.classify(
        const ApiError(message: 'SocketException: Failed host lookup'),
      );

      expect(failure.type, AppFailureType.offline);
      expect(failure.canRetry, isTrue);
    });
  });
}
