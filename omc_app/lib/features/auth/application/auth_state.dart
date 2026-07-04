enum AuthStatus { checking, authenticated, unauthenticated }

class AuthState {
  const AuthState({required this.status, this.userId, this.message});

  final AuthStatus status;
  final String? userId;
  final String? message;

  const AuthState.checking()
    : status = AuthStatus.checking,
      userId = null,
      message = null;

  const AuthState.authenticated({required String this.userId})
    : status = AuthStatus.authenticated,
      message = null;

  const AuthState.unauthenticated({this.message})
    : status = AuthStatus.unauthenticated,
      userId = null;
}
