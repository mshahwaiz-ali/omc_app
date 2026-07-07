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

      state = AuthState.authenticated(userId: session.userId);
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

      state = AuthState.authenticated(userId: session.userId);
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

  Future<void> logout() async {
    await _authRepository.logout();
    state = const AuthState.unauthenticated();
  }
}
