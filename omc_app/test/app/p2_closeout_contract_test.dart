import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P2 closeout contracts', () {
    test('active feature screens use canonical capability authority', () {
      const paths = [
        'lib/features/service_requests/presentation/my_services_screen.dart',
        'lib/features/service_requests/presentation/customer_service_case_detail_screen.dart',
        'lib/features/expense_tracker/presentation/expense_tracker_screen.dart',
      ];

      for (final path in paths) {
        final source = File(path).readAsStringSync();
        expect(
          source,
          contains('effectiveCapabilitiesProvider'),
          reason: '$path must consume the canonical effective capabilities.',
        );
        expect(
          source,
          isNot(contains('profile?.capabilities ?? authState.capabilities')),
          reason: '$path must not recreate profile/session precedence.',
        );
        expect(
          source,
          isNot(contains('ref.watch(authControllerProvider).capabilities')),
          reason: '$path must not bypass the effective capability provider.',
        );
      }
    });

    test('retired Home compatibility alias stays removed', () {
      expect(
        File('lib/features/home/presentation/home_screen_v2.dart').existsSync(),
        isFalse,
      );
    });

    test('My Services does not retain superseded header widgets', () {
      final source = File(
        'lib/features/service_requests/presentation/my_services_screen.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('class _Header extends StatelessWidget')));
      expect(source, isNot(contains('class _TopActionBadge')));
      expect(source, isNot(contains('class _Avatar')));
      expect(source, isNot(contains('// ignore: unused_element')));
    });

    test('internal-only expense message avoids Desk terminology', () {
      final source = File(
        'lib/features/expense_tracker/presentation/expense_tracker_screen.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('use Desk for customer review')));
      expect(
        source,
        contains('use the internal workspace for customer review'),
      );
    });
  });
}
