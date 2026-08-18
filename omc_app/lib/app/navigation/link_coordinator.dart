import '../../features/auth/application/auth_state.dart';

class LinkCoordinator {
  Uri? _pending;

  Uri? normalize(Uri uri) {
    if (uri.hasScheme) {
      final isVerifiedHttps =
          uri.scheme == 'https' &&
          uri.host == 'erp.omchouse.com' &&
          uri.path.startsWith('/app/');
      final isTestScheme = uri.scheme == 'omchouse' && uri.host == 'auth';
      if (!isVerifiedHttps && !isTestScheme) return null;
    }

    var path = uri.path;
    if (path.startsWith('/app/')) path = path.substring(4);
    if (!path.startsWith('/')) path = '/$path';
    if (!_isAllowedPath(path)) return null;
    return Uri(
      path: path,
      queryParameters: uri.queryParameters.isEmpty ? null : uri.queryParameters,
    );
  }

  void queue(Uri uri) {
    final normalized = normalize(uri);
    if (normalized == null || normalized == _pending) return;
    _pending = normalized;
  }

  String? takeFor(AuthStatus status) {
    if (status == AuthStatus.checking || status == AuthStatus.authenticating) {
      return null;
    }
    final pending = _pending;
    if (pending == null) return null;
    final path = pending.path;
    final publicTokenRoute =
        path == '/verify-email' ||
        path == '/reset-password' ||
        path == '/activate-account';
    if (status != AuthStatus.authenticated && !publicTokenRoute) return null;
    _pending = null;
    return pending.toString();
  }

  bool _isAllowedPath(String path) {
    return path == '/verify-email' ||
        path == '/reset-password' ||
        path == '/activate-account' ||
        path == '/notifications' ||
        path.startsWith('/notifications/') ||
        path.startsWith('/my-services/') ||
        path.startsWith('/documents/') ||
        path.startsWith('/payments/') ||
        path.startsWith('/support-tickets/');
  }
}
