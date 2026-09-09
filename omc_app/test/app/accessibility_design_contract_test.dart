import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/app/design_tokens.dart';
import 'package:omc_app/app/navigation/omc_bottom_nav.dart';
import 'package:omc_app/app/theme.dart';
import 'package:omc_app/core/widgets/app_button.dart';
import 'package:omc_app/core/widgets/omc_premium.dart';
import 'package:omc_app/core/widgets/premium_list_header.dart';
import 'package:omc_app/features/app_config/presentation/app_brand_registry.dart';

void main() {
  test('design system v2 exposes the approved semantic scale', () {
    final theme = AppTheme.lightTheme;

    expect(theme.textTheme.headlineLarge?.fontSize, 30);
    expect(theme.textTheme.headlineLarge?.fontWeight, FontWeight.w700);
    expect(theme.textTheme.headlineMedium?.fontSize, 26);
    expect(theme.textTheme.titleLarge?.fontSize, 21);
    expect(theme.textTheme.titleLarge?.fontWeight, FontWeight.w600);
    expect(theme.textTheme.titleMedium?.fontSize, 17);
    expect(theme.textTheme.bodyLarge?.fontSize, 16);
    expect(theme.textTheme.bodyMedium?.fontSize, 15);
    expect(theme.textTheme.bodySmall?.fontSize, 13);
    expect(theme.textTheme.amount.fontSize, 28);
    expect(theme.textTheme.amountSecondary.fontSize, 20);

    expect(AppRadius.control, 12);
    expect(AppRadius.card, 16);
    expect(AppRadius.dialog, 20);
    expect(AppRadius.sheet, 24);
    expect(AppLayout.pageInsetFor(320), 16);
    expect(AppLayout.pageInsetFor(390), 20);
    expect(AppLayout.pageInsetFor(768), 24);
  });

  test('global interaction targets stay accessibility sized', () {
    expect(AppTouchTarget.minimum, greaterThanOrEqualTo(48));
    expect(AppTouchTarget.primaryButtonHeight, 56);
    expect(AppTouchTarget.secondaryButtonHeight, 52);

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
    expect(
      theme.inputDecorationTheme.constraints?.minHeight,
      greaterThanOrEqualTo(56),
    );
  });

  test('runtime accent preserves fill and derives contrast-safe surface tones', () {
    for (final accent in const [
      '#FFFFFF',
      '#F2C94C',
      '#2563EB',
      '#E83F5B',
      '#11A97D',
      '#111111',
    ]) {
      final colors = OmcAppColors.resolve(accentColor: accent);
      expect(
        _contrastRatio(colors.accent, colors.onAccent),
        greaterThanOrEqualTo(4.5),
        reason: 'Accent $accent must keep readable filled-button text.',
      );
      expect(
        _contrastRatio(colors.accentInk, Colors.white),
        greaterThanOrEqualTo(4.5),
        reason: 'Accent $accent needs readable accent text on a light surface.',
      );
      expect(
        _contrastRatio(colors.accentFocus, Colors.white),
        greaterThanOrEqualTo(3.0),
        reason: 'Accent $accent needs a visible focus indicator.',
      );
    }

    final white = OmcAppColors.resolve(accentColor: '#FFFFFF');
    expect(white.accent, const Color(0xFFFFFFFF));
  });

  test('invalid runtime accent still falls back without changing the contract', () {
    final colors = OmcAppColors.resolve(accentColor: 'not-a-color');
    expect(colors.accent, const Color(0xFF111827));
    expect(_contrastRatio(colors.accentInk, Colors.white), greaterThanOrEqualTo(4.5));
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

  testWidgets('loading app button keeps its label, semantics and width', (
    tester,
  ) async {
    Future<Size> pumpButton({required bool loading}) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Center(
              child: AppButton(
                label: 'Save changes',
                onPressed: () {},
                isLoading: loading,
                isExpanded: false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      return tester.getSize(find.byType(FilledButton));
    }

    final idleSize = await pumpButton(loading: false);
    final loadingSize = await pumpButton(loading: true);

    expect(loadingSize, idleSize);
    expect(find.text('Save changes'), findsOneWidget);
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
                  title: 'Support workspace with a long operational heading',
                  subtitle:
                      'Review customer conversations and operational support requests without hiding important context.',
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

  testWidgets('status badge keeps the complete state at large text', (
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
                width: 180,
                child: OmcStatusBadge(
                  label: 'Payment submitted for verification',
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(
      find.bySemanticsLabel('Status: Payment submitted for verification'),
      findsOneWidget,
    );
    expect(find.text('Payment submitted for verification'), findsOneWidget);
  });

  testWidgets('interactive surface does not erase nested action semantics', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: OmcSurface(
            onTap: () {},
            semanticLabel: 'Open account summary',
            child: TextButton(
              onPressed: () {},
              child: const Text('View invoice'),
            ),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Open account summary'), findsOneWidget);
    expect(find.bySemanticsLabel('View invoice'), findsOneWidget);
  });
}

double _contrastRatio(Color first, Color second) {
  final firstLuminance = first.computeLuminance();
  final secondLuminance = second.computeLuminance();
  final lighter = firstLuminance >= secondLuminance
      ? firstLuminance
      : secondLuminance;
  final darker = firstLuminance >= secondLuminance
      ? secondLuminance
      : firstLuminance;
  return (lighter + 0.05) / (darker + 0.05);
}
