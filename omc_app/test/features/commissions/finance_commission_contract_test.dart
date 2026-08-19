import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/features/commissions/data/finance_commission_repository.dart';

void main() {
  group('FinanceCommissionAllocation', () {
    test('uses backend allowed actions without synthesizing authority', () {
      final allocation = FinanceCommissionAllocation.fromJson({
        'id': 'COMM-0001',
        'status': 'Approved',
        'accounting_evidence_status': 'Matched',
        'allowed_actions': <String>[],
        'commission_amount': 2500,
        'currency': 'PKR',
      });

      expect(allocation.accountingReady, isTrue);
      expect(allocation.canApprove, isFalse);
      expect(allocation.canReject, isFalse);
      expect(allocation.canMarkPayable, isFalse);
      expect(allocation.canMarkPaid, isFalse);
    });

    test('parses only actions explicitly returned by backend', () {
      final allocation = FinanceCommissionAllocation.fromJson({
        'id': 'COMM-0002',
        'status': 'Payable',
        'accounting_evidence_status': 'Matched',
        'allowed_actions': ['reject', 'mark_paid'],
        'commission_amount': 1000,
        'currency': 'PKR',
      });

      expect(allocation.canApprove, isFalse);
      expect(allocation.canReject, isTrue);
      expect(allocation.canMarkPayable, isFalse);
      expect(allocation.canMarkPaid, isTrue);
    });

    test('treats non-matched evidence as not accounting ready', () {
      final allocation = FinanceCommissionAllocation.fromJson({
        'id': 'COMM-0003',
        'status': 'Calculated',
        'accounting_evidence_status': 'Review Required',
        'allowed_actions': ['reject'],
      });

      expect(allocation.accountingReady, isFalse);
      expect(allocation.canReject, isTrue);
      expect(allocation.canApprove, isFalse);
    });
  });
}
