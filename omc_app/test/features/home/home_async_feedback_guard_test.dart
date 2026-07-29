import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Home exposes retryable async failure feedback', () {
    final home = File(
      'lib/features/home/presentation/home_screen_role_aware.dart',
    ).readAsStringSync();
    final customer = File(
      'lib/features/home/presentation/customer_guest_home_view.dart',
    ).readAsStringSync();
    final internal = File(
      'lib/features/home/presentation/internal_home_view.dart',
    ).readAsStringSync();

    expect(home, contains('final homeLoadMessage ='));
    expect(home, contains('dashboardAsync.hasError'));
    expect(home, contains('quickActionsAsync.hasError'));
    expect(home, contains('onRetryHomeLoad:'));
    expect(customer, contains('final String? loadMessage;'));
    expect(customer, contains('final VoidCallback onRetryHomeLoad;'));
    expect(home, contains('Home data could not be refreshed'));
    expect(customer, contains('message: loadMessage!'));
    expect(customer, contains('Try again'));
    expect(internal, contains('final String? loadMessage;'));
    expect(internal, contains('final VoidCallback onRetryHomeLoad;'));
    expect(internal, contains('message: loadMessage!'));
    expect(internal, contains('Try again'));
  });
}
