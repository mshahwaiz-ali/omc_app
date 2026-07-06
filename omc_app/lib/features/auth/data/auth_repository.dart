import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/config/env.dart';
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

    if (Env.useMockAuth) {
      return AuthSession(userId: userId);
    }

    final serverUserId = await getSessionUser();
    if (serverUserId == null || serverUserId.isEmpty) {
      await clearSession();
      return null;
    }

    return AuthSession(userId: serverUserId);
  }

  Future<String?> getSessionUser() async {
    final response = await _frappeClient.getMethod(
      ApiConfig.getSessionUserMethod,
    );

    final message = response['message'];
    final data = message is Map<String, dynamic> ? message : response;
    final profile = data['profile'];

    final user =
        data['user'] ??
        data['user_id'] ??
        data['email'] ??
        data['name'] ??
        (profile is Map<String, dynamic> ? profile['email'] : null) ??
        (profile is Map<String, dynamic> ? profile['user_id'] : null);

    final text = user?.toString().trim();
    if (text == null || text.isEmpty) return null;

    await _secureStorageService.saveUserId(text);
    return text;
  }

  Future<AuthSession> loginWithPassword({
    required String email,
    required String password,
  }) async {
    if (Env.useMockAuth) {
      // Local testing bypass only.
      // Keep real Frappe login below for staging/production.
      final normalizedEmail = email.trim().isEmpty
          ? 'local.tester@omc.local'
          : email.trim();

      await _secureStorageService.saveSessionCookie('mock-local-session');
      await _secureStorageService.saveUserId(normalizedEmail);

      return AuthSession(userId: normalizedEmail);
    }

    await clearSession();

    final result = await _frappeClient.loginWithPassword(
      email: email,
      password: password,
    );

    final sessionCookie = result.sessionCookie;

    if (sessionCookie == null || sessionCookie.isEmpty) {
      if (!kIsWeb) {
        throw ApiError(
          message: 'Login succeeded but the server did not return a session.',
          details: result.data,
        );
      }

      // On Flutter Web, browsers do not expose Set-Cookie to Dart.
      // If the Frappe login call reached this point without throwing, login was
      // accepted and the browser owns the session cookie.
      await _secureStorageService.saveSessionCookie('browser-managed-session');
      await _secureStorageService.saveUserId(email);

      return AuthSession(userId: email);
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
