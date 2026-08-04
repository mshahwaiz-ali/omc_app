import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import '../data/device_lock_service.dart';

class DeviceLockGate extends ConsumerStatefulWidget {
  const DeviceLockGate({required this.child, super.key});
  final Widget child;

  @override
  ConsumerState<DeviceLockGate> createState() => _DeviceLockGateState();
}

class _DeviceLockGateState extends ConsumerState<DeviceLockGate>
    with WidgetsBindingObserver {
  bool _locked = true;
  bool _authenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Android reports `inactive` while its biometric dialog is visible.
    // Treating that as background immediately re-locks the app and causes
    // a second authentication prompt.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      ref.read(deviceLockSessionUnlockedProvider.notifier).markLocked();
      if (mounted) setState(() => _locked = true);
      return;
    }

    if (state == AppLifecycleState.resumed && _locked) {
      _unlock();
    }
  }

  Future<void> _unlock() async {
    if (_authenticating || !mounted) return;

    // Set this before any await so repeated builds cannot start parallel
    // biometric requests.
    setState(() => _authenticating = true);

    try {
      final auth = ref.read(authControllerProvider);
      final service = ref.read(deviceLockServiceProvider);
      final enabled = await service.isEnabled();

      if (!mounted) return;

      if (auth.status != AuthStatus.authenticated || !enabled) {
        ref.read(deviceLockSessionUnlockedProvider.notifier).markUnlocked();
        setState(() => _locked = false);
        return;
      }

      final alreadyUnlocked = ref.read(deviceLockSessionUnlockedProvider);
      if (alreadyUnlocked) {
        setState(() => _locked = false);
        return;
      }

      final unlocked = await service.authenticate();
      if (!mounted) return;

      ref
          .read(deviceLockSessionUnlockedProvider.notifier)
          .setUnlocked(unlocked);
      setState(() => _locked = !unlocked);
    } finally {
      if (mounted) setState(() => _authenticating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    if (auth.status != AuthStatus.authenticated) return widget.child;
    final enabledState = ref.watch(deviceLockEnabledProvider);
    if (enabledState.isLoading) {
      return const Material(
        color: Color(0xFFF8FAFD),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final enabled = enabledState.value ?? false;
    final sessionUnlocked = ref.watch(deviceLockSessionUnlockedProvider);
    final shouldLock = enabled && auth.status == AuthStatus.authenticated;

    if (!shouldLock || sessionUnlocked || !_locked) {
      return widget.child;
    }

    if (!_authenticating) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_authenticating && _locked) _unlock();
      });
    }
    return Material(
      color: const Color(0xFFF8FAFD),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_rounded, size: 58),
                const SizedBox(height: 18),
                const Text(
                  'OMC House is locked',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Use your fingerprint, Face ID or device credential to continue.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 22),
                FilledButton.icon(
                  onPressed: _authenticating ? null : _unlock,
                  icon: const Icon(Icons.fingerprint_rounded),
                  label: const Text('Unlock'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
