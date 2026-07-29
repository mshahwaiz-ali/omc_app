import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('forbidden redirects surface a one-time shell notice', () {
    final redirectSource = File(
      'lib/app/auth_route_redirect.dart',
    ).readAsStringSync();
    final routerSource = File('lib/app/router.dart').readAsStringSync();
    final shellSource = File('lib/app/main_shell.dart').readAsStringSync();

    expect(redirectSource, contains('access-denied'));
    expect(redirectSource, contains('_accessDeniedHome'));
    expect(
      routerSource,
      contains("state.uri.queryParameters['notice'] == 'access-denied'"),
    );
    expect(routerSource, contains('showAccessDeniedNotice:'));
    expect(shellSource, contains('showAccessDeniedNotice'));
    expect(shellSource, contains('_showLockedSnack(_currentCapabilities())'));
  });
}
