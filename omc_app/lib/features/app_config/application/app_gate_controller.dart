import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/api_config.dart';
import '../data/mobile_app_config_repository.dart';
import 'app_gate_policy.dart';

final installedMobileVersionProvider = FutureProvider<String>(
  (ref) async => (await PackageInfo.fromPlatform()).version,
);

String _dismissalKey(String pair) =>
    'omc_update_dismissed_v1_${base64Url.encode(utf8.encode('${Uri.parse(ApiConfig.baseUrl).origin}|$pair'))}';

final optionalUpdateSuppressionProvider = FutureProvider.autoDispose
    .family<bool, String>((ref, pair) async {
      Timer? expiry;
      var alive = true;
      ref.onDispose(() {
        alive = false;
        expiry?.cancel();
      });
      try {
        final prefs = await SharedPreferences.getInstance();
        final timestamp = prefs.getInt(_dismissalKey(pair));
        final now = DateTime.now();
        final suppressed = optionalUpdateSuppressedAt(timestamp, now);
        if (alive && suppressed && timestamp != null) {
          final until = DateTime.fromMillisecondsSinceEpoch(
            timestamp,
          ).add(const Duration(hours: 24));
          expiry = Timer(until.difference(now), ref.invalidateSelf);
        }
        return suppressed;
      } catch (_) {
        return false;
      }
    });

Future<bool> saveOptionalUpdateDismissal(String pair) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.setInt(
    _dismissalKey(pair),
    DateTime.now().millisecondsSinceEpoch,
  );
}

final appGateDecisionProvider = Provider<AppGateDecision>((ref) {
  final state = ref.watch(mobileAppConfigProvider);
  final config = state.value;
  final now = DateTime.now();
  final keepCurrentConfigDuringRefresh =
      state.isRefreshing && config?.isCurrentAt(now) == true;
  final needsVersion = config?.controls.minimumAppVersion.isNotEmpty == true;
  final version = needsVersion
      ? ref.watch(installedMobileVersionProvider)
      : null;
  var suppressed = false;
  var suppressionLoading = false;
  final installed = version?.value;
  if (config != null &&
      !config.controls.forceUpdate &&
      needsVersion &&
      installed != null) {
    try {
      if (config.controls.requiresUpdate(installed)) {
        final pair = updateDismissalPair(
          installed,
          config.controls.minimumAppVersion,
        );
        final suppression = ref.watch(optionalUpdateSuppressionProvider(pair));
        suppressed = suppression.value == true;
        suppressionLoading = suppression.isLoading;
      }
    } on FormatException {
      return const AppGateDecision(AppGateKind.unavailable);
    }
  }
  return evaluateMobileGate(
    config: config,
    now: now,
    loading:
        (state.isLoading && !keepCurrentConfigDuringRefresh) ||
        suppressionLoading,
    failed: state.hasError,
    installedVersion: version?.value,
    installedVersionLoading: version?.isLoading == true,
    optionalUpdateSuppressed: suppressed,
  );
});
