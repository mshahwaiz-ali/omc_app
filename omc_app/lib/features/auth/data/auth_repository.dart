import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/frappe_client.dart';
import '../../../core/storage/secure_storage_service.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    frappeClient: ref.watch(frappeClientProvider),
    secureStorageService: ref.watch(secureStorageServiceProvider),
  );
});

class AuthSession {
  const AuthSession({required this.userId});

  final String userId;
}

class AuthRepository {
  const AuthRepository({
    required FrappeClient frappeClient,
    required SecureStorageService secureStorageService,
  }) : this._(frappeClient, secureStorageService);

  const AuthRepository._(this._frappeClient, this._secureStorageService);

  final FrappeClient _frappeClient;
  final SecureStorageService _secureStorageService;

  Future<AuthSession?> readStoredSession() async {
    final userId = await _secureStorageService.readUserId();
    final sessionCookie = await _secureStorageService.readSessionCookie();
    final apiKey = await _secureStorageService.readApiKey();
    final apiSecret = await _secureStorageService.readApiSecret();

    final hasCookie = sessionCookie != null && sessionCookie.isNotEmpty;
    final hasToken =
        apiKey != null &&
        apiKey.isNotEmpty &&
        apiSecret != null &&
        apiSecret.isNotEmpty;

    if (userId == null || userId.isEmpty || (!hasCookie && !hasToken)) {
      return null;
    }

    return AuthSession(userId: userId);
  }

  Future<AuthSession> loginWithPassword({
    required String email,
    required String password,
  }) async {
    final result = await _frappeClient.loginWithPassword(
      email: email,
      password: password,
    );

    final sessionCookie = result.sessionCookie;

    if (sessionCookie == null || sessionCookie.isEmpty) {
      throw ApiError(
        message: 'Login succeeded but the server did not return a session.',
        details: result.data,
      );
    }

    await _secureStorageService.saveSessionCookie(sessionCookie);
    await _secureStorageService.saveUserId(email);

    return AuthSession(userId: email);
  }

  Future<Map<String, dynamic>> loginWithGoogleToken({required String idToken}) {
    return _frappeClient.postMethod(
      ApiConfig.googleLoginMethod,
      data: {'id_token': idToken},
    );
  }

  Future<Map<String, dynamic>> signUp({required Map<String, dynamic> data}) {
    return _frappeClient.postMethod(ApiConfig.signUpMethod, data: data);
  }

  Future<void> clearSession() {
    return _secureStorageService.clearSession();
  }
}
