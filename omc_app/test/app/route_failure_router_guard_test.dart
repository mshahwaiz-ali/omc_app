import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('router errorBuilder uses context-aware recovery', () {
    final source = File('lib/app/router.dart').readAsStringSync();

    expect(source, contains('resolveRouteFailureRecovery'));
    expect(source, contains('primaryActionLabel: recovery.label'));
    expect(source, contains('final navigator = Navigator.of(context);'));
    expect(source, contains('navigator.canPop()'));
    expect(
      source,
      isNot(
        contains(
          "RouteFailureScreen(onGoHome: () => context.go('/home'), "
          "onGoBack: null)",
        ),
      ),
    );
  });
}
