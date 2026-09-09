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
    required this.accentInk,
    required this.accentFocus,
  });

  /// Exact backend-configured accent value. Do not replace or normalize this
  /// into a different brand color for filled primary controls.
  final Color accent;
  final Color onAccent;
  final Color accentSoft;
  final Color accentBorder;
  final Color accentPressed;

  /// Derived presentation-only tones used when the configured accent itself
  /// does not have enough contrast on a light surface.
  final Color accentInk;
  final Color accentFocus;

  factory OmcAppColors.resolve({
    String? accentColor,
    String? primaryColorFamily,
  }) {
    // primaryColorFamily is retained only as a temporary source-compatible
    // argument for older call sites. It now carries the resolved accent value.
    final accent =
        _tryParseHexColor(accentColor) ??
        _tryParseHexColor(primaryColorFamily) ??
        const Color(0xFF111827);
    return OmcAppColors(
      accent: accent,
      onAccent: _readableForeground(accent),
      accentSoft: accent.withValues(alpha: 0.08),
      accentBorder: accent.withValues(alpha: 0.22),
      accentPressed: _darken(accent, 0.10),
      accentInk: _contrastSafeSurfaceColor(accent, minimumRatio: 4.5),
      accentFocus: _contrastSafeSurfaceColor(accent, minimumRatio: 3.0),
    );
  }
}

/// Compatibility helper for older widgets. The argument is now the resolved
/// accent hex value, not a named colour family.
Color appPrimaryColorFor(String? accentColor, {String? legacyAccentColor}) {
  return _tryParseHexColor(legacyAccentColor) ??
      _tryParseHexColor(accentColor) ??
      const Color(0xFF111827);
}

Color appPrimarySoftColorFor(String? accentColor, {String? legacyAccentColor}) {
  return appPrimaryColorFor(
    accentColor,
    legacyAccentColor: legacyAccentColor,
  ).withValues(alpha: 0.08);
}

Color appPrimaryForegroundFor(
  String? accentColor, {
  String? legacyAccentColor,
}) {
  final primary = appPrimaryColorFor(
    accentColor,
    legacyAccentColor: legacyAccentColor,
  );
  return _readableForeground(primary);
}

Color? _tryParseHexColor(String? value) {
  final normalized = value?.trim().replaceFirst('#', '') ?? '';
  if (!RegExp(r'^[0-9A-Fa-f]{6}$').hasMatch(normalized)) return null;
  return Color(int.parse('FF$normalized', radix: 16));
}

Color _readableForeground(Color background) {
  const darkForeground = Colors.black;
  const lightForeground = Colors.white;
  final darkContrast = _contrastRatio(background, darkForeground);
  final lightContrast = _contrastRatio(background, lightForeground);
  return darkContrast >= lightContrast ? darkForeground : lightForeground;
}

Color _contrastSafeSurfaceColor(
  Color source, {
  required double minimumRatio,
}) {
  const surface = Colors.white;
  if (_contrastRatio(source, surface) >= minimumRatio) return source;

  final hsl = HSLColor.fromColor(source);
  for (var step = 1; step <= 24; step += 1) {
    final lightness = (hsl.lightness - (step * 0.025)).clamp(0.0, 1.0);
    final candidate = hsl.withLightness(lightness).toColor();
    if (_contrastRatio(candidate, surface) >= minimumRatio) return candidate;
  }

  return Colors.black;
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

Color _darken(Color color, double amount) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
}
