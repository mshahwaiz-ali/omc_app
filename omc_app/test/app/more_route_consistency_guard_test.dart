import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('/more uses guarded route-triggered sheet semantics', () {
    final router = File('lib/app/router.dart').readAsStringSync();
    final shell = File('lib/app/main_shell.dart').readAsStringSync();

    expect(router, contains('showMoreOnLoad: true'));
    expect(router, isNot(contains("const MainShell(initialIndex: 4)")));
    expect(shell, contains('final bool showMoreOnLoad;'));
    expect(shell, contains('bool _isMoreSheetOpen = false;'));
    expect(shell, contains('if (_isMoreSheetOpen) return;'));
    expect(shell, contains('await showOmcMoreSheet('));
    expect(shell, contains("state.uri.path == '/more'"));
    expect(shell, contains("context.go('/home')"));
    expect(shell, contains('onMore: _showMoreSheet'));
  });
}
