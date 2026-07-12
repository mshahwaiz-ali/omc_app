import 'package:flutter/material.dart';

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

  factory OmcAppColors.resolve({String? accentColor}) {
    final accent = _tryParseHexColor(accentColor) ?? const Color(0xFF111827);
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

/// Legacy compatibility helper for older screens. The family argument is
/// intentionally ignored; [accentColor] is now the only branding source.
Color appPrimaryColorFor(String? family, {String? accentColor}) {
  return OmcAppColors.resolve(accentColor: accentColor).accent;
}

Color appPrimarySoftColorFor(String? family, {String? accentColor}) {
  return OmcAppColors.resolve(accentColor: accentColor).accentSoft;
}

Color appPrimaryForegroundFor(String? family, {String? accentColor}) {
  return OmcAppColors.resolve(accentColor: accentColor).onAccent;
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
