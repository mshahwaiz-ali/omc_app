import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/core/network/api_error.dart';
import 'package:omc_app/core/resilience/app_failure.dart';

void main() {
  group('customer module failure mapping', () {
    test('server trace is never shown to customer', () {
      final failure = AppFailureClassifier.classify(
        const ApiError(
          message: 'Traceback at /srv/frappe/apps/omc/private.py',
          statusCode: 503,
        ),
      );

      expect(failure.type, AppFailureType.serverUnavailable);
      expect(failure.message, isNot(contains('/srv/frappe')));
      expect(failure.canRetry, isTrue);
    });

    test('forbidden customer record has no retry loop', () {
      final failure = AppFailureClassifier.classify(
        const ApiError(
          message: 'You do not have permission to access this document',
          statusCode: 403,
        ),
      );

      expect(failure.type, AppFailureType.forbidden);
      expect(failure.canRetry, isFalse);
    });

    test('missing record maps to unavailable item', () {
      final failure = AppFailureClassifier.classify(
        const ApiError(
          message: 'Document OMC Service Payment PAY-404 not found',
          statusCode: 404,
        ),
      );

      expect(failure.type, AppFailureType.notFound);
      expect(failure.title, 'Item unavailable');
    });
  });
}
