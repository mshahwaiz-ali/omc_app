import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  // Brand / interaction colors.
  static const Color primary = Color(0xFF111827);
  static const Color primaryDark = Color(0xFF0B1220);
  static const Color primarySoft = Color(0xFFF1F5F9);

  // Semantic colors.
  static const Color danger = Color(0xFFE11D48);
  static const Color dangerSoft = Color(0xFFFFE8EE);
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFD97706);
  static const Color info = Color(0xFF2563EB);

  // Compatibility alias for older widgets.
  //
  // New interactive widgets must use `primary`. Existing usages can be
  // migrated gradually after confirming whether each red is semantic.
  static const Color primaryRed = danger;

  static const Color darkRed = Color(0xFF1E293B);
  static const Color background = Color(0xFFF7F8FB);
  static const Color card = Colors.white;
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = textSecondary;
  static const Color border = Color(0xFFE5EAF2);
  static const Color cardSoft = Color(0xFFF8FAFC);

  static ThemeData get lightTheme {
    final colorScheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: primary,
          onPrimary: Colors.white,
          primaryContainer: primarySoft,
          onPrimaryContainer: primaryDark,
          secondary: const Color(0xFF475569),
          onSecondary: Colors.white,
          error: danger,
          onError: Colors.white,
          errorContainer: dangerSoft,
          surface: card,
          onSurface: textPrimary,
          outline: border,
          outlineVariant: const Color(0xFFEDF0F5),
          surfaceTint: Colors.transparent,
        );

    final rounded18 = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
    );

    final rounded22 = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      splashColor: primary.withValues(alpha: 0.08),
      highlightColor: primary.withValues(alpha: 0.05),

      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: background,
        surfaceTintColor: Colors.transparent,
        foregroundColor: textPrimary,
      ),

      cardTheme: CardThemeData(
        color: card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: rounded22,
      ),

      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.white,
        modalBackgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
      ),

      datePickerTheme: DatePickerThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        headerBackgroundColor: primarySoft,
        headerForegroundColor: textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return textSecondary.withValues(alpha: 0.45);
          }
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return textPrimary;
        }),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary;
          }
          return Colors.transparent;
        }),
        todayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return primary;
        }),
        todayBorder: const BorderSide(color: primary, width: 1.4),
        yearForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return textPrimary;
        }),
        yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary;
          }
          return Colors.transparent;
        }),
      ),

      timePickerTheme: TimePickerThemeData(
        backgroundColor: Colors.white,
        dialBackgroundColor: cardSoft,
        dialHandColor: primary,
        entryModeIconColor: primary,
        hourMinuteColor: primarySoft,
        hourMinuteTextColor: textPrimary,
        dayPeriodColor: primarySoft,
        dayPeriodTextColor: textPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: primarySoft,
        circularTrackColor: primarySoft,
      ),

      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary;
          }
          return Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(Colors.white),
        side: const BorderSide(color: Color(0xFFCBD3DF), width: 1.5),
      ),

      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary;
          }
          return const Color(0xFF94A3B8);
        }),
      ),

      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return const Color(0xFFF8FAFC);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return primary;
          }
          return const Color(0xFFCBD5E1);
        }),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: primarySoft,
        disabledColor: const Color(0xFFF1F5F9),
        checkmarkColor: primary,
        side: const BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        labelStyle: const TextStyle(
          color: textSecondary,
          fontWeight: FontWeight.w700,
        ),
        secondaryLabelStyle: const TextStyle(
          color: primaryDark,
          fontWeight: FontWeight.w800,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 15,
        ),
        hintStyle: const TextStyle(
          color: Color(0xFF94A3B8),
          fontWeight: FontWeight.w500,
        ),
        labelStyle: const TextStyle(
          color: textSecondary,
          fontWeight: FontWeight.w600,
        ),
        prefixIconColor: textSecondary,
        suffixIconColor: textSecondary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: danger, width: 1.5),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          backgroundColor: primary,
          foregroundColor: Colors.white,
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
          backgroundColor: primary,
          foregroundColor: Colors.white,
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
          foregroundColor: primary,
          side: const BorderSide(color: border),
          shape: rounded18,
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        ),
      ),

      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 4,
        focusElevation: 5,
        hoverElevation: 5,
        highlightElevation: 6,
        shape: CircleBorder(),
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimary,
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  static ThemeData get darkTheme {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: primary,
          brightness: Brightness.dark,
        ).copyWith(
          primary: const Color(0xFFCBD5E1),
          error: const Color(0xFFFF8AA5),
          surfaceTint: Colors.transparent,
        );

    return lightTheme.copyWith(
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFF111827),
      canvasColor: const Color(0xFF111827),
    );
  }
}
