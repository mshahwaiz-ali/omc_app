enum AuthStatus { checking, authenticating, authenticated, unauthenticated }

class AuthState {
  const AuthState({
    required this.status,
    this.userId,
    this.message,
    this.canAccessInternalWorkspace = false,
  });

  final AuthStatus status;
  final String? userId;
  final String? message;
  final bool canAccessInternalWorkspace;

  const AuthState.checking()
    : status = AuthStatus.checking,
      userId = null,
      message = null,
      canAccessInternalWorkspace = false;

  const AuthState.authenticating()
    : status = AuthStatus.authenticating,
      userId = null,
      message = null,
      canAccessInternalWorkspace = false;

  const AuthState.authenticated({
    required String this.userId,
    this.canAccessInternalWorkspace = false,
  }) : status = AuthStatus.authenticated,
       message = null;

  const AuthState.unauthenticated({this.message})
    : status = AuthStatus.unauthenticated,
      userId = null,
      canAccessInternalWorkspace = false;
}
