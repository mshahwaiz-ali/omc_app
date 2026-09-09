import 'package:flutter/material.dart';

class AppSpacing {
  const AppSpacing._();

  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
}

class AppRadius {
  const AppRadius._();

  /// Design System V2 radius family.
  static const double control = 12;
  static const double card = 16;
  static const double dialog = 20;
  static const double sheet = 24;
  static const double pill = 999;

  /// Source-compatible aliases while feature-local styling is migrated.
  static const double small = control;
  static const double medium = card;
  static const double large = card;
}

class AppTouchTarget {
  const AppTouchTarget._();

  /// Material/Android accessibility guidance uses 48 logical pixels as the
  /// minimum interactive target. Visual glyphs may remain smaller inside it.
  static const double minimum = 48;
  static const double secondaryButtonHeight = 52;
  static const double primaryButtonHeight = 56;
  static const double prominentButtonHeight = primaryButtonHeight;

  static const BoxConstraints constraints = BoxConstraints(
    minWidth: minimum,
    minHeight: minimum,
  );
}

class AppLayout {
  const AppLayout._();

  static const double generalMaxWidth = 840;
  static const double formMaxWidth = 560;
  static const double readingMaxWidth = 680;

  static double pageInsetFor(double width) {
    if (width < 360) return AppSpacing.md;
    if (width >= 600) return AppSpacing.xl;
    return AppSpacing.lg;
  }
}

class AppMotion {
  const AppMotion._();

  static const Duration quick = Duration(milliseconds: 180);
  static const Duration standard = Duration(milliseconds: 240);
  static const Duration loadingPulse = Duration(milliseconds: 900);

  static bool reducedMotion(BuildContext context) {
    return MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  static Duration durationFor(BuildContext context, Duration duration) {
    return reducedMotion(context) ? Duration.zero : duration;
  }
}
