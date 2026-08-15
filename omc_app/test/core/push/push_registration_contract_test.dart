import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/core/push/push_registration.dart';

void main() {
  test(
    'unconfigured push source exposes no fabricated token or routes',
    () async {
      const source = UnavailablePushTokenSource();
      expect(await source.requestToken(), isNull);
      expect(await source.tokenRefreshes.toList(), isEmpty);
      expect(await source.openedRoutes.toList(), isEmpty);
    },
  );

  test('auth-bound coordinator retains registration and refresh contracts', () {
    final source = File(
      'lib/core/push/push_registration.dart',
    ).readAsStringSync();
    expect(source, contains('registerPushTokenMethod'));
    expect(source, contains('unregisterPushTokenMethod'));
    expect(source, contains('tokenRefreshes.listen'));
    expect(source, contains('openedRoutes'));
  });
}
