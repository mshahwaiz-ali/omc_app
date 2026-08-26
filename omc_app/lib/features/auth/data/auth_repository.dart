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
    bool isWeb = kIsWeb,
  }) : this._(frappeClient, secureStorageService, isWeb);

  const AuthRepository._(
    this._frappeClient,
    this._secureStorageService,
    this._isWeb,
  );

  static const _registrationVerificationStatusMethod =
      'omc_app.api.pending_registration.get_registration_verification_status';
  static const _completeRegistrationMethod =
      'omc_app.api.pending_registration.complete_registration';

  final FrappeClient _frappeClient;
  final SecureStorageService _secureStorageService;
  final bool _isWeb;

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
    final isGuest =
        text == null ||
        text.isEmpty ||
        text.toLowerCase() == 'guest' ||
        data['is_guest'] == true ||
        data['access_state']?.toString().trim().toLowerCase() == 'guest';

    if (isGuest) return null;

    final capabilities = _capabilitiesFromResponse(data);

    await _secureStorageService.saveUserId(text);
    return AuthSession(
      userId: text,
      canAccessInternalWorkspace: capabilities.canAccessInternalWorkspace,
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
      if (!_isWeb) {
        throw ApiError(
          message: 'Login succeeded but the server did not return a session.',
          details: result.data,
        );
      }

      // On Flutter Web, browsers do not expose Set-Cookie to Dart.
      // If the Frappe login call reached this point without throwing, login was
      // accepted and the browser owns the session cookie.
      await _secureStorageService.saveSessionCookie('browser-managed-session');
    } else {
      await _secureStorageService.saveSessionCookie(sessionCookie);
    }

    try {
      final serverSession = await _getSessionAfterAcceptedLogin(result.data);
      if (serverSession == null) {
        throw const ApiError(
          message:
              'Login could not verify an authenticated server session. Please sign in again.',
        );
      }

      await updateGuestActivity(convertedUser: serverSession.userId);
      return serverSession;
    } catch (_) {
      await clearSession();
      rethrow;
    }
  }

  AuthCapabilities _capabilitiesFromResponse(Map<String, dynamic> data) {
    final capabilities = data['capabilities'];
    if (capabilities is Map<String, dynamic>) {
      return AuthCapabilities.fromJson(capabilities);
    }

    return AuthCapabilities.fromJson(data);
  }

  Future<AuthSession?> _getSessionAfterAcceptedLogin(
    Map<String, dynamic> loginData,
  ) async {
    try {
      return await getSessionUser();
    } on ApiError catch (error) {
      throw ApiError(
        message:
            'Login succeeded, but the app could not verify the server session. Rerun the local dev script so Flutter and Frappe use the same host.',
        details: {'login': loginData, 'session_error': error.details},
      );
    }
  }

  Future<Map<String, dynamic>> loginWithGoogleToken({required String idToken}) {
    return _frappeClient.postMethod(
      ApiConfig.googleLoginMethod,
      data: {'id_token': idToken},
    );
  }

  Future<Map<String, dynamic>> signUp({required Map<String, dynamic> data}) {
    final publicData = Map<String, dynamic>.from(data)
      ..remove('password')
      ..remove('new_password')
      ..remove('confirm_password');
    return _frappeClient.postMethod(
      ApiConfig.startRegistrationMethod,
      data: publicData,
    );
  }

  Future<Map<String, dynamic>> resendVerification({required String email}) {
    return _frappeClient.postMethod(
      ApiConfig.resendVerificationMethod,
      data: {'email': email.trim()},
    );
  }

  Future<Map<String, dynamic>> getRegistrationVerificationStatus({
    required String token,
  }) {
    return _frappeClient.getMethod(
      _registrationVerificationStatusMethod,
      queryParameters: {'token': token.trim()},
    );
  }

  Future<Map<String, dynamic>> completeRegistration({
    required String token,
    required String password,
  }) {
    return _frappeClient.postMethod(
      _completeRegistrationMethod,
      data: {'token': token.trim(), 'password': password},
    );
  }

  @Deprecated('Use getRegistrationVerificationStatus instead.')
  Future<Map<String, dynamic>> verifyRegistration({required String token}) {
    return getRegistrationVerificationStatus(token: token);
  }

  Future<Map<String, dynamic>> suggestUsername({
    required String fullName,
    required String email,
  }) {
    return _frappeClient.getMethod(
      ApiConfig.suggestUsernameMethod,
      queryParameters: {'full_name': fullName, 'email': email},
    );
  }

  Future<Map<String, dynamic>> checkUsernameAvailability({
    required String username,
  }) {
    return _frappeClient.getMethod(
      ApiConfig.checkUsernameAvailabilityMethod,
      queryParameters: {'username': username},
    );
  }

  Future<Map<String, dynamic>> validateReferralCode({
    required String referralCode,
  }) {
    return _frappeClient.getMethod(
      ApiConfig.validateReferralCodeMethod,
      queryParameters: {'referral_code': referralCode},
    );
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

  Future<void> verifyCurrentPassword({required String currentPassword}) async {
    await _frappeClient.postMethod(
      ApiConfig.verifyCurrentPasswordMethod,
      data: {'current_password': currentPassword},
    );
  }

  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final response = await _frappeClient.postMethod(
      ApiConfig.changePasswordMethod,
      data: {
        'current_password': currentPassword,
        'new_password': newPassword,
        'confirm_password': confirmPassword,
      },
    );
    await _secureStorageService.clearBiometricLogin();
    return response;
  }

  Future<Map<String, dynamic>> requestCustomerActivation({
    required String email,
  }) {
    return _frappeClient.postMethod(
      ApiConfig.requestCustomerActivationMethod,
      data: {'email': email.trim()},
    );
  }

  Future<Map<String, dynamic>> completeCustomerActivation({
    required String token,
    required String password,
    required String confirmPassword,
  }) async {
    final response = await _frappeClient.postMethod(
      ApiConfig.completeCustomerActivationMethod,
      data: {
        'token': token.trim(),
        'password': password,
        'confirm_password': confirmPassword,
      },
    );

    await _secureStorageService.clearBiometricLogin();
    return response;
  }

  Future<Map<String, dynamic>> requestPasswordReset({
    required String identifier,
  }) {
    return _frappeClient.postMethod(
      ApiConfig.requestPasswordResetMethod,
      data: {'identifier': identifier.trim()},
    );
  }

  Future<Map<String, dynamic>> resetPassword({
    required String token,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final response = await _frappeClient.postMethod(
      ApiConfig.resetPasswordMethod,
      data: {
        'token': token,
        'new_password': newPassword,
        'confirm_password': confirmPassword,
      },
    );
    await _secureStorageService.clearBiometricLogin();
    return response;
  }
}
