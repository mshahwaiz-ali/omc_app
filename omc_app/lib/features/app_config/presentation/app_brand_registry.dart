import 'package:flutter/material.dart';

const String defaultAppPrimaryColorFamily = 'navy';
const String defaultAppAccentColor = '#111827';

@immutable
class OmcAppColors {
  const OmcAppColors({
    required this.accent,
    required this.onAccent,
    required this.accentSoft,
    required this.accentBorder,
    required this.accentPressed,
  });

  final Color accent;
  final Color onAccent;
  final Color accentSoft;
  final Color accentBorder;
  final Color accentPressed;

  factory OmcAppColors.resolve({
    String? accentColor,
    String? primaryColorFamily,
  }) {
    final accent = appPrimaryColorFor(
      primaryColorFamily,
      accentColor: accentColor,
    );
    final brightness = ThemeData.estimateBrightnessForColor(accent);
    return OmcAppColors(
      accent: accent,
      onAccent: brightness == Brightness.dark
          ? Colors.white
          : const Color(0xFF111827),
      accentSoft: accent.withValues(alpha: 0.08),
      accentBorder: accent.withValues(alpha: 0.22),
      accentPressed: _darken(accent, 0.10),
    );
  }
}

Color appPrimaryColorFor(String? family, {String? accentColor}) {
  final parsed = _tryParseHexColor(accentColor);
  if (parsed != null) return parsed;
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

Color appPrimarySoftColorFor(String? family, {String? accentColor}) {
  return appPrimaryColorFor(
    family,
    accentColor: accentColor,
  ).withValues(alpha: 0.08);
}

Color appPrimaryForegroundFor(String? family, {String? accentColor}) {
  final primary = appPrimaryColorFor(family, accentColor: accentColor);
  final brightness = ThemeData.estimateBrightnessForColor(primary);
  return brightness == Brightness.dark ? Colors.white : const Color(0xFF111827);
}

Color? _tryParseHexColor(String? value) {
  final normalized = value?.trim().replaceFirst('#', '') ?? '';
  if (!RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(normalized)) return null;
  return Color(int.parse('FF$normalized', radix: 16));
}

Color _darken(Color color, double amount) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
}

String _normalizedFamily(String? family) {
  final normalized = family?.trim().toLowerCase() ?? '';
  return normalized.isEmpty ? defaultAppPrimaryColorFamily : normalized;
}
