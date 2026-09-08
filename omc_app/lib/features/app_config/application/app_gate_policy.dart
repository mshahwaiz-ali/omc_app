import '../data/mobile_app_config.dart';
import '../data/mobile_release_controls.dart';

enum AppGateKind {
  loading,
  unavailable,
  maintenance,
  forcedUpdate,
  recommendedUpdate,
  feature,
  open,
}

class AppGateDecision {
  const AppGateDecision(
    this.kind, {
    this.minimumVersion = '',
    this.message = '',
  });
  final AppGateKind kind;
  final String minimumVersion;
  final String message;
  bool get blocked => kind != AppGateKind.open;
  bool get offersUpdate =>
      kind == AppGateKind.forcedUpdate || kind == AppGateKind.recommendedUpdate;
}

AppGateDecision evaluateMobileGate({
  required MobileAppConfig? config,
  required DateTime now,
  bool loading = false,
  bool failed = false,
  String? installedVersion,
  bool installedVersionLoading = false,
  bool optionalUpdateSuppressed = false,
}) {
  // Keep a known maintenance block visible during retry or network failure.
  if (config?.controls.maintenanceMode == true) {
    return const AppGateDecision(AppGateKind.maintenance);
  }
  if (loading) {
    return const AppGateDecision(AppGateKind.loading);
  }
  if (failed || config == null || !config.isCurrentAt(now)) {
    return const AppGateDecision(AppGateKind.unavailable);
  }
  final controls = config.controls;
  if (controls.minimumAppVersion.isEmpty) {
    return const AppGateDecision(AppGateKind.open);
  }
  if (installedVersionLoading) {
    return const AppGateDecision(AppGateKind.loading);
  }
  if (installedVersion == null) {
    return const AppGateDecision(AppGateKind.unavailable);
  }
  try {
    if (!controls.requiresUpdate(installedVersion)) {
      return const AppGateDecision(AppGateKind.open);
    }
  } on FormatException {
    return const AppGateDecision(AppGateKind.unavailable);
  }
  if (controls.forceUpdate) {
    return AppGateDecision(
      AppGateKind.forcedUpdate,
      minimumVersion: controls.minimumAppVersion,
    );
  }
  return optionalUpdateSuppressed
      ? const AppGateDecision(AppGateKind.open)
      : AppGateDecision(
          AppGateKind.recommendedUpdate,
          minimumVersion: controls.minimumAppVersion,
        );
}

bool optionalUpdateSuppressedAt(int? dismissedAt, DateTime now) {
  if (dismissedAt == null) {
    return false;
  }
  final elapsed = now.millisecondsSinceEpoch - dismissedAt;
  return elapsed >= 0 && elapsed < const Duration(hours: 24).inMilliseconds;
}

String updateDismissalPair(String installed, String minimum) =>
    '${mobileSemanticVersion(installed)}|${mobileSemanticVersion(minimum)}';

/// Availability is additional to (and never replaces) backend/route authority.
bool mobileFeatureRouteEnabled(
  String location,
  MobileFeatureConfig features, {
  bool guest = false,
}) {
  final path = Uri.tryParse(location)?.path ?? '';
  bool at(String root) => path == root || path.startsWith('$root/');
  if (path.isEmpty) {
    return false;
  }
  if (guest &&
      !features.guestModeEnabled &&
      path != '/' &&
      path != '/login' &&
      path != '/onboarding' &&
      path != '/signup' &&
      path != '/forgot-password' &&
      path != '/activate-existing-account' &&
      path != '/activate-account' &&
      path != '/verify-email' &&
      path != '/reset-password') {
    return false;
  }
  if (at('/expense-tracker') || at('/expense-budget')) {
    return features.expenseTrackerEnabled;
  }
  if (at('/tax-calculator')) {
    return features.taxCalculatorEnabled;
  }
  if (at('/knowledge')) {
    return features.knowledgeEnabled;
  }
  if (at('/payments') || at('/internal-workspace/payments')) {
    return features.paymentsEnabled &&
        (!at('/internal-workspace') || features.internalWorkspaceEnabled);
  }
  if (at('/support') || at('/support-tickets')) {
    return features.supportEnabled;
  }
  if (at('/internal-workspace') ||
      at('/tasks') ||
      at('/customers') ||
      at('/leads') ||
      at('/admin-control')) {
    return features.internalWorkspaceEnabled;
  }
  if (at('/subscriptions')) {
    return features.subscriptionsEnabled;
  }
  return true;
}
