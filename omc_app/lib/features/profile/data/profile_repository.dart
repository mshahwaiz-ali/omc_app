import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/frappe_client.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import 'profile_summary.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final frappeClient = ref.watch(frappeClientProvider);

  return ProfileRepository(frappeClient: frappeClient);
});

final profileSummaryProvider = FutureProvider<ProfileSummary?>((ref) async {
  final authState = ref.watch(authControllerProvider);
  if (authState.status != AuthStatus.authenticated) return null;

  final repository = ref.watch(profileRepositoryProvider);
  final profile = await repository.fetchProfile(
    fallbackUserId: authState.userId,
  );
  if (profile != null) {
    ref
        .read(authControllerProvider.notifier)
        .syncProfileSummary(
          displayName: profile.displayName,
          email: profile.email,
          phone: profile.phone,
          companyName: profile.companyName,
          customerStatus: profile.status,
          approvalStatus: profile.approvalStatus,
          avatarUrl: profile.avatarUrl,
          canAccessInternalWorkspace: profile.canAccessInternalWorkspace,
          capabilities: profile.capabilities,
        );
  }

  return profile;
});

class ProfileRepository {
  const ProfileRepository({required this._frappeClient});

  final FrappeClient _frappeClient;

  Future<ProfileSummary?> fetchProfile({
    required String? fallbackUserId,
  }) async {
    try {
      final response = await _frappeClient.getMethod(ApiConfig.profileMethod);
      return _mapProfileResponse(response, fallbackUserId: fallbackUserId) ??
          ProfileSummary.fromUserId(fallbackUserId);
    } on ApiError {
      rethrow;
    } catch (error) {
      throw ApiError(
        message:
            'Full customer profile could not be loaded from the server right now.',
        code: 'profile_unavailable',
        details: error,
      );
    }
  }

  Future<String?> uploadProfileImage({
    String? filePath,
    Uint8List? fileBytes,
    required String fileName,
  }) async {
    final resolvedBytes = fileBytes ?? await _readFileBytes(filePath);

    if ((resolvedBytes == null || resolvedBytes.isEmpty) &&
        (filePath == null || filePath.trim().isEmpty)) {
      throw ApiError(
        message:
            'Selected profile photo could not be read. Please choose it again.',
        code: 'profile_image_unavailable',
      );
    }

    final response = await _frappeClient.uploadFile(
      filePath: resolvedBytes == null ? filePath : null,
      fileBytes: resolvedBytes,
      fileName: fileName,
      method: ApiConfig.uploadProfileImageMethod,
      isPrivate: false,
    );

    final message = response['message'];
    final payload = message is Map<String, dynamic> ? message : response;
    final uploadedUrl = _userImageUrlFromPayload(payload);
    return uploadedUrl == null ? null : _withAvatarCacheBust(uploadedUrl);
  }

  Future<Uint8List?> _readFileBytes(String? filePath) async {
    final cleanPath = filePath?.trim();
    if (cleanPath == null || cleanPath.isEmpty) return null;

    try {
      return await XFile(cleanPath).readAsBytes();
    } catch (_) {
      return null;
    }
  }

  Future<bool> requestProfileUpdate(Map<String, dynamic> payload) async {
    if (payload.isEmpty) return false;

    await _frappeClient.postMethod(
      ApiConfig.updateProfileMethod,
      data: payload,
    );

    return true;
  }

  Future<bool> requestContactUpdate(Map<String, dynamic> payload) async {
    if (payload.isEmpty) return false;

    await _frappeClient.postMethod(
      ApiConfig.updateContactMethod,
      data: payload,
    );

    return true;
  }

  ProfileSummary? _mapProfileResponse(
    Map<String, dynamic>? data, {
    required String? fallbackUserId,
  }) {
    if (data == null) return null;

    final message = data['message'];
    final envelope = message is Map<String, dynamic> ? message : data;
    final profile = message is Map<String, dynamic>
        ? message['profile'] ??
              message['data'] ??
              message['customer'] ??
              message
        : data['profile'] ?? data['data'] ?? data['customer'] ?? data;

    if (profile is! Map<String, dynamic>) return null;

    final fallback = ProfileSummary.fromUserId(fallbackUserId);
    final email = _nullableString(
      profile['email'] ?? profile['user_id'] ?? profile['user'],
    );
    final capabilities = _capabilitiesFromResponse(
      envelope: envelope,
      profile: profile,
    );
    final avatarUrl =
        _userImageUrlFromPayload(profile) ?? _userImageUrlFromPayload(envelope);

    return ProfileSummary(
      displayName:
          _nullableString(
            profile['display_name'] ??
                profile['full_name'] ??
                profile['customer_name'] ??
                profile['name'],
          ) ??
          fallback.displayName,
      email: email ?? fallback.email,
      phone: _nullableString(profile['phone'] ?? profile['mobile_no']),
      customerType: _nullableString(
        profile['customer_type'] ?? profile['user_type'],
      ),
      cnic: _nullableString(profile['cnic'] ?? profile['tax_id']),
      ntn: _nullableString(profile['ntn']),
      companyName: _nullableString(
        profile['company_name'] ?? profile['company'],
      ),
      approvalStatus: _nullableString(profile['approval_status']),
      avatarUrl: avatarUrl == null ? null : _withAvatarCacheBust(avatarUrl),
      status:
          _nullableString(profile['customer_status'] ?? profile['status']) ??
          fallback.status,
      canAccessInternalWorkspace:
          capabilities.canAccessInternalWorkspace ||
          _boolValue(
            profile['can_access_internal_workspace'] ??
                profile['canAccessInternalWorkspace'] ??
                envelope['can_access_internal_workspace'] ??
                envelope['canAccessInternalWorkspace'],
          ),
      capabilities: capabilities,
    );
  }

  String? _userImageUrlFromPayload(Map<String, dynamic> payload) {
    return _nullableString(
      payload['user_image'] ?? payload['avatar_url'] ?? payload['file_url'],
    );
  }

  String _withAvatarCacheBust(String value) {
    final cleanValue = value.trim();
    if (cleanValue.isEmpty) return cleanValue;
    final separator = cleanValue.contains('?') ? '&' : '?';
    return '$cleanValue${separator}avatar_ts=${DateTime.now().millisecondsSinceEpoch}';
  }

  AuthCapabilities _capabilitiesFromResponse({
    required Map<String, dynamic> envelope,
    required Map<String, dynamic> profile,
  }) {
    final profileCapabilities = profile['capabilities'];
    if (profileCapabilities is Map<String, dynamic>) {
      return AuthCapabilities.fromJson(profileCapabilities);
    }

    final envelopeCapabilities = envelope['capabilities'];
    if (envelopeCapabilities is Map<String, dynamic>) {
      return AuthCapabilities.fromJson(envelopeCapabilities);
    }

    return AuthCapabilities.fromJson({...envelope, ...profile});
  }

  bool _boolValue(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;

    final text = value?.toString().trim().toLowerCase();
    return text == 'true' || text == '1' || text == 'yes';
  }

  String? _nullableString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }
}
