import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/app/auth_route_redirect.dart';
import 'package:omc_app/features/auth/application/auth_state.dart';

void main() {
  const pending = AuthCapabilities(accessState: AccountAccessState.pending);
  const approved = AuthCapabilities(accessState: AccountAccessState.approved);
  const internal = AuthCapabilities(
    accessState: AccountAccessState.internal,
    canAccessInternalWorkspace: true,
  );
  const internalCaseViewer = AuthCapabilities(
    accessState: AccountAccessState.internal,
    canAccessInternalWorkspace: true,
    canViewRelevantServiceCases: true,
  );

  String? redirect(
    AuthStatus status,
    String location, {
    AuthCapabilities capabilities = AuthCapabilities.guest,
  }) {
    return resolveAuthRouteRedirect(
      status: status,
      capabilities: capabilities,
      location: location,
    );
  }

  group('token-consumption routes', () {
    for (final route in const ['/verify-email', '/reset-password']) {
      test('$route survives every auth state', () {
        for (final status in AuthStatus.values) {
          final capabilities = status == AuthStatus.authenticated
              ? approved
              : AuthCapabilities.guest;
          expect(
            redirect(status, route, capabilities: capabilities),
            isNull,
            reason: '$route must remain available during $status',
          );
        }
      });
    }
  });

  group('session checking', () {
    test('keeps splash and redirects protected routes to splash', () {
      expect(redirect(AuthStatus.checking, '/'), isNull);
      expect(redirect(AuthStatus.checking, '/documents'), '/');
    });
  });

  group('unauthenticated users', () {
    test('may open anonymous entry routes', () {
      for (final route in const [
        '/',
        '/onboarding',
        '/login',
        '/signup',
        '/forgot-password',
      ]) {
        expect(redirect(AuthStatus.unauthenticated, route), isNull);
      }
    });

    test('are redirected from protected and review routes', () {
      expect(redirect(AuthStatus.unauthenticated, '/documents'), '/login');
      expect(redirect(AuthStatus.unauthenticated, '/under-review'), '/login');
    });
  });

  group('guest users', () {
    test('may open anonymous routes but not under-review', () {
      expect(redirect(AuthStatus.guest, '/login'), isNull);
      expect(redirect(AuthStatus.guest, '/forgot-password'), isNull);
      expect(
        redirect(AuthStatus.guest, '/under-review'),
        '/home?notice=access-denied',
      );
    });

    test('leave splash for home without a denial notice', () {
      expect(redirect(AuthStatus.guest, '/'), '/home');
    });

    test('receive feedback when a protected route is denied', () {
      expect(
        redirect(AuthStatus.guest, '/documents'),
        '/home?notice=access-denied',
      );
    });
  });

  group('authenticated users', () {
    test('pending users land on under-review from auth entry routes', () {
      for (final route in const [
        '/',
        '/login',
        '/signup',
        '/forgot-password',
      ]) {
        expect(
          redirect(AuthStatus.authenticated, route, capabilities: pending),
          '/under-review',
        );
      }
    });

    test('pending users may remain on under-review', () {
      expect(
        redirect(
          AuthStatus.authenticated,
          '/under-review',
          capabilities: pending,
        ),
        isNull,
      );
    });

    test('approved and internal users cannot remain on under-review', () {
      expect(
        redirect(
          AuthStatus.authenticated,
          '/under-review',
          capabilities: approved,
        ),
        '/home',
      );
      expect(
        redirect(
          AuthStatus.authenticated,
          '/under-review',
          capabilities: internal,
        ),
        '/home',
      );
    });

    test('approved users leave login for home without a denial notice', () {
      expect(
        redirect(AuthStatus.authenticated, '/login', capabilities: approved),
        '/home',
      );
    });

    test('approved users receive feedback for capability-denied routes', () {
      expect(
        redirect(
          AuthStatus.authenticated,
          '/internal-workspace',
          capabilities: approved,
        ),
        '/home?notice=access-denied',
      );
    });

    test('staff customer-style case links move to internal case detail', () {
      expect(
        redirect(
          AuthStatus.authenticated,
          '/my-services/OMC-SR-0001',
          capabilities: internalCaseViewer,
        ),
        '/internal-workspace/service-cases/OMC-SR-0001',
      );
    });

    test('staff customer-style case root moves to internal case queue', () {
      expect(
        redirect(
          AuthStatus.authenticated,
          '/my-services',
          capabilities: internalCaseViewer,
        ),
        '/internal-workspace/service-cases',
      );
    });

    test('customer case links remain customer case links', () {
      const customer = AuthCapabilities(
        accessState: AccountAccessState.approved,
        canTrackRequests: true,
      );
      expect(
        redirect(
          AuthStatus.authenticated,
          '/my-services/OMC-SR-0001',
          capabilities: customer,
        ),
        isNull,
      );
    });
  });
}
