import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/features/service_requests/data/service_request_repository.dart';

void main() {
  group('assisted customer retirement contract', () {
    test('registered customer identity ignores retired manual customer aliases', () {
      final option = AssistedCustomerOption.fromJson({
        'customer_mode': 'Existing Customer',
        'customer_id': 'OMC-CUST-0001',
        'manual_customer_id': 'OMC-MANUAL-0001',
        'full_name': 'Registered Customer',
        'email': 'customer@example.com',
        'phone': '03001234567',
      });

      expect(option.id, 'OMC-CUST-0001');
      expect(option.mode, 'Existing Customer');
      expect(option.fullName, 'Registered Customer');
    });

    test('missing registered customer identity is not promoted from legacy alias', () {
      final selection = AssistedCustomerSelection.fromResponse({
        'modes': ['My Referral', 'Existing Customer'],
        'items': [
          {
            'customer_mode': 'Existing Customer',
            'manual_customer_id': 'OMC-MANUAL-0001',
            'full_name': 'Legacy Walk In',
          },
        ],
      });

      expect(selection.modes, ['My Referral', 'Existing Customer']);
      expect(selection.items, isEmpty);
    });
  });
}
