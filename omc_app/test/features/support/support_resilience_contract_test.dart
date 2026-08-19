import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/core/network/api_error.dart';
import 'package:omc_app/features/support/data/support_repository.dart';

void main() {
  group('SupportRefreshPolicy', () {
    test('keeps automatic detail refresh network cadence bounded', () {
      expect(
        SupportRefreshPolicy.detailFreshnessWindow,
        greaterThanOrEqualTo(const Duration(seconds: 15)),
      );
      expect(
        SupportRefreshPolicy.feedRefreshInterval,
        greaterThanOrEqualTo(const Duration(seconds: 30)),
      );
    });

    test('allows stale snapshot only for transient failures', () {
      const offline = ApiError(
        message: 'offline',
        category: ApiFailureCategory.offline,
      );
      const timeout = ApiError(
        message: 'timeout',
        category: ApiFailureCategory.timeout,
      );
      const server = ApiError(message: 'server', statusCode: 503);
      const throttled = ApiError(message: 'slow down', statusCode: 429);

      expect(SupportRefreshPolicy.canReuseStale(offline), isTrue);
      expect(SupportRefreshPolicy.canReuseStale(timeout), isTrue);
      expect(SupportRefreshPolicy.canReuseStale(server), isTrue);
      expect(SupportRefreshPolicy.canReuseStale(throttled), isTrue);
    });

    test('never hides access or validation failures with stale data', () {
      const unauthorized = ApiError(
        message: 'login required',
        statusCode: 401,
        category: ApiFailureCategory.authentication,
      );
      const forbidden = ApiError(
        message: 'forbidden',
        statusCode: 403,
        category: ApiFailureCategory.authorization,
        retryable: true,
      );
      const validation = ApiError(
        message: 'invalid request',
        statusCode: 422,
        category: ApiFailureCategory.validation,
        retryable: true,
      );

      expect(SupportRefreshPolicy.canReuseStale(unauthorized), isFalse);
      expect(SupportRefreshPolicy.canReuseStale(forbidden), isFalse);
      expect(SupportRefreshPolicy.canReuseStale(validation), isFalse);
    });
  });

  test('ticket freshness remains isolated by ticket id', () {
    final firstAt = DateTime(2026, 8, 20, 1);
    final secondAt = DateTime(2026, 8, 20, 2);
    final state = SupportSyncState(
      tickets: {
        'SUP-001': SupportResourceFreshness(
          status: SupportFreshnessStatus.stale,
          lastSuccessAt: firstAt,
        ),
        'SUP-002': SupportResourceFreshness(
          status: SupportFreshnessStatus.fresh,
          lastSuccessAt: secondAt,
        ),
      },
    );

    expect(state.ticket('SUP-001').isStale, isTrue);
    expect(state.ticket('SUP-001').lastSuccessAt, firstAt);
    expect(state.ticket('SUP-002').isStale, isFalse);
    expect(state.ticket('SUP-002').lastSuccessAt, secondAt);
    expect(state.ticket('SUP-404').status, SupportFreshnessStatus.idle);
  });
}
