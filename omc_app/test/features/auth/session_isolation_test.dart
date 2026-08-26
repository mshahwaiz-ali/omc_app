import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:local_auth/local_auth.dart';
import 'package:omc_app/app/providers/core_providers.dart';
import 'package:omc_app/core/config/api_config.dart';
import 'package:omc_app/core/network/api_error.dart';
import 'package:omc_app/core/network/dio_client.dart';
import 'package:omc_app/core/network/frappe_client.dart';
import 'package:omc_app/core/storage/secure_storage_service.dart';
import 'package:omc_app/features/admin_control/data/admin_control_repository.dart';
import 'package:omc_app/features/app_config/data/mobile_app_config_repository.dart';
import 'package:omc_app/features/auth/application/auth_controller.dart';
import 'package:omc_app/features/auth/application/auth_state.dart';
import 'package:omc_app/features/auth/data/auth_repository.dart';
import 'package:omc_app/features/content/data/app_content_repository.dart';
import 'package:omc_app/features/customers/data/customers_repository.dart';
import 'package:omc_app/features/device_lock/data/device_lock_service.dart';
import 'package:omc_app/features/documents/data/documents_repository.dart';
import 'package:omc_app/features/home/data/home_content_repository.dart';
import 'package:omc_app/features/home/data/home_dashboard_repository.dart';
import 'package:omc_app/features/home/data/mobile_quick_actions_repository.dart';
import 'package:omc_app/features/internal_workspace/presentation/internal_workspace_providers.dart';
import 'package:omc_app/features/knowledge/data/knowledge_repository.dart';
import 'package:omc_app/features/leads/data/leads_repository.dart';
import 'package:omc_app/features/onboarding/data/onboarding_repository.dart';
import 'package:omc_app/features/payments/data/finance_reconciliation_repository.dart';
import 'package:omc_app/features/payments/data/payments_repository.dart';
import 'package:omc_app/features/service_catalogue/data/service_catalogue_repository.dart';
import 'package:omc_app/features/service_requests/data/customer_service_case_repository.dart';
import 'package:omc_app/features/service_requests/data/service_request_repository.dart';
import 'package:omc_app/features/settings/data/settings_repository.dart';
import 'package:omc_app/features/support/data/support_repository.dart';
import 'package:omc_app/features/tasks/data/tasks_repository.dart';

void main() {
  test(
    'identity-owned providers rotate while public providers stay stable',
    () {
      final client = _SessionAwareFrappeClient();
      final container = ProviderContainer(
        overrides: [frappeClientProvider.overrideWithValue(client)],
      );
      addTearDown(container.dispose);

      final protectedBefore = <Object>[
        container.read(adminControlRepositoryProvider),
        container.read(customersRepositoryProvider),
        container.read(documentsRepositoryProvider),
        container.read(financeReconciliationRepositoryProvider),
        container.read(homeContentRepositoryProvider),
        container.read(homeDashboardRepositoryProvider),
        container.read(internalWorkspaceRepositoryProvider),
        container.read(leadsRepositoryProvider),
        container.read(mobileQuickActionsRepositoryProvider),
        container.read(paymentsRepositoryProvider),
        container.read(customerServiceCaseRepositoryProvider),
        container.read(serviceRequestRepositoryProvider),
        container.read(settingsRepositoryProvider),
        container.read(tasksRepositoryProvider),
      ];
      final publicBefore = <Object>[
        container.read(appContentRepositoryProvider),
        container.read(knowledgeRepositoryProvider),
        container.read(mobileAppConfigRepositoryProvider),
        container.read(onboardingRepositoryProvider),
        container.read(serviceCatalogueRepositoryProvider),
      ];
      final dioBefore = container.read(dioClientProvider);

      container.read(sessionEpochProvider.notifier).advance();

      final protectedAfter = <Object>[
        container.read(adminControlRepositoryProvider),
        container.read(customersRepositoryProvider),
        container.read(documentsRepositoryProvider),
        container.read(financeReconciliationRepositoryProvider),
        container.read(homeContentRepositoryProvider),
        container.read(homeDashboardRepositoryProvider),
        container.read(internalWorkspaceRepositoryProvider),
        container.read(leadsRepositoryProvider),
        container.read(mobileQuickActionsRepositoryProvider),
        container.read(paymentsRepositoryProvider),
        container.read(customerServiceCaseRepositoryProvider),
        container.read(serviceRequestRepositoryProvider),
        container.read(settingsRepositoryProvider),
        container.read(tasksRepositoryProvider),
      ];
      final publicAfter = <Object>[
        container.read(appContentRepositoryProvider),
        container.read(knowledgeRepositoryProvider),
        container.read(mobileAppConfigRepositoryProvider),
        container.read(onboardingRepositoryProvider),
        container.read(serviceCatalogueRepositoryProvider),
      ];

      for (var index = 0; index < protectedBefore.length; index++) {
        expect(
          identical(protectedBefore[index], protectedAfter[index]),
          isFalse,
          reason: 'protected provider $index retained a prior session owner',
        );
      }
      for (var index = 0; index < publicBefore.length; index++) {
        expect(
          identical(publicBefore[index], publicAfter[index]),
          isTrue,
          reason: 'public provider $index was rebuilt unnecessarily',
        );
      }
      expect(identical(dioBefore, container.read(dioClientProvider)), isTrue);
    },
  );

  test(
    'auth transitions never expose the previous dashboard or support data',
    () async {
      final client = _SessionAwareFrappeClient();
      final storage = _MemorySecureStorageService();
      final authRepository = _TransitionAuthRepository(
        client: client,
        storage: storage,
        sessions: const [
          AuthSession(
            userId: 'customer-a@example.com',
            capabilities: AuthCapabilities(
              accessState: AccountAccessState.approved,
              canViewCustomerDashboard: true,
              canCreateSupportTicket: true,
            ),
          ),
          AuthSession(
            userId: 'customer-b@example.com',
            capabilities: AuthCapabilities(
              accessState: AccountAccessState.approved,
              canViewCustomerDashboard: true,
              canCreateSupportTicket: true,
            ),
          ),
          AuthSession(
            userId: 'staff-a@example.com',
            canAccessInternalWorkspace: true,
            capabilities: AuthCapabilities(
              accessState: AccountAccessState.internal,
              canAccessInternalWorkspace: true,
              canViewSupportTickets: true,
            ),
          ),
          AuthSession(
            userId: 'staff-b@example.com',
            canAccessInternalWorkspace: true,
            capabilities: AuthCapabilities(
              accessState: AccountAccessState.internal,
              canAccessInternalWorkspace: true,
              canViewSupportTickets: true,
            ),
          ),
        ],
      );
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepository),
          deviceLockServiceProvider.overrideWithValue(
            DeviceLockService(
              authentication: LocalAuthentication(),
              storage: storage,
            ),
          ),
          frappeClientProvider.overrideWithValue(client),
        ],
      );
      addTearDown(container.dispose);

      final boundaryStates = <AuthStatus>[];
      final boundarySubscription = container.listen<int>(sessionEpochProvider, (
        previous,
        next,
      ) {
        boundaryStates.add(container.read(authControllerProvider).status);
      });
      addTearDown(boundarySubscription.close);

      final controller = container.read(authControllerProvider.notifier);

      await controller.login(email: 'customer-a@example.com', password: 'ok');
      await _expectSessionData(container, activeCases: 11, unreadSupport: 101);

      await controller.logout();
      _expectNoPriorDashboard(container, 11);
      await _expectSessionData(container, activeCases: 0, unreadSupport: 0);

      await controller.login(email: 'customer-b@example.com', password: 'ok');
      _expectNoPriorDashboard(container, 11);
      await _expectSessionData(container, activeCases: 22, unreadSupport: 202);

      expect(await controller.continueAsGuest(), isTrue);
      _expectNoPriorDashboard(container, 22);
      await _expectSessionData(container, activeCases: 0, unreadSupport: 0);
      expect(
        authRepository.transitionCalls,
        containsAllInOrder(['logout', 'guest']),
      );

      await controller.login(email: 'staff-a@example.com', password: 'ok');
      await _expectSessionData(container, activeCases: 33, unreadSupport: 303);

      await controller.logout();
      _expectNoPriorDashboard(container, 33);
      await controller.login(email: 'staff-b@example.com', password: 'ok');
      _expectNoPriorDashboard(container, 33);
      await _expectSessionData(container, activeCases: 44, unreadSupport: 404);

      container.read(sessionExpirySignalProvider.notifier).signal();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(authControllerProvider).status,
        AuthStatus.unauthenticated,
      );
      _expectNoPriorDashboard(container, 44);
      await _expectSessionData(container, activeCases: 0, unreadSupport: 0);

      expect(
        boundaryStates,
        containsAllInOrder([
          AuthStatus.authenticated,
          AuthStatus.unauthenticated,
          AuthStatus.authenticated,
          AuthStatus.guest,
          AuthStatus.authenticated,
          AuthStatus.unauthenticated,
          AuthStatus.authenticated,
          AuthStatus.unauthenticated,
        ]),
      );
    },
  );

  test(
    'support session caches reset without rebuilding public config',
    () async {
      final client = _SessionAwareFrappeClient()
        ..identity = 'customer-a@example.com';
      final container = ProviderContainer(
        overrides: [frappeClientProvider.overrideWithValue(client)],
      );
      addTearDown(container.dispose);

      await container.read(supportConfigProvider.future);
      expect(await container.read(supportUnreadCountProvider.future), 101);
      expect(
        container.read(supportSyncStateProvider).unread.hasSuccessfulSnapshot,
        isTrue,
      );

      client.identity = 'customer-b@example.com';
      container.read(sessionEpochProvider.notifier).advance();

      expect(
        container.read(supportSyncStateProvider).unread.hasSuccessfulSnapshot,
        isFalse,
      );
      expect(await container.read(supportUnreadCountProvider.future), 202);
      await container.read(supportConfigProvider.future);
      expect(client.supportConfigReads, 1);
      expect(client.supportUnreadReads, 2);
    },
  );

  test(
    'late support responses cannot repopulate a new session cache',
    () async {
      final client = _SessionAwareFrappeClient()
        ..identity = 'customer-a@example.com';
      final delayedResponse = Completer<Map<String, dynamic>>();
      client.delayedUnreadResponse = delayedResponse;
      final container = ProviderContainer(
        overrides: [frappeClientProvider.overrideWithValue(client)],
      );
      addTearDown(container.dispose);

      final repository = container.read(supportRepositoryProvider);
      final previousSessionRead = repository.fetchSupportUnreadCount();

      client.identity = 'customer-b@example.com';
      container.read(sessionEpochProvider.notifier).advance();
      delayedResponse.complete(const {
        'message': {'count': 101},
      });

      await expectLater(
        previousSessionRead,
        throwsA(
          isA<ApiError>().having(
            (error) => error.code,
            'code',
            'support_session_changed',
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(supportSyncStateProvider).unread.status,
        SupportFreshnessStatus.idle,
      );
      expect(await repository.fetchSupportUnreadCount(), 202);
      expect(client.supportUnreadReads, 2);
    },
  );

  test('logout removes protected ownership before remote cleanup', () async {
    final client = _SessionAwareFrappeClient();
    final storage = _MemorySecureStorageService();
    final authRepository = _TransitionAuthRepository(
      client: client,
      storage: storage,
      sessions: const [
        AuthSession(
          userId: 'customer-a@example.com',
          capabilities: AuthCapabilities(
            accessState: AccountAccessState.approved,
            canViewCustomerDashboard: true,
          ),
        ),
      ],
    );
    final logoutCompleter = Completer<void>();
    authRepository.logoutCompleter = logoutCompleter;
    authRepository.logoutFailure = StateError('secure storage unavailable');
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        deviceLockServiceProvider.overrideWithValue(
          DeviceLockService(
            authentication: LocalAuthentication(),
            storage: storage,
          ),
        ),
        frappeClientProvider.overrideWithValue(client),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(authControllerProvider.notifier);
    await controller.login(email: 'customer-a@example.com', password: 'ok');
    final previousEpoch = container.read(sessionEpochProvider);

    final logout = controller.logout();
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(authControllerProvider).status,
      AuthStatus.unauthenticated,
    );
    expect(container.read(sessionEpochProvider), previousEpoch);

    logoutCompleter.complete();
    await expectLater(logout, throwsStateError);
    expect(container.read(sessionEpochProvider), previousEpoch + 1);
  });

  test('expiry stays fail-closed when local cleanup fails', () async {
    final client = _SessionAwareFrappeClient();
    final storage = _MemorySecureStorageService();
    final authRepository = _TransitionAuthRepository(
      client: client,
      storage: storage,
      sessions: const [
        AuthSession(
          userId: 'customer-a@example.com',
          capabilities: AuthCapabilities(
            accessState: AccountAccessState.approved,
            canViewCustomerDashboard: true,
          ),
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(authRepository),
        deviceLockServiceProvider.overrideWithValue(
          DeviceLockService(
            authentication: LocalAuthentication(),
            storage: storage,
          ),
        ),
        frappeClientProvider.overrideWithValue(client),
      ],
    );
    addTearDown(container.dispose);

    final controller = container.read(authControllerProvider.notifier);
    await controller.login(email: 'customer-a@example.com', password: 'ok');
    final previousEpoch = container.read(sessionEpochProvider);
    authRepository.clearFailure = StateError('secure storage unavailable');

    container.read(sessionExpirySignalProvider.notifier).signal();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(
      container.read(authControllerProvider).status,
      AuthStatus.unauthenticated,
    );
    expect(container.read(sessionEpochProvider), previousEpoch + 1);
  });
}

Future<void> _expectSessionData(
  ProviderContainer container, {
  required int activeCases,
  required int unreadSupport,
}) async {
  final dashboard = await container.read(homeDashboardSummaryProvider.future);
  final unread = await container.read(supportUnreadCountProvider.future);
  expect(dashboard.activeCases, activeCases);
  expect(unread, unreadSupport);
}

void _expectNoPriorDashboard(ProviderContainer container, int priorValue) {
  final current = container.read(homeDashboardSummaryProvider).value;
  expect(current?.activeCases, isNot(priorValue));
}

class _TransitionAuthRepository extends AuthRepository {
  _TransitionAuthRepository({
    required this.client,
    required SecureStorageService storage,
    required this.sessions,
  }) : super(frappeClient: client, secureStorageService: storage, isWeb: false);

  final _SessionAwareFrappeClient client;
  final List<AuthSession> sessions;
  final List<String> transitionCalls = [];
  Completer<void>? logoutCompleter;
  Object? logoutFailure;
  Object? clearFailure;
  int _sessionIndex = 0;

  @override
  Future<AuthSession> loginWithPassword({
    required String email,
    required String password,
  }) async {
    final session = sessions[_sessionIndex++];
    client.identity = session.userId;
    transitionCalls.add('login:${session.userId}');
    return session;
  }

  @override
  Future<void> logout() async {
    client.identity = 'Guest';
    transitionCalls.add('logout');
    await logoutCompleter?.future;
    final failure = logoutFailure;
    if (failure != null) throw failure;
  }

  @override
  Future<void> clearSession() async {
    client.identity = 'Guest';
    transitionCalls.add('clear');
    final failure = clearFailure;
    if (failure != null) throw failure;
  }

  @override
  Future<void> createGuestSession() async {
    client.identity = 'Guest';
    transitionCalls.add('guest');
  }
}

class _SessionAwareFrappeClient extends FrappeClient {
  _SessionAwareFrappeClient()
    : super(
        DioClient(
          secureStorageService: _MemorySecureStorageService(),
          dio: Dio(BaseOptions(baseUrl: 'https://erp.omchouse.com')),
        ),
      );

  String identity = 'Guest';
  int supportConfigReads = 0;
  int supportUnreadReads = 0;
  Completer<Map<String, dynamic>>? delayedUnreadResponse;

  int get _identityIndex => switch (identity.toLowerCase()) {
    'customer-a@example.com' => 1,
    'customer-b@example.com' => 2,
    'staff-a@example.com' => 3,
    'staff-b@example.com' => 4,
    _ => 0,
  };

  @override
  Future<Map<String, dynamic>> getMethod(
    String method, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    if (method == ApiConfig.dashboardDataMethod) {
      return {
        'message': {'active_cases': _identityIndex * 11},
      };
    }
    if (method == ApiConfig.supportUnreadCountMethod) {
      supportUnreadReads++;
      final delayed = delayedUnreadResponse;
      if (delayed != null) {
        delayedUnreadResponse = null;
        return delayed.future;
      }
      return {
        'message': {'count': _identityIndex * 101},
      };
    }
    if (method == ApiConfig.supportConfigMethod) {
      supportConfigReads++;
      return const {
        'message': {
          'channels': [
            {
              'channel_type': 'email',
              'label': 'Email',
              'value': 'support@example.com',
            },
          ],
        },
      };
    }
    return const {'message': {}};
  }
}

class _MemorySecureStorageService extends SecureStorageService {
  @override
  Future<String?> readSessionCookie() async => null;

  @override
  Future<String?> readApiKey() async => null;

  @override
  Future<String?> readApiSecret() async => null;
}
