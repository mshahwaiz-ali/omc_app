import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
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
        // Never remove the Router/Navigator subtree during auth,
        // biometric, dialog, or logout state transitions.
        widget.child,

        if (mustLock)
          Positioned.fill(
            child: Material(
              color: const Color(0xFFF8FAFC),
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 92,
                            height: 92,
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.09),
                              borderRadius: BorderRadius.circular(28),
                            ),
                            child: Icon(
                              isFace
                                  ? Icons.face_retouching_natural_rounded
                                  : Icons.fingerprint_rounded,
                              size: 48,
                              color: AppTheme.primary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Text(
                            'Unlock OMC House',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 27,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Unlock $activeIdentity to continue.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                              height: 1.45,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_failureMessage != null) ...[
                            const SizedBox(height: 18),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF7ED),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFFFED7AA),
                                ),
                              ),
                              child: Text(
                                _failureMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF9A3412),
                                  fontWeight: FontWeight.w700,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _authenticating ? null : _unlock,
                              icon: _authenticating
                                  ? const SizedBox(
                                      width: 19,
                                      height: 19,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                      ),
                                    )
                                  : Icon(
                                      isFace
                                          ? Icons
                                                .face_retouching_natural_rounded
                                          : Icons.fingerprint_rounded,
                                    ),
                              label: Text(
                                _failureMessage != null
                                    ? 'Try again'
                                    : actionLabel,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextButton(
                            onPressed: _authenticating
                                ? null
                                : _useAnotherAccount,
                            child: const Text('Use another account'),
                          ),
                        ],
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
}
