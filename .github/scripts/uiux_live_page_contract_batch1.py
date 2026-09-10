from pathlib import Path


def once(text, old, new, label):
    count = text.count(old)
    if count != 1:
        raise SystemExit(f'{label}: expected one anchor, found {count}')
    return text.replace(old, new, 1)


def exact_count(text, old, new, count, label):
    actual = text.count(old)
    if actual != count:
        raise SystemExit(f'{label}: expected {count} anchors, found {actual}')
    return text.replace(old, new)


premium_path = Path('omc_app/lib/core/widgets/omc_premium.dart')
premium = premium_path.read_text()
marker = 'class OmcSurface extends StatelessWidget {'
primitive = '''class OmcPageListView extends StatelessWidget {
  const OmcPageListView({
    required this.children,
    super.key,
    this.topPadding = AppSpacing.lg,
    this.bottomPadding = AppSpacing.xl,
    this.controller,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.physics = const AlwaysScrollableScrollPhysics(
      parent: BouncingScrollPhysics(),
    ),
    this.maxWidth = AppLayout.generalMaxWidth,
  });

  final List<Widget> children;
  final double topPadding;
  final double bottomPadding;
  final ScrollController? controller;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;
  final ScrollPhysics physics;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final inset = AppLayout.pageInsetFor(constraints.maxWidth);
        final horizontal = constraints.maxWidth > maxWidth + inset * 2
            ? (constraints.maxWidth - maxWidth) / 2
            : inset;
        return ListView(
          controller: controller,
          keyboardDismissBehavior: keyboardDismissBehavior,
          physics: physics,
          padding: EdgeInsets.fromLTRB(
            horizontal,
            topPadding,
            horizontal,
            bottomPadding,
          ),
          children: children,
        );
      },
    );
  }
}

'''
if 'class OmcPageListView extends StatelessWidget' not in premium:
    premium = once(premium, marker, primitive + marker, 'responsive page primitive insertion')
premium_path.write_text(premium)

# E002 guest/pending/rejected Home: live list owner delegated from HomeScreen.
guest_path = Path('omc_app/lib/features/home/presentation/customer_guest_home_view.dart')
guest = guest_path.read_text()
guest_old = '''          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, AppSpacing.xl),
            children: ['''
guest_new = '''          child: OmcPageListView(
            topPadding: 18,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            children: ['''
guest = once(guest, guest_old, guest_new, 'guest home root page')
guest = guest.replace(
    'borderRadius: BorderRadius.circular(999),',
    'borderRadius: BorderRadius.circular(AppRadius.pill),',
)
guest_path.write_text(guest)

# E003 internal Home: routed internal owner.
internal_path = Path('omc_app/lib/features/home/presentation/internal_home_view.dart')
internal = internal_path.read_text()
internal_old = '''          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, AppSpacing.xl),
            children: ['''
internal_new = '''          child: OmcPageListView(
            topPadding: 18,
            children: ['''
internal = once(internal, internal_old, internal_new, 'internal home root page')
internal = internal.replace(
    'borderRadius: BorderRadius.circular(999),',
    'borderRadius: BorderRadius.circular(AppRadius.pill),',
)
# Queue counts and availability are operational information, not tertiary metadata.
internal = once(
    internal,
    '''                                      Text(
                                        '$count items',
                                        style: const TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),''',
    '''                                      Text(
                                        '$count items',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: AppTheme.textSecondary,
                                            ),
                                      ),''',
    'internal queue count typography',
)
internal = once(
    internal,
    '''                Text(
                  available
                      ? metric.value == 0
                            ? '0 items'
                            : '${metric.value} items'
                      : 'Not available for this role',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),''',
    '''                Text(
                  available
                      ? metric.value == 0
                            ? '0 items'
                            : '${metric.value} items'
                      : 'Not available for this role',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textSecondary,
                  ),
                ),''',
    'internal metric availability typography',
)
internal = once(
    internal,
    '''                          Text(
                            status,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),''',
    '''                          Text(
                            status,
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),''',
    'internal activity status typography',
)
internal = once(
    internal,
    'padding: const EdgeInsets.all(14),\n      child: LayoutBuilder(',
    'padding: const EdgeInsets.all(AppSpacing.md),\n      child: LayoutBuilder(',
    'internal load notice compact padding',
)
internal_path.write_text(internal)

# E004 Dashboard customer/internal variants.
dash_path = Path('omc_app/lib/features/dashboard/presentation/dashboard_screen.dart')
dash = dash_path.read_text()
dash_old = '''    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      children: ['''
dash_new = '''    return OmcPageListView(
      topPadding: 18,
      bottomPadding: 32,
      children: ['''
dash = exact_count(dash, dash_old, dash_new, 2, 'dashboard customer/internal pages')
dash = dash.replace(
    'borderRadius: BorderRadius.circular(999),',
    'borderRadius: BorderRadius.circular(AppRadius.pill),',
)
# Dashboard already imports the premium primitives; AppRadius is needed for tokenized pills.
if "import '../../../app/design_tokens.dart';" not in dash:
    dash = once(
        dash,
        "import 'package:go_router/go_router.dart';\n\n",
        "import 'package:go_router/go_router.dart';\n\nimport '../../../app/design_tokens.dart';\n",
        'dashboard design token import',
    )
dash_path.write_text(dash)

# E016 Payments: list, empty, error and loading states all share the same page contract.
payments_path = Path('omc_app/lib/features/payments/presentation/payments_screen.dart')
payments = payments_path.read_text()
payments_old = '''    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, AppSpacing.xl),
      children: ['''
payments_new = '''    return OmcPageListView(
      topPadding: 16,
      children: ['''
payments = exact_count(payments, payments_old, payments_new, 4, 'payments page states')
payments = payments.replace(
    'borderRadius: BorderRadius.circular(12),',
    'borderRadius: BorderRadius.circular(AppRadius.control),',
)
payments_path.write_text(payments)

# Notifications list/error/loading states use the same responsive page contract.
notifications_path = Path('omc_app/lib/features/notifications/presentation/notifications_screen.dart')
notifications = notifications_path.read_text()
main_old = '''              return ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, AppSpacing.xl),
                children: ['''
main_new = '''              return OmcPageListView(
                topPadding: 16,
                children: ['''
notifications = once(notifications, main_old, main_new, 'notifications main page')
state_old = '''    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, AppSpacing.xl),
      children: ['''
state_new = '''    return OmcPageListView(
      topPadding: 16,
      children: ['''
notifications = exact_count(notifications, state_old, state_new, 2, 'notifications state pages')
notifications = notifications.replace(
    'borderRadius: BorderRadius.circular(16),',
    'borderRadius: BorderRadius.circular(AppRadius.card),',
)
notifications = notifications.replace(
    'borderRadius: BorderRadius.circular(12),',
    'borderRadius: BorderRadius.circular(AppRadius.control),',
)
# Notification type is categorical status; reference/timestamp remain caption metadata.
notifications = once(
    notifications,
    '''                          Text(
                            item.type.label,
                            style: TextStyle(
                              color: color,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),''',
    '''                          Text(
                            item.type.label,
                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: color,
                            ),
                          ),''',
    'notification type status typography',
)
notifications_path.write_text(notifications)

# Source-level contract test for the routed ownership and responsive primitive.
test_path = Path('omc_app/test/app/uiux_live_page_contract_batch1_test.dart')
test_path.write_text(r'''import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  String read(String path) => File(path).readAsStringSync();

  test('V2 responsive page primitive implements C2 insets and bounded width', () {
    final source = read('lib/core/widgets/omc_premium.dart');
    final start = source.indexOf('class OmcPageListView');
    final end = source.indexOf('class OmcSurface', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));
    final block = source.substring(start, end);
    expect(block, contains('AppLayout.pageInsetFor(constraints.maxWidth)'));
    expect(block, contains('maxWidth = AppLayout.generalMaxWidth'));
    expect(block, contains('(constraints.maxWidth - maxWidth) / 2'));
  });

  test('live Home owners use responsive page primitive', () {
    final dispatcher = read('lib/features/home/presentation/home_screen_dispatcher.dart');
    final roleAware = read('lib/features/home/presentation/home_screen_role_aware.dart');
    final guest = read('lib/features/home/presentation/customer_guest_home_view.dart');
    final internal = read('lib/features/home/presentation/internal_home_view.dart');
    expect(dispatcher, contains("'home_screen_role_aware.dart' as legacy"));
    expect(roleAware, contains('CustomerGuestHomeView('));
    expect(roleAware, contains('InternalHomeView('));
    expect(guest, contains('child: OmcPageListView('));
    expect(internal, contains('child: OmcPageListView('));
    expect(guest, isNot(contains('padding: const EdgeInsets.fromLTRB(20, 18, 20, AppSpacing.xl)')));
    expect(internal, isNot(contains('padding: const EdgeInsets.fromLTRB(20, 18, 20, AppSpacing.xl)')));
  });

  test('live Dashboard, Payments and Notifications page states use C2 primitive', () {
    final router = read('lib/app/router.dart');
    final dashboard = read('lib/features/dashboard/presentation/dashboard_screen.dart');
    final payments = read('lib/features/payments/presentation/payments_screen.dart');
    final notifications = read('lib/features/notifications/presentation/notifications_screen.dart');
    expect(router, contains('const DashboardScreen()'));
    expect(router, contains('const PaymentsScreen()'));
    expect(router, contains('const NotificationsScreen()'));
    expect('OmcPageListView('.allMatches(dashboard).length, greaterThanOrEqualTo(2));
    expect('OmcPageListView('.allMatches(payments).length, greaterThanOrEqualTo(4));
    expect('OmcPageListView('.allMatches(notifications).length, greaterThanOrEqualTo(3));
    expect(dashboard, isNot(contains('padding: const EdgeInsets.fromLTRB(20, 18, 20, 32)')));
    expect(payments, isNot(contains('padding: const EdgeInsets.fromLTRB(20, 16, 20, AppSpacing.xl)')));
    expect(notifications, isNot(contains('padding: const EdgeInsets.fromLTRB(20, 16, 20, AppSpacing.xl)')));
  });

  test('meaningful operational statuses do not use caption typography', () {
    final internal = read('lib/features/home/presentation/internal_home_view.dart');
    final notifications = read('lib/features/notifications/presentation/notifications_screen.dart');
    expect(internal, contains('textTheme.labelMedium?.copyWith'));
    expect(internal, contains('textTheme.bodyMedium'));
    expect(notifications, contains('item.type.label'));
    expect(notifications, contains('textTheme.labelMedium?.copyWith'));
  });
}
''')
