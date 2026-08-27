import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('home and placeholder hygiene', () {
    test('active HomeScreen exports the lifecycle dispatcher', () {
      final exportSource = File(
        'lib/features/home/presentation/home_screen.dart',
      ).readAsStringSync();
      final dispatcherSource = File(
        'lib/features/home/presentation/home_screen_dispatcher.dart',
      ).readAsStringSync();

      expect(exportSource, contains("export 'home_screen_dispatcher.dart';"));
      expect(dispatcherSource, contains('effectiveCapabilitiesProvider'));
      expect(dispatcherSource, contains('ApprovedCustomerHomeView'));
      expect(
        dispatcherSource,
        contains("'home_screen_role_aware.dart' as legacy"),
      );
    });

    test(
      'legacy guest and internal Home path uses canonical capability authority',
      () {
        final source = File(
          'lib/features/home/presentation/home_screen_role_aware.dart',
        ).readAsStringSync();

        expect(source, contains('effectiveCapabilitiesProvider'));
        expect(
          source,
          isNot(contains('profile?.capabilities ?? authState.capabilities')),
        );
      },
    );

    test('retired feature placeholder screen is absent', () {
      expect(
        File(
          'lib/shared/presentation/feature_placeholder_screen.dart',
        ).existsSync(),
        isFalse,
      );
    });

    test('obsolete HomeScreen v2 compatibility alias is absent', () {
      expect(
        File('lib/features/home/presentation/home_screen_v2.dart').existsSync(),
        isFalse,
      );
    });
  });
}
