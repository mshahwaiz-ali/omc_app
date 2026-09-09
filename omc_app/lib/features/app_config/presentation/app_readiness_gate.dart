import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/design_tokens.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../application/app_gate_controller.dart';
import '../application/app_gate_policy.dart';
import '../data/mobile_app_config.dart';
import '../data/mobile_app_config_repository.dart';

final mobileBackDispatcherProvider = Provider<RootBackButtonDispatcher>(
  (ref) => _GatedBackDispatcher(() {
    if (ref.read(appGateDecisionProvider).blocked) {
      return true;
    }
    final config = ref.read(mobileAppConfigProvider).value;
    final uri = ref.read(appRouterProvider).routeInformationProvider.value.uri;
    return !mobileFeatureRouteEnabled(
      uri.toString(),
      config?.features ?? const MobileFeatureConfig(),
      guest: ref.read(authControllerProvider).status == AuthStatus.guest,
    );
  }),
);

class _GatedBackDispatcher extends RootBackButtonDispatcher {
  _GatedBackDispatcher(this.blocked);
  final bool Function() blocked;
  @override
  Future<bool> didPopRoute() =>
      blocked() ? Future<bool>.value(true) : super.didPopRoute();
}

class AppReadinessGate extends ConsumerStatefulWidget {
  const AppReadinessGate({required this.child, super.key});
  final Widget child;
  @override
  ConsumerState<AppReadinessGate> createState() => _AppReadinessGateState();
}

class _AppReadinessGateState extends ConsumerState<AppReadinessGate>
    with WidgetsBindingObserver {
  String? _actionError;
  bool _actionBusy = false;
  Timer? _retryTimer;
  int _retries = 0;
  AppGateKind? _lastKind;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _retryTimer?.cancel();
      _retryTimer = null;
      _retries = 0;
      ref.invalidate(mobileAppConfigProvider);
    }
  }

  void _retry() {
    if (ref.read(mobileAppConfigProvider).isLoading) {
      return;
    }
    _retryTimer?.cancel();
    _retryTimer = null;
    _retries = 0;
    setState(() => _actionError = null);
    ref.invalidate(installedMobileVersionProvider);
    ref.invalidate(mobileAppConfigProvider);
  }

  void _boundRecovery(AppGateKind kind) {
    if (kind != AppGateKind.unavailable) {
      _retryTimer?.cancel();
      _retryTimer = null;
      if (kind == AppGateKind.open) {
        _retries = 0;
      }
      return;
    }
    const delays = [
      Duration(seconds: 5),
      Duration(seconds: 15),
      Duration(seconds: 30),
    ];
    if (_retryTimer != null || _retries >= delays.length) {
      return;
    }
    _retryTimer = Timer(delays[_retries++], () {
      _retryTimer = null;
      if (mounted &&
          ref.read(appGateDecisionProvider).kind == AppGateKind.unavailable) {
        ref.invalidate(mobileAppConfigProvider);
      }
    });
  }

  Future<void> _action(Future<void> Function() action) async {
    if (_actionBusy) {
      return;
    }
    setState(() {
      _actionBusy = true;
      _actionError = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _actionError = 'The action could not be completed. Please retry.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _actionBusy = false);
      }
    }
  }

  Future<void> _update() async {
    const package = 'com.wajid.omc_house';
    var opened = false;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        opened = await launchUrl(
          Uri.parse('market://details?id=$package'),
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        // An absent Play application falls back to the public HTTPS listing.
      }
    }
    if (!opened) {
      try {
        opened = await launchUrl(
          Uri.https('play.google.com', '/store/apps/details', {'id': package}),
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {
        opened = false;
      }
    }
    if (!opened && mounted) {
      setState(
        () => _actionError =
            'The store could not be opened. Open Google Play and search for OMC House.',
      );
    }
  }

  Future<void> _dismissUpdate() async {
    final config = ref.read(mobileAppConfigProvider).value;
    final installed = ref.read(installedMobileVersionProvider).value;
    if (config == null ||
        installed == null ||
        config.controls.forceUpdate ||
        ref.read(appGateDecisionProvider).kind !=
            AppGateKind.recommendedUpdate) {
      return;
    }
    final pair = updateDismissalPair(
      installed,
      config.controls.minimumAppVersion,
    );
    if (!await saveOptionalUpdateDismissal(pair)) {
      throw StateError('Update preference was not saved.');
    }
    if (mounted) {
      ref.invalidate(optionalUpdateSuppressionProvider(pair));
    }
  }

  @override
  Widget build(BuildContext context) {
    final global = ref.watch(appGateDecisionProvider);
    final config = ref.watch(mobileAppConfigProvider).value;
    final auth = ref.watch(authControllerProvider);
    final router = ref.watch(appRouterProvider);
    _boundRecovery(global.kind);
    if (_lastKind != global.kind) {
      _lastKind = global.kind;
      _actionError = null;
    }
    return ListenableBuilder(
      listenable: router.routeInformationProvider,
      builder: (context, _) {
        final allowed = mobileFeatureRouteEnabled(
          router.routeInformationProvider.value.uri.toString(),
          config?.features ?? const MobileFeatureConfig(),
          guest: auth.status == AuthStatus.guest,
        );
        final decision = global.blocked || allowed
            ? global
            : const AppGateDecision(AppGateKind.feature);
        return MobileReadinessOverlay(
          blocked: decision.blocked,
          panel: AppGatePanel(
            decision: decision,
            busy: _actionBusy,
            error: _actionError,
            onRetry: _retry,
            onUpdate: () => _action(_update),
            onDismissUpdate: () => _action(_dismissUpdate),
            onLogout:
                auth.status == AuthStatus.authenticated ||
                    auth.status == AuthStatus.guest
                ? () => _action(
                    () => ref.read(authControllerProvider.notifier).logout(),
                  )
                : null,
            onHome:
                decision.kind == AppGateKind.feature &&
                    auth.status != AuthStatus.guest
                ? () => router.go('/home')
                : null,
          ),
          child: widget.child,
        );
      },
    );
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

/// Retain Router/Navigator/form state while blocking interaction, keyboard focus
/// and accessibility access. This covers dialogs and restored/direct routes too.
class MobileReadinessOverlay extends StatelessWidget {
  const MobileReadinessOverlay({
    required this.blocked,
    required this.child,
    required this.panel,
    super.key,
  });
  final bool blocked;
  final Widget child;
  final Widget panel;
  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      ExcludeFocus(
        excluding: blocked,
        child: ExcludeSemantics(
          excluding: blocked,
          child: IgnorePointer(
            ignoring: blocked,
            child: TickerMode(enabled: !blocked, child: child),
          ),
        ),
      ),
      if (blocked) Positioned.fill(child: panel),
    ],
  );
}

class AppGatePanel extends StatelessWidget {
  const AppGatePanel({
    required this.decision,
    required this.onRetry,
    required this.onUpdate,
    required this.onDismissUpdate,
    this.onLogout,
    this.onHome,
    this.busy = false,
    this.error,
    super.key,
  });
  final AppGateDecision decision;
  final VoidCallback onRetry;
  final VoidCallback onUpdate;
  final VoidCallback onDismissUpdate;
  final VoidCallback? onLogout;
  final VoidCallback? onHome;
  final bool busy;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = switch (decision.kind) {
      AppGateKind.loading => 'Checking OMC availability',
      AppGateKind.maintenance => 'OMC is under maintenance',
      AppGateKind.forcedUpdate => 'Update required',
      AppGateKind.recommendedUpdate => 'An update is available',
      AppGateKind.feature => 'This feature is unavailable',
      _ => 'OMC configuration is unavailable',
    };
    final message = switch (decision.kind) {
      AppGateKind.loading =>
        'Please keep the app connected while its availability is checked.',
      AppGateKind.maintenance =>
        'Normal mobile access is paused for all accounts. Retry later. Administrators can recover through ERP Desk.',
      AppGateKind.forcedUpdate =>
        'Install OMC House ${decision.minimumVersion} or newer to continue.',
      AppGateKind.recommendedUpdate =>
        'OMC House ${decision.minimumVersion} or newer is recommended. You may continue for 24 hours.',
      AppGateKind.feature =>
        'This feature is disabled by OMC. Your current screen has been retained.',
      _ =>
        'Current app controls could not be verified. Check your connection and retry. Saved forms have been retained.',
    };
    final loading = decision.kind == AppGateKind.loading;

    return Material(
      key: const ValueKey('omc-app-readiness-gate'),
      color: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.xxl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppLayout.formMaxWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (loading)
                    Semantics(
                      label: title,
                      liveRegion: true,
                      child: const SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                    )
                  else
                    ExcludeSemantics(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(AppRadius.card),
                        ),
                        child: Icon(
                          decision.offersUpdate
                              ? Icons.system_update_rounded
                              : Icons.shield_outlined,
                          size: 40,
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.xl),
                  Semantics(
                    header: true,
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Semantics(
                      liveRegion: true,
                      label: error!,
                      excludeSemantics: true,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppTheme.dangerSoft,
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          border: Border.all(
                            color: AppTheme.danger.withValues(alpha: 0.20),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: AppTheme.danger,
                              size: 24,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                error!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  if (decision.offersUpdate)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: busy ? null : onUpdate,
                        icon: const Icon(Icons.open_in_new_rounded),
                        label: const Text('Open Google Play'),
                      ),
                    ),
                  if (decision.kind == AppGateKind.recommendedUpdate) ...[
                    const SizedBox(height: AppSpacing.xs),
                    TextButton(
                      onPressed: busy ? null : onDismissUpdate,
                      child: const Text('Continue for now'),
                    ),
                  ],
                  if (!loading) ...[
                    const SizedBox(height: AppSpacing.xs),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : onRetry,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                      ),
                    ),
                  ],
                  if (onHome != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    TextButton(
                      onPressed: busy ? null : onHome,
                      child: const Text('Return home'),
                    ),
                  ],
                  if (onLogout != null)
                    TextButton(
                      onPressed: busy ? null : onLogout,
                      child: const Text('Sign out'),
                    ),
                  if (!kIsWeb &&
                      defaultTargetPlatform == TargetPlatform.android)
                    TextButton(
                      onPressed: busy ? null : () => SystemNavigator.pop(),
                      child: const Text('Exit app'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
