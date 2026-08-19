import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/features/home/data/home_dashboard_repository.dart';

void main() {
  test('lifecycle milestone exposes backend state without inference', () {
    const milestone = HomeDashboardLifecycleMilestone(
      key: 'payment',
      label: 'Payment',
      state: 'attention',
      detail: 'Payment is required.',
    );

    expect(milestone.isAttention, isTrue);
    expect(milestone.isComplete, isFalse);
    expect(milestone.isCurrent, isFalse);
    expect(milestone.isSkipped, isFalse);
  });

  test('activated completed snapshot exposes completed status', () {
    const snapshot = HomeDashboardServiceSnapshot(
      id: 'SR-001',
      title: 'Tax filing',
      status: 'Completed',
      customerName: 'Customer',
      requestState: 'Activated',
      operationalStatus: 'Completed',
      displayStatus: 'Completed',
      currentStage: 'Completed',
      documentSummary: HomeDashboardDocumentSummary.empty(),
      paymentSummary: HomeDashboardPaymentSummary.empty(),
      progress: 1,
    );

    expect(snapshot.isCompleted, isTrue);
    expect(snapshot.isTerminal, isFalse);
    expect(snapshot.statusLabel, 'Completed');
    expect(snapshot.stageLabel, 'Completed');
  });

  test('cancelled snapshot is terminal even when legacy status differs', () {
    const snapshot = HomeDashboardServiceSnapshot(
      id: 'SR-002',
      title: 'Registration',
      status: 'Open',
      customerName: 'Customer',
      requestState: 'Cancelled',
      operationalStatus: 'Open',
      currentStage: 'Cancelled',
      documentSummary: HomeDashboardDocumentSummary.empty(),
      paymentSummary: HomeDashboardPaymentSummary.empty(),
      progress: 0,
    );

    expect(snapshot.isTerminal, isTrue);
    expect(snapshot.isCompleted, isFalse);
    expect(snapshot.statusLabel, 'Cancelled');
  });

  test('service next action retains required flag from backend contract', () {
    const action = HomeDashboardNextAction(
      type: 'complete_payment',
      title: 'Complete payment',
      subtitle: 'Payment is required.',
      route: '/payments',
      buttonLabel: 'Open payment',
      required: true,
    );
    const snapshot = HomeDashboardServiceSnapshot(
      id: 'SR-003',
      title: 'Company filing',
      status: 'Waiting for Payment',
      customerName: 'Customer',
      requestState: 'Pending Payment',
      operationalStatus: 'Waiting for Payment',
      currentStage: 'Payment',
      nextAction: action,
      actionRequired: true,
      documentSummary: HomeDashboardDocumentSummary.empty(),
      paymentSummary: HomeDashboardPaymentSummary.empty(),
      progress: 0.45,
    );

    expect(snapshot.nextAction?.type, 'complete_payment');
    expect(snapshot.nextAction?.required, isTrue);
    expect(snapshot.actionRequired, isTrue);
    expect(snapshot.stageLabel, 'Payment');
  });
}
