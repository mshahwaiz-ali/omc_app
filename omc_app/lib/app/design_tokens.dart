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

  static const double small = 12;
  static const double medium = 16;
  static const double control = 18;
  static const double large = 22;
  static const double card = 24;
  static const double sheet = 24;
  static const double pill = 999;
}

class AppTouchTarget {
  const AppTouchTarget._();

  /// Material/Android accessibility guidance uses 48 logical pixels as the
  /// minimum interactive target. Visual glyphs may remain smaller inside it.
  static const double minimum = 48;
  static const double primaryButtonHeight = 52;
  static const double prominentButtonHeight = 54;

  static const BoxConstraints constraints = BoxConstraints(
    minWidth: minimum,
    minHeight: minimum,
  );
}

class AppMotion {
  const AppMotion._();

  static const Duration quick = Duration(milliseconds: 180);
  static const Duration standard = Duration(milliseconds: 240);
}
