import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../app/providers/core_providers.dart';
import '../../../core/forms/dirty_form_controller.dart';
import '../../device_lock/data/device_lock_service.dart';
import '../data/auth_repository.dart';
import 'auth_state.dart';

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends Notifier<AuthState> {
  late final _authRepository = ref.read(authRepositoryProvider);
  bool _sessionExpiryInFlight = false;

  @override
  AuthState build() {
    ref.listen<int>(sessionExpirySignalProvider, (previous, next) {
      if (previous != next && state.status == AuthStatus.authenticated) {
        _expireSession();
      }
    });
    return const AuthState.checking();
  }

  Future<void> _activateSession(AuthSession session) async {
    await ref
        .read(deviceLockServiceProvider)
        .preserveBiometricLoginOnlyFor(session.userId);
    state = AuthState.authenticated(
      userId: session.userId,
      canAccessInternalWorkspace: session.canAccessInternalWorkspace,
      capabilities: session.capabilities,
    );

    await _advanceSessionBoundary();
  }

  Future<void> checkSession() async {
    try {
      final session = await _authRepository.readStoredSession();
      if (session == null) {
        state = const AuthState.unauthenticated();
        return;
      }

      await _activateSession(session);
    } catch (_) {
      state = const AuthState.unauthenticated();
      await _clearSessionBestEffort();
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = const AuthState.authenticating();

    try {
      final session = await _authRepository.loginWithPassword(
        email: email,
        password: password,
      );

      // Manual password authentication has already verified the user.
      // Unlock this runtime session before authenticated state is exposed,
      // so DeviceLockGate cannot flash or block after password login.
      ref.read(deviceLockSessionUnlockedProvider.notifier).markUnlocked();

      await _activateSession(session);
    } catch (error) {
      ref.read(deviceLockSessionUnlockedProvider.notifier).markLocked();
      state = AuthState.unauthenticated(message: _safeLoginMessage(error));
      await _clearSessionBestEffort();
    }
  }

  Future<bool> loginWithBiometrics(String identifier) async {
    final cleanIdentifier = identifier.trim();

    if (cleanIdentifier.isEmpty) {
      state = const AuthState.unauthenticated(
        message: 'Select a biometric login account.',
      );
      return false;
    }

    state = const AuthState.authenticating();

    try {
      final credentials = await ref
          .read(deviceLockServiceProvider)
          .authenticateAndReadBiometricLoginFor(cleanIdentifier);

      if (credentials == null) {
        state = const AuthState.unauthenticated(
          message: 'Biometric authentication was not completed.',
        );
        return false;
      }

      final session = await _authRepository.loginWithPassword(
        email: credentials.identifier,
        password: credentials.password,
      );

      ref.read(deviceLockSessionUnlockedProvider.notifier).markUnlocked();

      await _activateSession(session);
      return true;
    } catch (error) {
      ref.read(deviceLockSessionUnlockedProvider.notifier).markLocked();
      state = AuthState.unauthenticated(message: _safeLoginMessage(error));
      await _clearSessionBestEffort();
      return false;
    }
  }

  void syncProfileSummary({
    required String displayName,
    required String email,
    required bool canAccessInternalWorkspace,
    AuthCapabilities? capabilities,
    String? phone,
    String? companyName,
    String? customerStatus,
    String? approvalStatus,
    String? avatarUrl,
  }) {
    if (state.status != AuthStatus.authenticated) return;

    final nextState = state.copyWith(
      userId: email,
      canAccessInternalWorkspace:
          capabilities?.canAccessInternalWorkspace ??
          canAccessInternalWorkspace,
      displayName: displayName,
      phone: phone,
      companyName: companyName,
      customerStatus: customerStatus,
      approvalStatus: approvalStatus,
      avatarUrl: avatarUrl,
      capabilities: capabilities,
    );

    final didChange =
        nextState.userId != state.userId ||
        nextState.canAccessInternalWorkspace !=
            state.canAccessInternalWorkspace ||
        nextState.displayName != state.displayName ||
        nextState.phone != state.phone ||
        nextState.companyName != state.companyName ||
        nextState.customerStatus != state.customerStatus ||
        nextState.approvalStatus != state.approvalStatus ||
        nextState.avatarUrl != state.avatarUrl ||
        nextState.capabilities != state.capabilities;

    if (didChange) state = nextState;
  }

  Future<bool> continueAsGuest() async {
    try {
      // Drop protected UI ownership before any network cleanup. On Web the
      // logout call is also required to clear the browser-managed Frappe
      // cookie; clearing local storage alone is not a Guest transition.
      state = const AuthState.unauthenticated();
      ref.read(deviceLockSessionUnlockedProvider.notifier).markLocked();
      await _authRepository.logout();
      await _authRepository.createGuestSession();
      state = const AuthState.guest();

      return true;
    } catch (error) {
      await _clearSessionBestEffort();
      state = AuthState.unauthenticated(
        message: AppFailureClassifier.classify(
          error,
          fallbackTitle: 'Guest access unavailable',
          fallbackMessage:
              'Guest access could not be started right now. Please try again.',
        ).message,
      );

      return false;
    } finally {
      await _advanceSessionBoundary();
    }
  }

  Future<void> logout() async {
    // Remove authenticated ownership before starting remote cleanup. This
    // prevents protected providers from issuing refreshes while logout is in
    // flight and avoids mounting DeviceLockGate during the transition.
    state = const AuthState.unauthenticated();
    ref.read(deviceLockSessionUnlockedProvider.notifier).markLocked();

    try {
      await _authRepository.logout();
    } finally {
      await _advanceSessionBoundary();
    }
  }

  Future<void> _expireSession() async {
    if (_sessionExpiryInFlight || state.status != AuthStatus.authenticated) {
      return;
    }
    _sessionExpiryInFlight = true;
    try {
      state = const AuthState.unauthenticated(
        message: 'Your session has expired. Please sign in again.',
      );
      ref.read(deviceLockSessionUnlockedProvider.notifier).markLocked();
      await _clearSessionBestEffort();
      await _advanceSessionBoundary();
    } finally {
      _sessionExpiryInFlight = false;
    }
  }

  Future<void> _clearSessionBestEffort() async {
    try {
      await _authRepository.clearSession();
    } catch (_) {
      // AuthState remains fail-closed even when device storage is unavailable.
    }
  }

  Future<void> _advanceSessionBoundary() async {
    // Auth state changes can cause GoRouter to replace a screen immediately.
    // Defer dependent-provider refreshes until the current build is complete.
    await Future<void>.delayed(Duration.zero);
    ref.read(sessionEpochProvider.notifier).advance();
    ref.invalidate(activeDirtyFormProvider);
  }

  String _safeLoginMessage(Object error) {
    if (error is ApiError) {
      final message = error.message.trim();
      final lower = message.toLowerCase();
      if (error.statusCode == 401 ||
          error.statusCode == 403 ||
          lower.contains('incorrect') ||
          lower.contains('invalid login') ||
          lower.contains('invalid password') ||
          lower.contains('invalid credential') ||
          lower.contains('wrong email') ||
          lower.contains('wrong password') ||
          lower.contains('user not found') ||
          lower.contains('unknown user') ||
          lower.contains('does not exist') ||
          lower.contains('authentication failed') ||
          lower.contains('account disabled') ||
          lower.contains('user disabled')) {
        return 'Wrong email or password. Please try again.';
      }
    }

    return AppFailureClassifier.classify(
      error,
      fallbackTitle: 'Sign in unavailable',
      fallbackMessage: 'Unable to login right now. Please try again.',
    ).message;
  }
}
