import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/features/internal_workspace/domain/internal_service_case.dart';

void main() {
  group('InternalServiceCase canonical lifecycle', () {
    InternalServiceCase build({
      required String requestState,
      String status = 'Open',
      String? displayStatus,
    }) {
      return InternalServiceCase.fromJson({
        'id': 'SR-1',
        'customer_name': 'Test Customer',
        'customer_profile': 'CP-1',
        'service_title': 'Tax Filing',
        'status': status,
        'operational_status': status,
        'request_state': requestState,
        'display_status': displayStatus,
        'priority': 'Medium',
        'created_at': 'Today',
        'updated_at': 'Today',
        'document_summary_label': 'No documents yet',
        'document_summary': <String, dynamic>{},
      });
    }

    test('cancelled and expired are terminal despite operational Open', () {
      final cancelled = build(
        requestState: 'Cancelled',
        displayStatus: 'Cancelled',
      );
      final expired = build(
        requestState: 'Expired',
        displayStatus: 'Expired',
      );

      expect(cancelled.isCancelled, isTrue);
      expect(cancelled.isActive, isFalse);
      expect(cancelled.statusLabel, 'Cancelled');
      expect(expired.isExpired, isTrue);
      expect(expired.isActive, isFalse);
      expect(expired.statusLabel, 'Expired');
    });

    test('pending payment is lifecycle-driven, not raw status-driven', () {
      final item = build(
        requestState: 'Pending Payment',
        displayStatus: 'Payment Required',
      );

      expect(item.isWaitingPayment, isTrue);
      expect(item.isActive, isTrue);
      expect(item.statusLabel, 'Payment Required');
    });

    test('completed requires Activated plus operational Completed', () {
      final premature = build(
        requestState: 'Ready for Activation',
        status: 'Completed',
      );
      final completed = build(
        requestState: 'Activated',
        status: 'Completed',
      );

      expect(premature.isCompleted, isFalse);
      expect(premature.isActive, isTrue);
      expect(completed.isCompleted, isTrue);
      expect(completed.isActive, isFalse);
    });
  });
}
