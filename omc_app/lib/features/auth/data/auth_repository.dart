import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/frappe_client.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../application/auth_state.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    frappeClient: ref.watch(frappeClientProvider),
    secureStorageService: ref.watch(secureStorageServiceProvider),
  );
});

class AuthSession {
  const AuthSession({
    required this.userId,
    this.canAccessInternalWorkspace = false,
    this.capabilities = AuthCapabilities.guest,
  });

  final String userId;
  final bool canAccessInternalWorkspace;
  final AuthCapabilities capabilities;
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

    final serverSession = await getSessionUser();
    if (serverSession == null || serverSession.userId.isEmpty) {
      await clearSession();
      return null;
    }

    return serverSession;
  }

  Future<AuthSession?> getSessionUser() async {
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

    final rolesValue = data['roles'];
    final roles = rolesValue is List
        ? rolesValue.map((role) => role.toString().trim()).toSet()
        : <String>{};

    final capabilities = _capabilitiesFromResponse(data);
    final canAccessInternalWorkspace =
        capabilities.canAccessInternalWorkspace ||
        data['can_access_internal_workspace'] == true ||
        data['canAccessInternalWorkspace'] == true ||
        roles.contains('System Manager');

    await _secureStorageService.saveUserId(text);
    return AuthSession(
      userId: text,
      canAccessInternalWorkspace: canAccessInternalWorkspace,
      capabilities: capabilities,
    );
  }

  Future<AuthSession> loginWithPassword({
    required String email,
    required String password,
  }) async {
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

      final serverSession = await getSessionUser();
      if (serverSession != null) {
        await updateGuestActivity(convertedUser: serverSession.userId);
        return serverSession;
      }

      await _secureStorageService.saveUserId(email);
      await updateGuestActivity(convertedUser: email);
      return AuthSession(userId: email);
    }

    await _secureStorageService.saveSessionCookie(sessionCookie);

    final serverSession = await getSessionUser();
    if (serverSession != null) {
      await updateGuestActivity(convertedUser: serverSession.userId);
      return serverSession;
    }

    await _secureStorageService.saveUserId(email);
    await updateGuestActivity(convertedUser: email);
    return AuthSession(userId: email);
  }

  AuthCapabilities _capabilitiesFromResponse(Map<String, dynamic> data) {
    final capabilities = data['capabilities'];
    if (capabilities is Map<String, dynamic>) {
      return AuthCapabilities.fromJson(capabilities);
    }

    return AuthCapabilities.fromJson(data);
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

  Future<void> createGuestSession() async {
    try {
      final deviceId = await _guestDeviceId();
      final response = await _frappeClient.postMethod(
        ApiConfig.createGuestSessionMethod,
        data: {
          'device_id': deviceId,
          'platform': _platformName,
          'app_version': 'unknown',
        },
      );
      await _storeGuestSessionId(response);
    } catch (_) {
      // Guest mode must stay usable even when analytics/session tracking fails.
    }
  }

  Future<void> updateGuestActivity({
    String? interestedService,
    String? convertedUser,
  }) async {
    try {
      final deviceId = await _guestDeviceId();
      final sessionId = await _secureStorageService.readGuestSessionId();
      final data = <String, dynamic>{
        'device_id': deviceId,
        'platform': _platformName,
        'app_version': 'unknown',
      };

      if (sessionId != null && sessionId.isNotEmpty) {
        data['session_id'] = sessionId;
      }
      if (interestedService != null && interestedService.trim().isNotEmpty) {
        data['interested_services'] = [interestedService.trim()];
      }
      if (convertedUser != null && convertedUser.trim().isNotEmpty) {
        data['converted_user'] = convertedUser.trim();
      }

      final response = await _frappeClient.postMethod(
        ApiConfig.updateGuestActivityMethod,
        data: data,
      );
      await _storeGuestSessionId(response);
    } catch (_) {
      // Non-blocking by design.
    }
  }

  Future<void> logout() async {
    try {
      await _frappeClient.postMethod(ApiConfig.logoutMethod);
    } catch (_) {
      // Local session cleanup must still happen even if the backend session is already expired.
    }

    await _secureStorageService.clearSession();
  }

  Future<void> clearSession() {
    return _secureStorageService.clearSession();
  }

  Future<String> _guestDeviceId() async {
    final existing = await _secureStorageService.readGuestDeviceId();
    if (existing != null && existing.isNotEmpty) return existing;

    final random = Random.secure();
    final suffix = List.generate(
      16,
      (_) => random.nextInt(16).toRadixString(16),
    ).join();
    final deviceId = 'guest-${DateTime.now().millisecondsSinceEpoch}-$suffix';
    await _secureStorageService.saveGuestDeviceId(deviceId);
    return deviceId;
  }

  Future<void> _storeGuestSessionId(Map<String, dynamic> response) async {
    final message = response['message'];
    final data = message is Map<String, dynamic> ? message : response;
    final guestSession = data['guest_session'];
    final sessionId = guestSession is Map<String, dynamic>
        ? (guestSession['session_id'] ?? guestSession['name'])?.toString()
        : null;
    if (sessionId != null && sessionId.isNotEmpty) {
      await _secureStorageService.saveGuestSessionId(sessionId);
    }
  }

  String get _platformName {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name.toLowerCase();
  }
}
