import '../features/auth/application/auth_state.dart';
import 'route_access_policy.dart';

const _tokenConsumptionRoutes = <String>{
  '/verify-email',
  '/reset-password',
  '/activate-account',
};
const _accessDeniedHome = '/home?notice=access-denied';

const _anonymousEntryRoutes = <String>{
  '/onboarding',
  '/login',
  '/signup',
  '/forgot-password',
  '/activate-existing-account',
};

/// Returns a redirect location, or `null` when the requested route is allowed.
///
/// Verification and password-reset routes deliberately remain available for
/// every session state, including the initial session check. This preserves
/// email-link tokens during cold app launches and allows a signed-in user to
/// consume a link without being forced to log out first.
String? resolveAuthRouteRedirect({
  required AuthStatus status,
  required AuthCapabilities capabilities,
  required String location,
}) {
  final isSplash = location == '/';
  final isTokenConsumptionRoute = _tokenConsumptionRoutes.contains(location);
  final isAnonymousEntryRoute = _anonymousEntryRoutes.contains(location);
  final isUnderReviewRoute = location == '/under-review';

  if (isTokenConsumptionRoute) return null;

  if (status == AuthStatus.checking) {
    return isSplash ? null : '/';
  }

  if (status == AuthStatus.unauthenticated) {
    return isAnonymousEntryRoute || isSplash ? null : '/login';
  }

  if (status == AuthStatus.guest) {
    if (isSplash) return '/home';
    if (isAnonymousEntryRoute) return null;
    return isGuestAllowedRoute(location) ? null : _accessDeniedHome;
  }

  if (status == AuthStatus.authenticated) {
    final authenticatedHome = capabilities.isPending
        ? '/under-review'
        : '/home';

    if (isAnonymousEntryRoute || isSplash) return authenticatedHome;
    if (isUnderReviewRoute) {
      return capabilities.isPending ? null : '/home';
    }

    if (canAccessRoute(location, capabilities)) return null;
    return authenticatedHome == '/home' ? _accessDeniedHome : authenticatedHome;
  }

  // AuthStatus.authenticating retains the current route while the explicit
  // login/guest action owns its loading and completion navigation.
  return null;
}
