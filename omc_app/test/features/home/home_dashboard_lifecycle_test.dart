import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/features/home/data/home_dashboard_repository.dart';

void main() {
  group('Home dashboard service lifecycle labels', () {
    HomeDashboardServiceSnapshot build({
      required String requestState,
      String status = 'Open',
      String? displayStatus,
    }) {
      return HomeDashboardServiceSnapshot(
        id: 'SR-1',
        title: 'Tax Filing',
        status: status,
        customerName: 'Test Customer',
        requestState: requestState,
        operationalStatus: status,
        displayStatus: displayStatus,
        documentSummary: const HomeDashboardDocumentSummary.empty(),
        paymentSummary: const HomeDashboardPaymentSummary.empty(),
        progress: 0.5,
      );
    }

    test('pending payment displays canonical lifecycle label', () {
      final item = build(
        requestState: 'Pending Payment',
        displayStatus: 'Payment Required',
      );

      expect(item.lifecycleState, 'Pending Payment');
      expect(item.statusLabel, 'Payment Required');
      expect(item.isTerminal, isFalse);
    });

    test('cancelled lifecycle wins over operational Open', () {
      final item = build(requestState: 'Cancelled', displayStatus: 'Cancelled');

      expect(item.statusLabel, 'Cancelled');
      expect(item.isTerminal, isTrue);
    });

    test('completion requires Activated plus operational Completed', () {
      final premature = build(
        requestState: 'Ready for Activation',
        status: 'Completed',
      );
      final completed = build(requestState: 'Activated', status: 'Completed');

      expect(premature.isCompleted, isFalse);
      expect(completed.isCompleted, isTrue);
    });
  });
}
