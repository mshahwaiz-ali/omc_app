import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/resilience/app_failure.dart';
import '../data/auth_repository.dart';
import 'auth_state.dart';

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

class AuthController extends Notifier<AuthState> {
  late final _authRepository = ref.read(authRepositoryProvider);

  @override
  AuthState build() {
    return const AuthState.checking();
  }

  Future<void> checkSession() async {
    try {
      final session = await _authRepository.readStoredSession();
      if (session == null) {
        state = const AuthState.unauthenticated();
        return;
      }

      state = AuthState.authenticated(
        userId: session.userId,
        canAccessInternalWorkspace: session.canAccessInternalWorkspace,
        capabilities: session.capabilities,
      );
    } catch (_) {
      await _authRepository.clearSession();
      state = const AuthState.unauthenticated();
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = const AuthState.authenticating();

    try {
      final session = await _authRepository.loginWithPassword(
        email: email,
        password: password,
      );

      state = AuthState.authenticated(
        userId: session.userId,
        canAccessInternalWorkspace: session.canAccessInternalWorkspace,
        capabilities: session.capabilities,
      );
    } catch (error) {
      await _authRepository.clearSession();
      state = AuthState.unauthenticated(message: _safeLoginMessage(error));
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
      await _authRepository.clearSession();
      await _authRepository.createGuestSession();
      state = const AuthState.guest();
      return true;
    } catch (error) {
      state = AuthState.unauthenticated(
        message: AppFailureClassifier.classify(
          error,
          fallbackTitle: 'Guest access unavailable',
          fallbackMessage:
              'Guest access could not be started right now. Please try again.',
        ).message,
      );
      return false;
    }
  }

  Future<void> logout() async {
    await _authRepository.logout();
    state = const AuthState.unauthenticated();
  }

  String _safeLoginMessage(Object error) {
    if (error is ApiError) {
      final message = error.message.trim();
      final lower = message.toLowerCase();
      if (error.statusCode == 401 ||
          lower.contains('incorrect') ||
          lower.contains('invalid login') ||
          lower.contains('invalid password') ||
          lower.contains('authentication failed')) {
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
