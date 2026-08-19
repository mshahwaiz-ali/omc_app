import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/features/service_requests/data/service_case.dart';

void main() {
  group('ServiceCase canonical lifecycle contract', () {
    test('financial hold is lifecycle state, not operational status', () {
      const serviceCase = ServiceCase(
        id: 'SR-1',
        title: 'Tax filing',
        category: 'Tax',
        status: 'In Progress',
        requestState: 'Financial Hold',
        operationalStatus: 'In Progress',
        displayStatus: 'Financial Hold',
        createdAtLabel: 'Today',
        updatedAtLabel: 'Today',
        progress: 0.5,
        hold: ServiceCaseHold(
          active: true,
          reason: 'Settlement requires OMC review.',
        ),
        settlement: ServiceCaseSettlement(
          status: 'Review Required',
          reviewKind: 'human_review',
        ),
      );

      expect(serviceCase.lifecycleState, 'Financial Hold');
      expect(serviceCase.effectiveOperationalStatus, 'In Progress');
      expect(serviceCase.statusLabel, 'Financial Hold');
      expect(serviceCase.isFinancialHold, isTrue);
      expect(serviceCase.settlement.requiresReview, isTrue);
    });

    test('activated request keeps operational progress independent', () {
      const serviceCase = ServiceCase(
        id: 'SR-2',
        title: 'Company registration',
        category: 'Corporate',
        status: 'In Progress',
        requestState: 'Activated',
        operationalStatus: 'In Progress',
        displayStatus: 'In Progress',
        createdAtLabel: 'Today',
        updatedAtLabel: 'Today',
        progress: 0.7,
        activation: ServiceCaseActivation(
          state: 'Activated',
          bridgeState: 'Completed',
          activated: true,
          evidenceComplete: true,
        ),
      );

      expect(serviceCase.lifecycleState, 'Activated');
      expect(serviceCase.statusLabel, 'In Progress');
      expect(serviceCase.activation.activated, isTrue);
      expect(serviceCase.activation.evidenceComplete, isTrue);
    });

    test('technical quarantine remains distinct from human review', () {
      const serviceCase = ServiceCase(
        id: 'SR-3',
        title: 'Tax filing',
        category: 'Tax',
        status: 'Waiting for Payment',
        requestState: 'Financial Hold',
        createdAtLabel: 'Today',
        updatedAtLabel: 'Today',
        progress: 0.4,
        settlement: ServiceCaseSettlement(
          status: 'Quarantined',
          reviewKind: 'technical_quarantine',
        ),
      );

      expect(serviceCase.settlement.requiresReview, isTrue);
      expect(serviceCase.settlement.reviewKind, 'technical_quarantine');
    });

    test('no-charge request does not present payment as pending', () {
      const serviceCase = ServiceCase(
        id: 'SR-4',
        title: 'No charge service',
        category: 'General',
        status: 'Open',
        requestState: 'Ready for Activation',
        createdAtLabel: 'Today',
        updatedAtLabel: 'Today',
        progress: 0.5,
        receipt: ServiceCaseReceipt(status: 'Not Required'),
        settlement: ServiceCaseSettlement(status: 'Not Required'),
      );

      expect(serviceCase.paymentSummaryLabel, 'No payment required');
      expect(serviceCase.hasPayment, isFalse);
    });
  });
}
