import 'package:flutter/material.dart';

const String defaultAppPrimaryColorFamily = 'navy';

Color appPrimaryColorFor(String? family) {
  return switch (_normalizedFamily(family)) {
    'blue' => const Color(0xFF2563EB),
    'teal' => const Color(0xFF0F766E),
    'indigo' => const Color(0xFF4F46E5),
    'slate' => const Color(0xFF475569),
    'burgundy' => const Color(0xFF881337),
    'omc_red' => const Color(0xFFC81D32),
    _ => const Color(0xFF111827),
  };
}

Color appPrimarySoftColorFor(String? family) {
  return appPrimaryColorFor(family).withValues(alpha: 0.08);
}

Color appPrimaryForegroundFor(String? family) {
  final primary = appPrimaryColorFor(family);
  final brightness = ThemeData.estimateBrightnessForColor(primary);

  return brightness == Brightness.dark ? Colors.white : const Color(0xFF111827);
}

String _normalizedFamily(String? family) {
  final normalized = family?.trim().toLowerCase() ?? '';
  return normalized.isEmpty ? defaultAppPrimaryColorFamily : normalized;
}
