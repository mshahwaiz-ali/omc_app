import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/app/route_access_policy.dart';
import 'package:omc_app/features/auth/application/auth_state.dart';
import 'package:omc_app/features/commissions/data/commission_repository.dart';

void main() {
  test('commission route requires its explicit capability', () {
    const denied = AuthCapabilities(accessState: AccountAccessState.internal);
    const allowed = AuthCapabilities(
      accessState: AccountAccessState.internal,
      canViewReferralCommissions: true,
    );
    expect(canAccessRoute('/my-commissions', denied), isFalse);
    expect(canAccessRoute('/my-commissions/OMC-COM-1', allowed), isTrue);
  });

  test('immutable invoice basis and rate map from backend payload', () {
    final earning = CommissionEarning.fromJson({
      'id': 'OMC-COM-1',
      'status': 'Earned',
      'customer_name': 'Long Customer Name',
      'service_title': 'Income Tax Filing',
      'service_request': 'OMC-SR-1',
      'currency': 'PKR',
      'basis_amount': 10000,
      'commission_percent': 7.5,
      'commission_amount': 750,
      'earned_on': '2026-08-16',
    });
    expect(earning.basis, 10000);
    expect(earning.percent, 7.5);
    expect(earning.amount, 750);
    expect(earning.customer, 'Long Customer Name');
  });

  test('commission repository requests bounded pages', () {
    final source = File(
      'lib/features/commissions/data/commission_repository.dart',
    ).readAsStringSync();
    expect(source, contains("'start': start"));
    expect(source, contains("'limit': limit"));
    expect(source, contains("raw['has_more']"));
  });
}
