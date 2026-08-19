import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/features/payments/data/finance_reconciliation_repository.dart';

void main() {
  group('Finance reconciliation contract', () {
    test('uses backend allowed_actions without inferring authority', () {
      final openWithoutActions = FinanceReconciliationItem.fromJson({
        'name': 'REV-1',
        'status': 'Open',
        'reason_code': 'payment_party_mismatch',
        'allowed_actions': const <String>[],
      });

      expect(openWithoutActions.canResolve, isFalse);
      expect(openWithoutActions.canIgnore, isFalse);

      final backendAuthorized = FinanceReconciliationItem.fromJson({
        'name': 'REV-2',
        'status': 'Open',
        'allowed_actions': const ['resolve', 'ignore'],
      });
      expect(backendAuthorized.canResolve, isTrue);
      expect(backendAuthorized.canIgnore, isTrue);
    });

    test('preserves paginated next_start contract', () {
      final page = FinanceReconciliationPage.fromJson({
        'items': [
          {'name': 'REV-1'},
          {'name': 'REV-2'},
        ],
        'limit_start': 20,
        'limit_page_length': 20,
        'has_more': true,
        'next_start': 22,
      });

      expect(page.start, 20);
      expect(page.pageLength, 20);
      expect(page.hasMore, isTrue);
      expect(page.nextStart, 22);
      expect(page.items, hasLength(2));
    });

    test('keeps redacted evidence as structured display data', () {
      final item = FinanceReconciliationItem.fromJson({
        'name': 'REV-1',
        'evidence': {
          'payment_entry': 'ACC-PAY-1',
          'sales_invoice': 'ACC-SINV-1',
        },
      });

      expect(item.evidence['payment_entry'], 'ACC-PAY-1');
      expect(item.evidence['sales_invoice'], 'ACC-SINV-1');
    });
  });
}
