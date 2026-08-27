import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P3 interaction polish contracts', () {
    test('shared motion respects reduced-motion accessibility preference', () {
      final source = File('lib/app/design_tokens.dart').readAsStringSync();

      expect(source, contains('disableAnimations'));
      expect(source, contains('Duration.zero'));
      expect(source, contains('durationFor'));
    });

    test('shared skeleton stops animation for reduced motion', () {
      final source = File(
        'lib/core/widgets/app_skeleton.dart',
      ).readAsStringSync();

      expect(source, contains('AppMotion.reducedMotion(context)'));
      expect(source, contains('..stop()'));
      expect(source, contains('_controller.repeat(reverse: true)'));
    });

    test('primary actions and navigation use centralized haptics', () {
      final feedback = File(
        'lib/core/interaction/app_feedback.dart',
      ).readAsStringSync();
      final button = File(
        'lib/core/widgets/app_button.dart',
      ).readAsStringSync();
      final nav = File(
        'lib/app/navigation/omc_bottom_nav.dart',
      ).readAsStringSync();

      expect(feedback, contains('HapticFeedback.selectionClick'));
      expect(feedback, contains('HapticFeedback.lightImpact'));
      expect(button, contains('AppFeedback.action()'));
      expect(nav, contains('AppFeedback.selection()'));
      expect(nav, contains('AppMotion.durationFor(context, AppMotion.quick)'));
    });

    test('shared loading state announces progress accessibly', () {
      final source = File(
        'lib/core/widgets/loading_view.dart',
      ).readAsStringSync();

      expect(source, contains('liveRegion: true'));
      expect(source, contains('label: message'));
    });

    test('customer service detail uses shared skeleton primitive', () {
      final screen = File(
        'lib/features/service_requests/presentation/customer_service_case_detail_screen.dart',
      ).readAsStringSync();
      final support = File(
        'lib/features/service_requests/presentation/customer_service_case_detail_support.dart',
      ).readAsStringSync();

      expect(screen, contains("app_skeleton.dart"));
      expect(support, contains('AppSkeleton(height: 170)'));
      expect(support, isNot(contains('class _LoadingCard')));
    });

    test(
      'notification repository is production-silent and capability scoped',
      () {
        final source = File(
          'lib/features/notifications/data/notifications_repository.dart',
        ).readAsStringSync();

        expect(source, contains('effectiveCapabilitiesProvider'));
        expect(source, isNot(contains('debugPrint(')));
        expect(
          source,
          isNot(contains('Missing backend notification reference')),
        );
      },
    );

    test('retired core feature placeholder stays removed', () {
      expect(
        File('lib/core/widgets/feature_placeholder_screen.dart').existsSync(),
        isFalse,
      );
    });

    test('dormant primaryRed theme alias stays retired', () {
      final source = File('lib/app/theme.dart').readAsStringSync();
      expect(source, isNot(contains('primaryRed')));
    });
  });
}
