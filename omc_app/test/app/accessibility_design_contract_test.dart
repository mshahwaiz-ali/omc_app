import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/app/design_tokens.dart';
import 'package:omc_app/app/navigation/omc_bottom_nav.dart';
import 'package:omc_app/app/theme.dart';
import 'package:omc_app/core/widgets/app_button.dart';
import 'package:omc_app/core/widgets/premium_list_header.dart';

void main() {
  test('global interaction targets stay accessibility sized', () {
    expect(AppTouchTarget.minimum, greaterThanOrEqualTo(48));

    final theme = AppTheme.lightTheme;
    expect(theme.materialTapTargetSize, MaterialTapTargetSize.padded);

    final iconMinimum = theme.iconButtonTheme.style?.minimumSize?.resolve(
      <WidgetState>{},
    );
    expect(iconMinimum?.width, greaterThanOrEqualTo(48));
    expect(iconMinimum?.height, greaterThanOrEqualTo(48));

    final textMinimum = theme.textButtonTheme.style?.minimumSize?.resolve(
      <WidgetState>{},
    );
    expect(textMinimum?.height, greaterThanOrEqualTo(48));
  });

  testWidgets('bottom navigation scales and exposes meaningful semantics', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: Scaffold(
            bottomNavigationBar: OmcBottomNav(
              selectedIndex: 0,
              notificationBadgeCount: 3,
              onTabSelected: (_) {},
              onQuickActions: () {},
              onMore: () {},
              primaryColor: AppTheme.primary,
            ),
          ),
        ),
      ),
    );

    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);

    final navSize = tester.getSize(
      find.byKey(const ValueKey('omc_bottom_nav_surface')),
    );
    expect(navSize.height, greaterThan(72));
    expect(find.bySemanticsLabel('Home'), findsOneWidget);
    expect(
      find.bySemanticsLabel('More, 3 unread notifications'),
      findsOneWidget,
    );
  });

  testWidgets('loading app button announces its busy state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: AppButton(
            label: 'Save changes',
            onPressed: () {},
            isLoading: true,
            isExpanded: false,
          ),
        ),
      ),
    );

    final semantics = tester.ensureSemantics();
    addTearDown(semantics.dispose);

    expect(find.bySemanticsLabel('Save changes, loading'), findsOneWidget);
  });

  testWidgets('shared list header tolerates large text without overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: const Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 320,
                child: PremiumListHeader(
                  icon: Icons.support_agent_outlined,
                  title: 'Support workspace',
                  subtitle:
                      'Review customer conversations and operational support requests.',
                  metaLabel: 'Customer support queue',
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.bySemanticsLabel('Customer support queue'), findsOneWidget);
  });
}
