import 'package:pub_semver/pub_semver.dart';

/// SemVer precedence, deliberately excluding build metadata from comparison.
Version mobileSemanticVersion(String text) {
  final value = text.trim();
  final pattern = RegExp(
    r'^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)'
    r'(?:-((?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*)'
    r'(?:\.(?:0|[1-9][0-9]*|[0-9]*[A-Za-z-][0-9A-Za-z-]*))*))?'
    r'(?:\+([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$',
  );
  if (value.length > 128 || !pattern.hasMatch(value)) {
    throw const FormatException('Invalid mobile version.');
  }
  return Version.parse(value.split('+').first);
}

class MobileReleaseControls {
  const MobileReleaseControls({
    this.maintenanceMode = false,
    this.forceUpdate = false,
    this.minimumAppVersion = '',
    this.valid = true,
  });

  static const unavailable = MobileReleaseControls(valid: false);
  final bool maintenanceMode;
  final bool forceUpdate;
  final String minimumAppVersion;
  final bool valid;

  factory MobileReleaseControls.fromJson(Map<String, dynamic> json) {
    for (final key in const [
      'maintenance_mode',
      'minimum_app_version',
      'force_update',
    ]) {
      if (!json.containsKey(key)) {
        throw const FormatException('Required mobile controls are missing.');
      }
    }
    final minimum = json['minimum_app_version'];
    if (minimum is! String) {
      throw const FormatException('Invalid minimum mobile version.');
    }
    final clean = minimum.trim();
    if (clean.isNotEmpty) {
      mobileSemanticVersion(clean);
    }
    final force = _flag(json['force_update']);
    if (force && clean.isEmpty) {
      throw const FormatException(
        'A forced update requires a minimum version.',
      );
    }
    return MobileReleaseControls(
      maintenanceMode: _flag(json['maintenance_mode']),
      forceUpdate: force,
      minimumAppVersion: clean,
    );
  }

  static bool _flag(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is int && (value == 0 || value == 1)) {
      return value == 1;
    }
    if (value == '1' || value == 'true') {
      return true;
    }
    if (value == '0' || value == 'false') {
      return false;
    }
    throw const FormatException('Invalid mobile control flag.');
  }

  bool requiresUpdate(String installed) =>
      minimumAppVersion.isNotEmpty &&
      mobileSemanticVersion(
            installed,
          ).compareTo(mobileSemanticVersion(minimumAppVersion)) <
          0;
}
