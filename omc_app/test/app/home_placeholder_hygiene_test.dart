import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('home and placeholder hygiene', () {
    test('active HomeScreen uses canonical capability authority', () {
      final source = File(
        'lib/features/home/presentation/home_screen_role_aware.dart',
      ).readAsStringSync();

      expect(source, contains('effectiveCapabilitiesProvider'));
      expect(
        source,
        isNot(contains('profile?.capabilities ?? authState.capabilities')),
      );
    });

    test('retired feature placeholder screen is absent', () {
      expect(
        File(
          'lib/shared/presentation/feature_placeholder_screen.dart',
        ).existsSync(),
        isFalse,
      );
    });

    test('home compatibility exports remain intact', () {
      expect(
        File(
          'lib/features/home/presentation/home_screen.dart',
        ).readAsStringSync(),
        contains("export 'home_screen_role_aware.dart';"),
      );
      expect(
        File(
          'lib/features/home/presentation/home_screen_v2.dart',
        ).readAsStringSync(),
        contains("export 'home_screen_role_aware.dart';"),
      );
    });
  });
}
