import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/core/network/api_error.dart';
import 'package:omc_app/core/resilience/app_failure.dart';

void main() {
  group('AppFailureClassifier', () {
    test('classifies timeout without exposing technical details', () {
      final failure = AppFailureClassifier.classify(
        TimeoutException('socket deadline at internal.host'),
      );

      expect(failure.type, AppFailureType.timeout);
      expect(failure.canRetry, isTrue);
      expect(failure.message, isNot(contains('internal.host')));
    });

    test('classifies unauthorized and forbidden independently', () {
      final unauthorized = AppFailureClassifier.classify(
        const ApiError(message: 'Unauthorized', statusCode: 401),
      );
      final forbidden = AppFailureClassifier.classify(
        const ApiError(message: 'Permission denied', statusCode: 403),
      );

      expect(unauthorized.type, AppFailureType.unauthorized);
      expect(unauthorized.title, 'Session expired');
      expect(forbidden.type, AppFailureType.forbidden);
      expect(forbidden.title, 'Access unavailable');
    });

    test('classifies missing configuration', () {
      final failure = AppFailureClassifier.classify(
        const ApiError(message: 'No payment account is configured'),
      );

      expect(failure.type, AppFailureType.configuration);
      expect(failure.canRetry, isFalse);
    });

    test('classifies malformed responses', () {
      final failure = AppFailureClassifier.classify(
        const FormatException('Unexpected character at offset 42'),
      );

      expect(failure.type, AppFailureType.malformedResponse);
      expect(failure.canRetry, isTrue);
    });

    test('uses safe fallback for unknown errors', () {
      final failure = AppFailureClassifier.classify(
        StateError('database password=secret'),
      );

      expect(failure.type, AppFailureType.unknown);
      expect(failure.message, isNot(contains('secret')));
    });
  });
}
