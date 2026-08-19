import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('P3 closeout contracts', () {
    test('legacy empty-state names delegate to the shared state contract', () {
      final legacy = File('lib/core/widgets/empty_state.dart').readAsStringSync();
      final premium = File(
        'lib/core/widgets/premium_empty_state.dart',
      ).readAsStringSync();

      expect(legacy, contains('return AppEmptyState('));
      expect(premium, contains('return AppEmptyState('));
    });

    test('generic state actions do not pretend every action is a retry', () {
      final source = File('lib/core/widgets/app_state.dart').readAsStringSync();

      expect(source, contains('final IconData? actionIcon;'));
      expect(source, contains('actionIcon: Icons.refresh_rounded'));
      expect(source, contains('icon: actionIcon'));
      expect(
        source.indexOf('actionIcon: Icons.refresh_rounded'),
        lessThan(source.indexOf('class AppConfigurationState')),
      );
    });

    test('splash has no artificial startup delay and respects reduced motion', () {
      final source = File(
        'lib/features/splash/presentation/splash_screen.dart',
      ).readAsStringSync();

      expect(source, isNot(contains('Duration(milliseconds: 700)')));
      expect(source, contains('AppMotion.reducedMotion(context)'));
      expect(source, contains("label: 'Starting OMC'"));
      expect(source, contains('AppButton('));
    });

    test('identity header keeps accessible targets and labels', () {
      final source = File(
        'lib/core/widgets/omc_identity_header.dart',
      ).readAsStringSync();

      expect(source, contains('width: AppTouchTarget.minimum'));
      expect(source, contains('height: AppTouchTarget.minimum'));
      expect(source, contains("'Notifications, \$unreadNotifications unread'"));
      expect(source, contains("message: 'Open profile'"));
      expect(source, contains('AppFeedback.selection()'));
    });

    test('lead detail does not expose implementation terminology', () {
      final source = File(
        'lib/features/leads/presentation/lead_detail_screen.dart',
      ).readAsStringSync();

      expect(source, contains("title: 'Lead record'"));
      expect(source, isNot(contains("title: 'Backend lead'")));
      expect(source, isNot(contains('_backendErrorMessage')));
    });

    test('tax calculator uses canonical access and real config refresh', () {
      final source = File(
        'lib/features/tax_calculator/presentation/tax_calculator_screen.dart',
      ).readAsStringSync();

      expect(source, contains('effectiveCapabilitiesProvider'));
      expect(source, contains('Future<void> _refreshConfig() async'));
      expect(source, contains('onRefresh: _refreshConfig'));
      expect(source, contains("LoadingView(message: 'Loading tax calculator')"));
      expect(source, contains("label: 'Calculate tax'"));
      expect(source, contains('final AuthCapabilities capabilities;'));
      expect(
        source,
        isNot(contains('authState.capabilities.canCreateServiceRequest')),
      );
    });

    test('tax calculator customer copy avoids backend implementation language', () {
      final source = File(
        'lib/features/tax_calculator/presentation/tax_calculator_screen.dart',
      ).readAsStringSync();

      for (final phrase in const [
        'saved by backend',
        'backend settings',
        'Backend configured rules',
        'Backend slab calculation details',
        'Guidance from OMC backend',
        'server returned incomplete calculator configuration',
      ]) {
        expect(source, isNot(contains(phrase)), reason: 'Found: $phrase');
      }
    });
  });
}
