enum AuthStatus { checking, authenticating, authenticated, unauthenticated }

class AuthState {
  const AuthState({
    required this.status,
    this.userId,
    this.message,
    this.canAccessInternalWorkspace = false,
    this.displayName,
    this.phone,
    this.companyName,
    this.customerStatus,
    this.approvalStatus,
  });

  final AuthStatus status;
  final String? userId;
  final String? message;
  final bool canAccessInternalWorkspace;
  final String? displayName;
  final String? phone;
  final String? companyName;
  final String? customerStatus;
  final String? approvalStatus;

  const AuthState.checking()
    : status = AuthStatus.checking,
      userId = null,
      message = null,
      canAccessInternalWorkspace = false,
      displayName = null,
      phone = null,
      companyName = null,
      customerStatus = null,
      approvalStatus = null;

  const AuthState.authenticating()
    : status = AuthStatus.authenticating,
      userId = null,
      message = null,
      canAccessInternalWorkspace = false,
      displayName = null,
      phone = null,
      companyName = null,
      customerStatus = null,
      approvalStatus = null;

  const AuthState.authenticated({
    required String this.userId,
    this.canAccessInternalWorkspace = false,
    this.displayName,
    this.phone,
    this.companyName,
    this.customerStatus,
    this.approvalStatus,
  }) : status = AuthStatus.authenticated,
       message = null;

  const AuthState.unauthenticated({this.message})
    : status = AuthStatus.unauthenticated,
      userId = null,
      canAccessInternalWorkspace = false,
      displayName = null,
      phone = null,
      companyName = null,
      customerStatus = null,
      approvalStatus = null;

  AuthState copyWith({
    AuthStatus? status,
    String? userId,
    String? message,
    bool? canAccessInternalWorkspace,
    String? displayName,
    String? phone,
    String? companyName,
    String? customerStatus,
    String? approvalStatus,
  }) {
    return AuthState(
      status: status ?? this.status,
      userId: userId ?? this.userId,
      message: message ?? this.message,
      canAccessInternalWorkspace:
          canAccessInternalWorkspace ?? this.canAccessInternalWorkspace,
      displayName: displayName ?? this.displayName,
      phone: phone ?? this.phone,
      companyName: companyName ?? this.companyName,
      customerStatus: customerStatus ?? this.customerStatus,
      approvalStatus: approvalStatus ?? this.approvalStatus,
    );
  }
}
