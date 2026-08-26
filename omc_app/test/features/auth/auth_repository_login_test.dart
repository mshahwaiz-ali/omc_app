import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/core/config/api_config.dart';
import 'package:omc_app/core/network/api_error.dart';
import 'package:omc_app/core/network/dio_client.dart';
import 'package:omc_app/core/network/frappe_client.dart';
import 'package:omc_app/core/storage/secure_storage_service.dart';
import 'package:omc_app/features/auth/application/auth_state.dart';
import 'package:omc_app/features/auth/data/auth_repository.dart';

void main() {
  group('AuthRepository.loginWithPassword', () {
    test('accepts a canonical authenticated customer session', () async {
      final storage = _MemorySecureStorageService();
      final client = _FakeFrappeClient(
        loginResult: const FrappeLoginResult(
          data: {'message': 'Logged In'},
          sessionCookie: 'sid=customer-session',
        ),
        sessionResponse: _sessionResponse(
          user: 'customer@example.com',
          accessState: 'approved',
          capabilities: const {'can_create_service_request': true},
        ),
      );
      final repository = AuthRepository(
        frappeClient: client,
        secureStorageService: storage,
        isWeb: false,
      );

      final session = await repository.loginWithPassword(
        email: 'customer@example.com',
        password: 'correct-password',
      );

      expect(session.userId, 'customer@example.com');
      expect(session.capabilities.accessState, AccountAccessState.approved);
      expect(session.capabilities.canCreateServiceRequest, isTrue);
      expect(storage.sessionCookie, 'sid=customer-session');
      expect(storage.userId, 'customer@example.com');
      expect(client.convertedUsers, ['customer@example.com']);
    });

    test(
      'accepts canonical internal capabilities without a customer',
      () async {
        final storage = _MemorySecureStorageService();
        final client = _FakeFrappeClient(
          loginResult: const FrappeLoginResult(
            data: {'message': 'Logged In'},
            sessionCookie: 'sid=staff-session',
          ),
          sessionResponse: _sessionResponse(
            user: 'staff@example.com',
            accessState: 'internal',
            capabilities: const {
              'can_access_internal_workspace': true,
              'can_view_relevant_service_cases': true,
            },
          ),
        );
        final repository = AuthRepository(
          frappeClient: client,
          secureStorageService: storage,
          isWeb: false,
        );

        final session = await repository.loginWithPassword(
          email: 'staff@example.com',
          password: 'correct-password',
        );

        expect(session.userId, 'staff@example.com');
        expect(session.capabilities.accessState, AccountAccessState.internal);
        expect(session.canAccessInternalWorkspace, isTrue);
        expect(storage.userId, 'staff@example.com');
      },
    );

    test('fails closed when canonical session still reports Guest', () async {
      final storage = _MemorySecureStorageService();
      final client = _FakeFrappeClient(
        loginResult: const FrappeLoginResult(
          data: {'message': 'Logged In'},
          sessionCookie: 'sid=unverified-session',
        ),
        sessionResponse: const {
          'message': {
            'user': 'Guest',
            'is_guest': true,
            'access_state': 'guest',
          },
        },
      );
      final repository = AuthRepository(
        frappeClient: client,
        secureStorageService: storage,
        isWeb: false,
      );

      await expectLater(
        repository.loginWithPassword(
          email: 'submitted@example.com',
          password: 'accepted-but-not-authenticated',
        ),
        throwsA(
          isA<ApiError>().having(
            (error) => error.message,
            'message',
            contains('could not verify'),
          ),
        ),
      );

      expect(storage.sessionCookie, isNull);
      expect(storage.userId, isNull);
      expect(client.convertedUsers, isEmpty);
    });

    test('fails closed when canonical response has no identity', () async {
      final storage = _MemorySecureStorageService();
      final repository = AuthRepository(
        frappeClient: _FakeFrappeClient(
          loginResult: const FrappeLoginResult(
            data: {'message': 'Logged In'},
            sessionCookie: 'sid=unverified-session',
          ),
          sessionResponse: const {
            'message': {'access_state': 'approved'},
          },
        ),
        secureStorageService: storage,
        isWeb: false,
      );

      await expectLater(
        repository.loginWithPassword(
          email: 'submitted@example.com',
          password: 'accepted-but-not-authenticated',
        ),
        throwsA(isA<ApiError>()),
      );

      expect(storage.sessionCookie, isNull);
      expect(storage.userId, isNull);
    });

    test(
      'native login rejects an accepted response without a session',
      () async {
        final storage = _MemorySecureStorageService()
          ..sessionCookie = 'sid=old-session'
          ..userId = 'old@example.com';
        final client = _FakeFrappeClient(
          loginResult: const FrappeLoginResult(data: {'message': 'Logged In'}),
          sessionResponse: _sessionResponse(
            user: 'submitted@example.com',
            accessState: 'approved',
          ),
        );
        final repository = AuthRepository(
          frappeClient: client,
          secureStorageService: storage,
          isWeb: false,
        );

        await expectLater(
          repository.loginWithPassword(
            email: 'submitted@example.com',
            password: 'correct-password',
          ),
          throwsA(
            isA<ApiError>().having(
              (error) => error.message,
              'message',
              contains('did not return a session'),
            ),
          ),
        );

        expect(storage.sessionCookie, isNull);
        expect(storage.userId, isNull);
        expect(client.sessionReads, 0);
      },
    );

    test(
      'web login verifies the browser-managed session canonically',
      () async {
        final storage = _MemorySecureStorageService();
        final client = _FakeFrappeClient(
          loginResult: const FrappeLoginResult(data: {'message': 'Logged In'}),
          sessionResponse: _sessionResponse(
            user: 'web@example.com',
            accessState: 'approved',
          ),
        );
        final repository = AuthRepository(
          frappeClient: client,
          secureStorageService: storage,
          isWeb: true,
        );

        final session = await repository.loginWithPassword(
          email: 'web@example.com',
          password: 'correct-password',
        );

        expect(session.userId, 'web@example.com');
        expect(storage.sessionCookie, 'browser-managed-session');
        expect(storage.userId, 'web@example.com');
        expect(client.sessionReads, 1);
      },
    );

    test(
      'propagates invalid credentials without creating local state',
      () async {
        final storage = _MemorySecureStorageService()
          ..sessionCookie = 'sid=old-session'
          ..userId = 'old@example.com';
        final repository = AuthRepository(
          frappeClient: _FakeFrappeClient(
            loginError: const ApiError(
              message: 'Invalid login credentials.',
              statusCode: 401,
            ),
          ),
          secureStorageService: storage,
          isWeb: false,
        );

        await expectLater(
          repository.loginWithPassword(
            email: 'wrong@example.com',
            password: 'wrong-password',
          ),
          throwsA(
            isA<ApiError>().having(
              (error) => error.statusCode,
              'statusCode',
              401,
            ),
          ),
        );

        expect(storage.sessionCookie, isNull);
        expect(storage.userId, isNull);
      },
    );
  });
}

Map<String, dynamic> _sessionResponse({
  required String user,
  required String accessState,
  Map<String, dynamic> capabilities = const {},
}) {
  return {
    'message': {
      'user': user,
      'access_state': accessState,
      'capabilities': {'access_state': accessState, ...capabilities},
    },
  };
}

class _FakeFrappeClient extends FrappeClient {
  _FakeFrappeClient({
    this.loginResult,
    this.sessionResponse = const {},
    this.loginError,
  }) : super(
         DioClient(
           secureStorageService: _MemorySecureStorageService(),
           dio: Dio(BaseOptions(baseUrl: 'https://erp.omchouse.com')),
         ),
       );

  final FrappeLoginResult? loginResult;
  final Map<String, dynamic> sessionResponse;
  final Object? loginError;
  final List<String> convertedUsers = [];
  int sessionReads = 0;

  @override
  Future<FrappeLoginResult> loginWithPassword({
    required String email,
    required String password,
  }) async {
    if (loginError case final error?) throw error;
    return loginResult!;
  }

  @override
  Future<Map<String, dynamic>> getMethod(
    String method, {
    Map<String, dynamic>? queryParameters,
    CancelToken? cancelToken,
  }) async {
    expect(method, ApiConfig.getSessionUserMethod);
    sessionReads++;
    return sessionResponse;
  }

  @override
  Future<Map<String, dynamic>> postMethod(
    String method, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    String? idempotencyKey,
  }) async {
    if (method == ApiConfig.updateGuestActivityMethod && data is Map) {
      final convertedUser = data['converted_user']?.toString();
      if (convertedUser != null) convertedUsers.add(convertedUser);
    }
    return const {'message': {}};
  }
}

class _MemorySecureStorageService extends SecureStorageService {
  String? sessionCookie;
  String? userId;
  String? apiKey;
  String? apiSecret;
  String? guestDeviceId;
  String? guestSessionId;

  @override
  Future<void> saveSessionCookie(String value) async {
    sessionCookie = value;
  }

  @override
  Future<String?> readSessionCookie() async => sessionCookie;

  @override
  Future<void> saveUserId(String value) async {
    userId = value;
  }

  @override
  Future<String?> readUserId() async => userId;

  @override
  Future<String?> readApiKey() async => apiKey;

  @override
  Future<String?> readApiSecret() async => apiSecret;

  @override
  Future<String?> readGuestDeviceId() async => guestDeviceId;

  @override
  Future<void> saveGuestDeviceId(String value) async {
    guestDeviceId = value;
  }

  @override
  Future<String?> readGuestSessionId() async => guestSessionId;

  @override
  Future<void> saveGuestSessionId(String value) async {
    guestSessionId = value;
  }

  @override
  Future<void> clearSession() async {
    sessionCookie = null;
    userId = null;
    apiKey = null;
    apiSecret = null;
  }
}
