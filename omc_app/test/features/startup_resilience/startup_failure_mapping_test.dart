import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/core/network/api_error.dart';
import 'package:omc_app/core/resilience/app_failure.dart';

void main() {
  group('startup and onboarding failure mapping', () {
    test('local startup failure has safe fallback text', () {
      final failure = AppFailureClassifier.classify(
        StateError('SharedPreferences initialization failed'),
        fallbackMessage: 'OMC could not prepare the app right now.',
      );

      expect(failure.message, isNot(contains('SharedPreferences')));
      expect(failure.canRetry, isTrue);
    });

    test('onboarding server traceback is not exposed', () {
      final failure = AppFailureClassifier.classify(
        const ApiError(
          message: 'Traceback at /srv/frappe/apps/omc_app/onboarding.py',
          statusCode: 500,
        ),
        fallbackMessage: 'Onboarding could not be completed.',
      );

      expect(failure.type, AppFailureType.serverUnavailable);
      expect(failure.message, isNot(contains('/srv/frappe')));
      expect(failure.canRetry, isTrue);
    });

    test('offline startup remains retryable', () {
      final failure = AppFailureClassifier.classify(
        const ApiError(message: 'SocketException: Network is unreachable'),
      );

      expect(failure.type, AppFailureType.offline);
      expect(failure.canRetry, isTrue);
    });
  });
}
