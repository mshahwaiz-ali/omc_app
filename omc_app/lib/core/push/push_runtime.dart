import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/design_tokens.dart';
import '../../app/providers/core_providers.dart';
import '../../app/providers/effective_capabilities_provider.dart';
import '../../app/router.dart';
import '../../app/theme.dart';
import '../../features/app_config/application/app_gate_controller.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/application/auth_state.dart';
import '../../features/device_lock/data/device_lock_service.dart';
import '../config/api_config.dart';
import '../network/api_error.dart';
import 'push_destination.dart';
import 'push_registration.dart';

final pushAuthBindingProvider = Provider<void>((ref) {
  final coordinator = ref.watch(pushRegistrationProvider);
  ref.listen<AuthState>(authControllerProvider, (_, next) {
    unawaited(coordinator.syncForAuth(next));
  }, fireImmediately: true);
});

/// Taps wait for the same verified controls and update gate as visible routes.
final pushNavigationAllowedProvider = Provider<bool>((ref) {
  return !ref.watch(appGateDecisionProvider).blocked;
});

class PushRuntimeHost extends ConsumerStatefulWidget {
  const PushRuntimeHost({required this.child, super.key});
  final Widget child;
  @override
  ConsumerState<PushRuntimeHost> createState() => _PushRuntimeHostState();
}

class _PushRuntimeHostState extends ConsumerState<PushRuntimeHost>
    with WidgetsBindingObserver {
  late final PushRegistrationCoordinator _coordinator;
  StreamSubscription<PushOpenIntent>? _opens;
  CancelToken? _lookup;
  bool _busy = false;
  bool _scheduled = false;
  PushOpenIntent? _failedIntent;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _coordinator = ref.read(pushRegistrationProvider);
    _coordinator.status.addListener(_schedule);
    _opens = _coordinator.boundSource?.openedNotifications.listen(
      (_) => _schedule(),
    );
    _schedule();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(
      _coordinator.syncForAuth(ref.read(authControllerProvider), refresh: true),
    );
    _schedule();
  }

  void _schedule() {
    if (!mounted || _scheduled) return;
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) unawaited(_openPending());
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  bool _ready() {
    if (!mounted || !ref.read(pushNavigationAllowedProvider)) return false;
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    if (lifecycle != null && lifecycle != AppLifecycleState.resumed) {
      return false;
    }
    final auth = ref.read(authControllerProvider);
    if (auth.status != AuthStatus.authenticated ||
        auth.userId == null ||
        _coordinator.owner != auth.userId) {
      return false;
    }
    final enrollment = ref.read(biometricLoginEnabledForProvider(auth.userId!));
    if (enrollment.isLoading || enrollment.hasError) return false;
    if (enrollment.value == true &&
        !ref.read(deviceLockSessionUnlockedProvider)) {
      return false;
    }
    final location = ref
        .read(appRouterProvider)
        .routeInformationProvider
        .value
        .uri
        .path;
    return location != '/' && location != '/login' && location != '/onboarding';
  }

  Future<void> _openPending() async {
    final source = _coordinator.boundSource;
    final intent = source?.pendingOpen;
    if (_busy || intent == null || intent == _failedIntent || !_ready()) return;
    final owner = _coordinator.owner;
    if (intent.bindingId != _coordinator.bindingId) return;
    _busy = true;
    final cancellation = CancelToken();
    _lookup = cancellation;
    try {
      final response = await ref
          .read(frappeClientProvider)
          .getMethod(
            ApiConfig.notificationDetailMethod,
            queryParameters: intent.toData(),
            cancelToken: cancellation,
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              cancellation.cancel('Notification lookup deadline');
              throw TimeoutException('Notification lookup timed out.');
            },
          );
      if (!mounted ||
          !_ready() ||
          _coordinator.owner != owner ||
          _coordinator.bindingId != intent.bindingId ||
          source?.pendingOpen != intent) {
        return;
      }
      final message = response['message'];
      final data = message is Map<String, dynamic> ? message : response;
      if (data['name'] != intent.notificationId) {
        throw StateError('Notification response identity mismatch.');
      }
      final destination = pushDestination(
        data,
        ref.read(effectiveCapabilitiesProvider),
      );
      if (destination == null) {
        source?.consumeOpen(intent);
        setState(
          () => _error = 'This update is no longer available for this account.',
        );
        return;
      }
      source?.consumeOpen(intent);
      _failedIntent = null;
      if (_error != null) setState(() => _error = null);
      ref.read(appRouterProvider).go(destination);
    } catch (error) {
      if (!mounted ||
          _coordinator.owner != owner ||
          _coordinator.bindingId != intent.bindingId) {
        return;
      }
      final terminal =
          error is ApiError &&
          (error.statusCode == 401 ||
              error.statusCode == 403 ||
              error.statusCode == 404);
      if (terminal) source?.consumeOpen(intent);
      setState(() {
        _failedIntent = terminal ? null : intent;
        _error = terminal
            ? 'This update is no longer available for this account.'
            : 'The update could not be opened. Check your connection and retry.';
      });
    } finally {
      _busy = false;
      if (identical(_lookup, cancellation)) _lookup = null;
      if (mounted &&
          source?.pendingOpen != null &&
          source?.pendingOpen != _failedIntent) {
        _schedule();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(pushAuthBindingProvider);
    final auth = ref.watch(authControllerProvider);
    ref.watch(deviceLockSessionUnlockedProvider);
    ref.watch(pushNavigationAllowedProvider);
    if (auth.userId?.isNotEmpty == true) {
      ref.watch(biometricLoginEnabledForProvider(auth.userId!));
    }
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (previous?.userId != next.userId ||
          next.status != AuthStatus.authenticated) {
        _lookup?.cancel('Session changed');
        _failedIntent = null;
        _error = null;
      }
    });
    _schedule();
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_error != null && _ready())
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Material(
                    color: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.card),
                      side: const BorderSide(color: AppTheme.border),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final stackActions =
                              constraints.maxWidth < 320 ||
                              MediaQuery.textScalerOf(context).scale(1) > 1.3;
                          final dismiss = OutlinedButton(
                            onPressed: () {
                              _coordinator.boundSource?.clearPending();
                              setState(() {
                                _error = null;
                                _failedIntent = null;
                              });
                            },
                            child: const Text('Dismiss'),
                          );
                          final retry = _failedIntent == null
                              ? null
                              : FilledButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _error = null;
                                      _failedIntent = null;
                                    });
                                    _schedule();
                                  },
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('Retry'),
                                );

                          return Semantics(
                            container: true,
                            liveRegion: true,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Icon(
                                      Icons.error_outline_rounded,
                                      color: AppTheme.danger,
                                      size: 22,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Update could not be opened',
                                            style: Theme.of(
                                              context,
                                            ).textTheme.titleMedium,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _error!,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodyMedium,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 14),
                                if (stackActions) ...[
                                  ?retry,
                                  if (retry != null) const SizedBox(height: 8),
                                  dismiss,
                                ] else
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Flexible(child: dismiss),
                                      if (retry != null) ...[
                                        const SizedBox(width: 8),
                                        Flexible(child: retry),
                                      ],
                                    ],
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _coordinator.status.removeListener(_schedule);
    _lookup?.cancel('Push host disposed');
    unawaited(_opens?.cancel());
    super.dispose();
  }
}
