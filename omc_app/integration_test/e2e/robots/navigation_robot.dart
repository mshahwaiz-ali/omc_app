import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/core/diagnostics/omc_widget_keys.dart';

import '../support/e2e_waits.dart';

class NavigationRobot {
  NavigationRobot(this.tester, this.waits);

  final WidgetTester tester;
  final E2eWaits waits;

  static const _moreDestinations = <_MoreDestination>[
    _MoreDestination(
      label: 'Documents',
      actionId: 'documents',
      screenKey: OmcWidgetKeys.documentsScreen,
      requiredForCustomer: true,
    ),
    _MoreDestination(
      label: 'Payments',
      actionId: 'payments',
      screenKey: OmcWidgetKeys.paymentsScreen,
    ),
    _MoreDestination(
      label: 'Alerts',
      actionId: 'alerts',
      screenKey: OmcWidgetKeys.notificationsScreen,
    ),
    _MoreDestination(
      label: 'Tax',
      actionId: 'tax',
      screenKey: OmcWidgetKeys.taxScreen,
    ),
    _MoreDestination(
      label: 'Expense',
      actionId: 'expense',
      screenKey: OmcWidgetKeys.expenseScreen,
    ),
    _MoreDestination(
      label: 'Budget',
      actionId: 'budget',
      screenKey: OmcWidgetKeys.budgetScreen,
    ),
    _MoreDestination(
      label: 'Knowledge',
      actionId: 'knowledge',
      screenKey: OmcWidgetKeys.knowledgeScreen,
    ),
    _MoreDestination(
      label: 'Support',
      actionId: 'support',
      screenKey: OmcWidgetKeys.supportScreen,
    ),
    _MoreDestination(
      label: 'Profile',
      actionId: 'profile',
      screenKey: OmcWidgetKeys.profileScreen,
      requiredForCustomer: true,
    ),
    _MoreDestination(
      label: 'Settings',
      actionId: 'settings',
      screenKey: OmcWidgetKeys.settingsScreen,
      requiredForCustomer: true,
    ),
  ];

  Future<void> smokePrimaryNavigation() async {
    await _openPrimary(
      label: 'Home',
      navKey: OmcWidgetKeys.navHome,
      screenKey: OmcWidgetKeys.homeScreen,
    );
    await _openPrimary(
      label: 'Services',
      navKey: OmcWidgetKeys.navServices,
      screenKey: OmcWidgetKeys.servicesScreen,
    );
    await _openPrimary(
      label: 'Track / My Services',
      navKey: OmcWidgetKeys.navTrack,
      screenKey: OmcWidgetKeys.trackScreen,
    );
    await _openPrimary(
      label: 'Home',
      navKey: OmcWidgetKeys.navHome,
      screenKey: OmcWidgetKeys.homeScreen,
    );
  }

  Future<void> smokeMoreDestinations() async {
    for (final destination in _moreDestinations) {
      await _openMore();
      final action = find.byKey(OmcWidgetKeys.moreAction(destination.actionId));
      if (action.evaluate().isEmpty) {
        if (destination.requiredForCustomer) {
          fail(
            'More did not expose required normal-customer destination '
            '${destination.label}. Use an approved customer E2E persona.',
          );
        }
        debugPrint(
          'E2E navigation: ${destination.label} is not available to this '
          'persona/configuration; no route was invented.',
        );
        await _dismissMore();
        continue;
      }

      await waits.tapAndWait(
        target: action,
        destination: find.byKey(destination.screenKey),
        description: 'Navigation smoke: More -> ${destination.label}',
      );
      await _openPrimary(
        label: 'Home after ${destination.label}',
        navKey: OmcWidgetKeys.navHome,
        screenKey: OmcWidgetKeys.homeScreen,
      );
    }
  }

  Future<void> _openPrimary({
    required String label,
    required Key navKey,
    required Key screenKey,
  }) async {
    await waits.tapAndWait(
      target: find.byKey(navKey),
      destination: find.byKey(screenKey),
      description: 'Navigation smoke: $label',
    );
  }

  Future<void> _openMore() async {
    await waits.tapAndWait(
      target: find.byKey(OmcWidgetKeys.navMore),
      destination: find.byKey(OmcWidgetKeys.moreScreen),
      description: 'Navigation smoke: More',
    );
  }

  Future<void> _dismissMore() async {
    await tester.pageBack();
    await tester.pump();
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (find.byKey(OmcWidgetKeys.moreScreen).evaluate().isNotEmpty &&
        DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    if (find.byKey(OmcWidgetKeys.moreScreen).evaluate().isNotEmpty) {
      fail('More sheet did not dismiss within 5s.');
    }
    waits.assertHealthy('Dismiss More');
  }
}

class _MoreDestination {
  const _MoreDestination({
    required this.label,
    required this.actionId,
    required this.screenKey,
    this.requiredForCustomer = false,
  });

  final String label;
  final String actionId;
  final Key screenKey;
  final bool requiredForCustomer;
}
