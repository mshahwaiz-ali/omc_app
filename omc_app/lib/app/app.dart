import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/push/push_runtime.dart';
import '../features/app_config/presentation/app_readiness_gate.dart';
import '../features/app_config/data/mobile_app_config.dart';
import '../features/app_config/data/mobile_app_config_repository.dart';
import '../features/app_config/presentation/app_brand_registry.dart';
import '../features/device_lock/presentation/device_lock_gate.dart';
import 'design_tokens.dart';
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
      themeMode: ThemeMode.light,
      routerDelegate: router.routerDelegate,
      routeInformationParser: router.routeInformationParser,
      routeInformationProvider: router.routeInformationProvider,
      backButtonDispatcher: ref.watch(mobileBackDispatcherProvider),
      builder: (context, child) {
        return AppReadinessGate(
          child: PushRuntimeHost(
            child: DeviceLockGate(child: child ?? const SizedBox.shrink()),
          ),
        );
      },
    );
  }
}

ThemeData _withAccentTheme(ThemeData base, OmcAppColors colors) {
  final scheme = base.colorScheme.copyWith(
    primary: colors.accent,
    onPrimary: colors.onAccent,
    primaryContainer: colors.accentSoft,
    onPrimaryContainer: colors.accentInk,
  );

  final controlShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppRadius.control),
  );

  return base.copyWith(
    colorScheme: scheme,
    splashColor: colors.accentSoft,
    highlightColor: colors.accent.withValues(alpha: 0.05),
    focusColor: colors.accentFocus.withValues(alpha: 0.12),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: colors.accent,
      linearTrackColor: colors.accentSoft,
      circularTrackColor: colors.accentSoft,
    ),
    inputDecorationTheme: base.inputDecorationTheme.copyWith(
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.control),
        borderSide: BorderSide(color: colors.accentFocus, width: 2),
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: colors.accentInk,
      selectionColor: colors.accent.withValues(alpha: 0.22),
      selectionHandleColor: colors.accentInk,
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size.square(AppTouchTarget.minimum),
        foregroundColor: colors.accentInk,
        padding: const EdgeInsets.all(AppSpacing.sm),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(AppTouchTarget.primaryButtonHeight),
        backgroundColor: colors.accent,
        foregroundColor: colors.onAccent,
        disabledBackgroundColor: const Color(0xFFE2E8F0),
        disabledForegroundColor: const Color(0xFF64748B),
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        shape: controlShape,
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.25,
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size.fromHeight(AppTouchTarget.primaryButtonHeight),
        backgroundColor: colors.accent,
        foregroundColor: colors.onAccent,
        disabledBackgroundColor: const Color(0xFFE2E8F0),
        disabledForegroundColor: const Color(0xFF64748B),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.sm,
        ),
        shape: controlShape,
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.25,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(AppTouchTarget.secondaryButtonHeight),
        foregroundColor: colors.accentInk,
        side: BorderSide(color: colors.accentFocus),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        shape: controlShape,
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.25,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(AppTouchTarget.minimum, AppTouchTarget.minimum),
        foregroundColor: colors.accentInk,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.25,
        ),
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
      side: const BorderSide(color: AppTheme.controlOutline, width: 1.4),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return colors.accentFocus;
        return AppTheme.controlOutline;
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
      checkmarkColor: colors.accentInk,
      secondaryLabelStyle: base.textTheme.labelMedium?.copyWith(
        color: colors.accentInk,
        fontWeight: FontWeight.w600,
      ),
    ),
    datePickerTheme: base.datePickerTheme.copyWith(
      headerBackgroundColor: colors.accentSoft,
      headerForegroundColor: AppTheme.textPrimary,
      dayForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return AppTheme.textSecondary.withValues(alpha: 0.45);
        }
        if (states.contains(WidgetState.selected)) return colors.onAccent;
        return AppTheme.textPrimary;
      }),
      dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return colors.accent;
        return Colors.transparent;
      }),
      todayForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return colors.onAccent;
        return colors.accentInk;
      }),
      todayBorder: BorderSide(color: colors.accentFocus, width: 2),
      yearForegroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return colors.onAccent;
        return AppTheme.textPrimary;
      }),
      yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return colors.accent;
        return Colors.transparent;
      }),
    ),
    timePickerTheme: base.timePickerTheme.copyWith(
      dialHandColor: colors.accent,
      entryModeIconColor: colors.accentInk,
      hourMinuteColor: colors.accentSoft,
      dayPeriodColor: colors.accentSoft,
    ),
  );
}
