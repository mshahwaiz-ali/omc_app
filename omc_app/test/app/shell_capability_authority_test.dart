import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('app shell capability authority', () {
    test('all shell navigation surfaces use effectiveCapabilitiesProvider', () {
      final mainShell = File('lib/app/main_shell.dart').readAsStringSync();
      final detailShell = File(
        'lib/app/shell_nav_scaffold.dart',
      ).readAsStringSync();
      final router = File('lib/app/router.dart').readAsStringSync();

      for (final source in [mainShell, detailShell, router]) {
        expect(
          source,
          contains('effectiveCapabilitiesProvider'),
          reason:
              'Router and shell navigation must consume the canonical '
              'effective capability authority.',
        );
      }
    });

    test('shell files do not merge profile and auth capabilities directly', () {
      for (final path in const [
        'lib/app/main_shell.dart',
        'lib/app/shell_nav_scaffold.dart',
      ]) {
        final source = File(path).readAsStringSync();

        expect(
          source,
          isNot(contains('profile?.capabilities ?? authState.capabilities')),
          reason:
              '$path must not recreate a competing capability precedence rule.',
        );
        expect(
          source,
          isNot(
            contains(
              'profile?.capabilities ??\n'
              '        ref.read(authControllerProvider).capabilities',
            ),
          ),
          reason:
              '$path must not recreate a competing capability precedence rule.',
        );
      }
    });

    test('canonical provider owns profile-to-session fallback', () {
      final source = File(
        'lib/app/providers/effective_capabilities_provider.dart',
      ).readAsStringSync();

      expect(source, contains('profile?.capabilities ?? sessionCapabilities'));
      expect(source, contains('orElse: () => sessionCapabilities'));
    });
  });
}
