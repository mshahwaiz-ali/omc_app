import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/core/network/api_error.dart';
import 'package:omc_app/core/resilience/app_failure.dart';

void main() {
  group('knowledge failure mapping', () {
    test('server traceback is not exposed to readers', () {
      final failure = AppFailureClassifier.classify(
        const ApiError(
          message: 'Traceback at /srv/frappe/apps/omc_app/knowledge.py',
          statusCode: 500,
        ),
        fallbackMessage: 'Knowledge could not be loaded.',
      );

      expect(failure.type, AppFailureType.serverUnavailable);
      expect(failure.message, isNot(contains('/srv/frappe')));
      expect(failure.canRetry, isTrue);
    });

    test('missing article is classified as not found', () {
      final failure = AppFailureClassifier.classify(
        const ApiError(
          message: 'Knowledge article does not exist',
          statusCode: 404,
        ),
      );

      expect(failure.type, AppFailureType.notFound);
      expect(failure.canRetry, isFalse);
    });

    test('offline knowledge load is retryable', () {
      final failure = AppFailureClassifier.classify(
        const ApiError(message: 'SocketException: Network is unreachable'),
      );

      expect(failure.type, AppFailureType.offline);
      expect(failure.canRetry, isTrue);
    });
  });
}
