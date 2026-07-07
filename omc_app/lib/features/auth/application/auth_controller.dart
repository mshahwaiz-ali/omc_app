import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
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
    } on ApiError catch (error) {
      await _authRepository.clearSession();
      state = AuthState.unauthenticated(message: error.message);
    } catch (_) {
      await _authRepository.clearSession();
      state = const AuthState.unauthenticated(
        message: 'Unable to login right now. Please try again.',
      );
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
        nextState.capabilities != state.capabilities;

    if (didChange) state = nextState;
  }

  Future<void> continueAsGuest() async {
    await _authRepository.clearSession();
    state = const AuthState.guest();
    await _authRepository.createGuestSession();
  }

  Future<void> logout() async {
    await _authRepository.logout();
    state = const AuthState.unauthenticated();
  }
}
