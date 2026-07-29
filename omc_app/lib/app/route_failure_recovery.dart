import '../features/auth/application/auth_state.dart';

enum RouteFailureRecoveryKind { home, signIn, accountStatus }

class RouteFailureRecovery {
  const RouteFailureRecovery({
    required this.location,
    required this.label,
    required this.kind,
  });

  final String location;
  final String label;
  final RouteFailureRecoveryKind kind;
}

RouteFailureRecovery resolveRouteFailureRecovery({
  required AuthStatus status,
  required AuthCapabilities capabilities,
}) {
  if (status == AuthStatus.unauthenticated) {
    return const RouteFailureRecovery(
      location: '/login',
      label: 'Go to sign in',
      kind: RouteFailureRecoveryKind.signIn,
    );
  }

  if (status == AuthStatus.authenticated && capabilities.isPending) {
    return const RouteFailureRecovery(
      location: '/under-review',
      label: 'View account status',
      kind: RouteFailureRecoveryKind.accountStatus,
    );
  }

  return const RouteFailureRecovery(
    location: '/home',
    label: 'Go to home',
    kind: RouteFailureRecoveryKind.home,
  );
}
