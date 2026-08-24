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

    test(
      'cancelled and expired lifecycle states are terminal even when status is open',
      () {
        const cancelled = ServiceCase(
          id: 'SR-5',
          title: 'Cancelled request',
          category: 'General',
          status: 'Open',
          requestState: 'Cancelled',
          operationalStatus: 'Open',
          createdAtLabel: 'Today',
          updatedAtLabel: 'Today',
          progress: 0.4,
        );
        const expired = ServiceCase(
          id: 'SR-6',
          title: 'Expired request',
          category: 'General',
          status: 'Open',
          requestState: 'Expired',
          operationalStatus: 'Open',
          createdAtLabel: 'Today',
          updatedAtLabel: 'Today',
          progress: 0.4,
        );

        expect(cancelled.isTerminalRequest, isTrue);
        expect(cancelled.isClosed, isTrue);
        expect(cancelled.isActiveRequest, isFalse);
        expect(expired.isTerminalRequest, isTrue);
        expect(expired.isClosed, isTrue);
        expect(expired.isActiveRequest, isFalse);
      },
    );

    test(
      'operational completion only closes an activated canonical request',
      () {
        const preActivation = ServiceCase(
          id: 'SR-7',
          title: 'Ready request',
          category: 'General',
          status: 'Completed',
          requestState: 'Ready for Activation',
          operationalStatus: 'Completed',
          createdAtLabel: 'Today',
          updatedAtLabel: 'Today',
          progress: 0.9,
        );
        const activated = ServiceCase(
          id: 'SR-8',
          title: 'Completed request',
          category: 'General',
          status: 'Completed',
          requestState: 'Activated',
          operationalStatus: 'Completed',
          createdAtLabel: 'Today',
          updatedAtLabel: 'Today',
          progress: 1,
        );

        expect(preActivation.isCompletedRequest, isFalse);
        expect(preActivation.isClosed, isFalse);
        expect(activated.isCompletedRequest, isTrue);
        expect(activated.isClosed, isTrue);
      },
    );

    test('historical completed request is closed', () {
      const serviceCase = ServiceCase(
        id: 'HIST-1',
        title: 'Historical filing',
        category: 'Tax',
        status: 'Completed',
        requestState: 'Historical',
        operationalStatus: 'Completed',
        displayStatus: 'Completed',
        createdAtLabel: '2025',
        updatedAtLabel: '2025',
        progress: 0,
      );

      expect(serviceCase.isHistoricalRequest, isTrue);
      expect(serviceCase.isCompletedRequest, isTrue);
      expect(serviceCase.isClosed, isTrue);
      expect(serviceCase.isActiveRequest, isFalse);
      expect(serviceCase.statusLabel, 'Completed');
    });

    test('historical overdue request remains active', () {
      const serviceCase = ServiceCase(
        id: 'HIST-2',
        title: 'Historical filing',
        category: 'Tax',
        status: 'Overdue',
        requestState: 'Historical',
        operationalStatus: 'Overdue',
        displayStatus: 'Overdue',
        createdAtLabel: '2026',
        updatedAtLabel: '2026',
        progress: 0,
      );

      expect(serviceCase.isHistoricalRequest, isTrue);
      expect(serviceCase.isClosed, isFalse);
      expect(serviceCase.isActiveRequest, isTrue);
      expect(serviceCase.statusLabel, 'Overdue');
    });

    test('historical record without task remains neutral and active', () {
      const serviceCase = ServiceCase(
        id: 'HIST-3',
        title: 'Historical service',
        category: 'General',
        status: 'Historical',
        requestState: 'Historical',
        operationalStatus: 'Historical',
        displayStatus: 'Historical',
        createdAtLabel: '2025',
        updatedAtLabel: '2025',
        progress: 0,
      );

      expect(serviceCase.isHistoricalRequest, isTrue);
      expect(serviceCase.isClosed, isFalse);
      expect(serviceCase.isActiveRequest, isTrue);
      expect(serviceCase.statusLabel, 'Historical');
    });

    test('historical cancelled request is terminal', () {
      const serviceCase = ServiceCase(
        id: 'HIST-4',
        title: 'Historical service',
        category: 'General',
        status: 'Cancelled',
        requestState: 'Historical',
        operationalStatus: 'Cancelled',
        displayStatus: 'Cancelled',
        createdAtLabel: '2025',
        updatedAtLabel: '2025',
        progress: 0,
      );

      expect(serviceCase.isCancelledRequest, isTrue);
      expect(serviceCase.isTerminalRequest, isTrue);
      expect(serviceCase.isClosed, isTrue);
      expect(serviceCase.isActiveRequest, isFalse);
      expect(serviceCase.statusLabel, 'Cancelled');
    });
  });
}
