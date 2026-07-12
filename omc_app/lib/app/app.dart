import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/app_config/data/mobile_app_config.dart';
import '../features/app_config/data/mobile_app_config_repository.dart';
import '../features/app_config/presentation/app_brand_registry.dart';
import 'router.dart';
import 'theme.dart';

class OmcApp extends ConsumerWidget {
  const OmcApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final appConfig = ref
        .watch(mobileAppConfigProvider)
        .maybeWhen(
          data: (config) => config,
          orElse: () => MobileAppConfig.fallback,
        );
    final appColors = OmcAppColors.resolve(
      accentColor: appConfig.branding.accentColor,
    );

    return MaterialApp.router(
      title: appConfig.branding.companyName,
      debugShowCheckedModeBanner: false,
      theme: _withAccentTheme(AppTheme.lightTheme, appColors),
      darkTheme: _withAccentTheme(AppTheme.darkTheme, appColors),
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}

ThemeData _withAccentTheme(ThemeData base, OmcAppColors colors) {
  final scheme = base.colorScheme.copyWith(
    primary: colors.accent,
    onPrimary: colors.onAccent,
    primaryContainer: colors.accentSoft,
    onPrimaryContainer: colors.accent,
  );

  final rounded18 = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(18),
  );

  return base.copyWith(
    colorScheme: scheme,
    splashColor: colors.accentSoft,
    highlightColor: colors.accent.withValues(alpha: 0.05),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colors.accent,
      linearTrackColor: colors.accentSoft,
      circularTrackColor: colors.accentSoft,
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: colors.accent, width: 1.5),
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: colors.accent,
      selectionColor: colors.accent.withValues(alpha: 0.22),
      selectionHandleColor: colors.accent,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: colors.accent,
        foregroundColor: colors.onAccent,
        disabledBackgroundColor: const Color(0xFFE2E8F0),
        disabledForegroundColor: const Color(0xFF94A3B8),
        elevation: 0,
        shape: rounded18,
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        backgroundColor: colors.accent,
        foregroundColor: colors.onAccent,
        disabledBackgroundColor: const Color(0xFFE2E8F0),
        disabledForegroundColor: const Color(0xFF94A3B8),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shape: rounded18,
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(50),
        foregroundColor: colors.accent,
        side: BorderSide(color: colors.accentBorder),
        shape: rounded18,
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: colors.accent,
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: colors.accent,
      foregroundColor: colors.onAccent,
      elevation: 4,
      focusElevation: 5,
      hoverElevation: 5,
      highlightElevation: 6,
      shape: const CircleBorder(),
    ),
    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return colors.accent;
        return Colors.transparent;
      }),
      checkColor: WidgetStatePropertyAll(colors.onAccent),
      side: const BorderSide(color: Color(0xFFCBD3DF), width: 1.5),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return colors.accent;
        return const Color(0xFF94A3B8);
      }),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return colors.onAccent;
        return const Color(0xFFF8FAFC);
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return colors.accent;
        return const Color(0xFFCBD5E1);
      }),
    ),
    chipTheme: base.chipTheme.copyWith(
      selectedColor: colors.accentSoft,
      checkmarkColor: colors.accent,
      secondaryLabelStyle: TextStyle(
        color: colors.accent,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}
