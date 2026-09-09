import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design_tokens.dart';
import '../../../app/theme.dart';
import '../../../core/diagnostics/omc_widget_keys.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../data/device_lock_service.dart';

final biometricActionLabelProvider = FutureProvider<String>((ref) {
  return ref.read(deviceLockServiceProvider).biometricActionLabel();
});

class DeviceLockGate extends ConsumerStatefulWidget {
  const DeviceLockGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<DeviceLockGate> createState() => _DeviceLockGateState();
}

class _DeviceLockGateState extends ConsumerState<DeviceLockGate> {
  bool _authenticating = false;
  String? _failureMessage;

  Future<void> _unlock() async {
    if (_authenticating) return;

    final attemptIdentity =
        ref.read(authControllerProvider).userId?.trim().toLowerCase() ?? '';
    if (attemptIdentity.isEmpty) return;

    setState(() {
      _authenticating = true;
      _failureMessage = null;
    });

    final authenticated = await ref
        .read(deviceLockServiceProvider)
        .authenticate();

    if (!mounted) return;

    final currentAuth = ref.read(authControllerProvider);
    final currentIdentity = currentAuth.userId?.trim().toLowerCase() ?? '';
    final sameAuthenticatedAccount =
        currentAuth.status == AuthStatus.authenticated &&
        currentIdentity == attemptIdentity;

    if (!sameAuthenticatedAccount) {
      setState(() => _authenticating = false);
      return;
    }

    if (authenticated) {
      setState(() => _authenticating = false);
      ref.read(deviceLockSessionUnlockedProvider.notifier).markUnlocked();
      return;
    }

    setState(() {
      _authenticating = false;
      _failureMessage =
          'Authentication was cancelled or not recognized. '
          'Retry or use another account.';
    });
  }

  Future<void> _useAnotherAccount() async {
    if (_authenticating) return;

    setState(() {
      _authenticating = true;
      _failureMessage = null;
    });

    // Prevent the gate from intercepting a successful logout transition.
    ref.read(deviceLockSessionUnlockedProvider.notifier).markUnlocked();

    try {
      await ref.read(authControllerProvider.notifier).logout();

      ref.invalidate(deviceLockEnabledProvider);
      ref.invalidate(biometricLoginAvailableProvider);
      ref.invalidate(biometricLoginAccountsProvider);
    } catch (_) {
      // Logout did not remove authenticated ownership. Restore the lock and
      // leave the user with a recoverable action instead of a disabled gate.
      ref.read(deviceLockSessionUnlockedProvider.notifier).markLocked();

      if (!mounted) return;
      setState(() {
        _failureMessage =
            'Unable to switch accounts right now. '
            'Check your connection and try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _authenticating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      final previousIdentity = previous?.userId?.trim().toLowerCase() ?? '';
      final nextIdentity = next.userId?.trim().toLowerCase() ?? '';

      if (previousIdentity == nextIdentity || !mounted) return;

      setState(() {
        _authenticating = false;
        _failureMessage = null;
      });
    });

    final authState = ref.watch(authControllerProvider);
    final sessionUnlocked = ref.watch(deviceLockSessionUnlockedProvider);

    final activeIdentity = authState.userId?.trim() ?? '';

    final enrolledAsync = activeIdentity.isEmpty
        ? const AsyncValue<bool>.data(false)
        : ref.watch(biometricLoginEnabledForProvider(activeIdentity));

    final enrolledForActiveAccount = enrolledAsync.value == true;

    final mustLock =
        authState.status == AuthStatus.authenticated &&
        activeIdentity.isNotEmpty &&
        enrolledForActiveAccount &&
        !sessionUnlocked;

    final actionLabel =
        ref.watch(biometricActionLabelProvider).value ??
        'Unlock with biometrics';

    final isFace = actionLabel.toLowerCase().contains('face');

    return Stack(
      fit: StackFit.expand,
      children: [
        // Keep the Router/Navigator subtree mounted, while a visible lock must
        // also remove its content from pointer, keyboard and semantics access.
        ExcludeFocus(
          excluding: mustLock,
          child: ExcludeSemantics(
            excluding: mustLock,
            child: IgnorePointer(
              ignoring: mustLock,
              child: TickerMode(enabled: !mustLock, child: widget.child),
            ),
          ),
        ),

        if (mustLock)
          Positioned.fill(
            child: _DeviceLockPanel(
              activeIdentity: activeIdentity,
              actionLabel: actionLabel,
              isFace: isFace,
              authenticating: _authenticating,
              failureMessage: _failureMessage,
              onUnlock: _unlock,
              onUseAnotherAccount: _useAnotherAccount,
            ),
          ),
      ],
    );
  }
}

class _DeviceLockPanel extends StatelessWidget {
  const _DeviceLockPanel({
    required this.activeIdentity,
    required this.actionLabel,
    required this.isFace,
    required this.authenticating,
    required this.failureMessage,
    required this.onUnlock,
    required this.onUseAnotherAccount,
  });

  final String activeIdentity;
  final String actionLabel;
  final bool isFace;
  final bool authenticating;
  final String? failureMessage;
  final VoidCallback onUnlock;
  final VoidCallback onUseAnotherAccount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      key: OmcWidgetKeys.deviceLockScreen,
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ExcludeSemantics(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                      ),
                      child: Icon(
                        isFace
                            ? Icons.face_retouching_natural_rounded
                            : Icons.fingerprint_rounded,
                        size: 40,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Semantics(
                    header: true,
                    child: Text(
                      'Unlock OMC House',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Unlock $activeIdentity to continue.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  if (failureMessage != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Semantics(
                      liveRegion: true,
                      label: failureMessage!,
                      excludeSemantics: true,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppTheme.warningSoft,
                          borderRadius: BorderRadius.circular(AppRadius.card),
                          border: Border.all(
                            color: AppTheme.warning.withValues(alpha: 0.20),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.warning_amber_rounded,
                              color: AppTheme.warning,
                              size: 24,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                failureMessage!,
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
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: authenticating ? null : onUnlock,
                      icon: authenticating
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              isFace
                                  ? Icons.face_retouching_natural_rounded
                                  : Icons.fingerprint_rounded,
                            ),
                      label: Text(
                        failureMessage != null ? 'Try again' : actionLabel,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  TextButton(
                    key: OmcWidgetKeys.deviceLockUseAnotherAccount,
                    onPressed: authenticating ? null : onUseAnotherAccount,
                    child: const Text('Use another account'),
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
