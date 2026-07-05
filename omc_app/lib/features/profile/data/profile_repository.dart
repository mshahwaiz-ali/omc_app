import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/frappe_client.dart';
import '../../auth/application/auth_controller.dart';
import 'profile_summary.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final frappeClient = ref.watch(frappeClientProvider);

  return ProfileRepository(frappeClient: frappeClient);
});

final profileSummaryProvider = FutureProvider<ProfileSummary?>((ref) async {
  final repository = ref.watch(profileRepositoryProvider);
  final authState = ref.watch(authControllerProvider);

  return repository.fetchProfile(fallbackUserId: authState.userId);
});

class ProfileRepository {
  const ProfileRepository({required this._frappeClient});

  final FrappeClient _frappeClient;

  Future<ProfileSummary?> fetchProfile({
    required String? fallbackUserId,
  }) async {
    final response = await _frappeClient.getMethod(ApiConfig.profileMethod);
    return _mapProfileResponse(response, fallbackUserId: fallbackUserId);
  }

  Future<bool> requestProfileUpdate(Map<String, dynamic> payload) async {
    if (payload.isEmpty) return false;

    try {
      await _frappeClient.postMethod(
        ApiConfig.updateProfileMethod,
        data: payload,
      );

      return true;
    } on ApiError {
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestContactUpdate(Map<String, dynamic> payload) async {
    if (payload.isEmpty) return false;

    try {
      await _frappeClient.postMethod(
        ApiConfig.updateContactMethod,
        data: payload,
      );

      return true;
    } on ApiError {
      return false;
    } catch (_) {
      return false;
    }
  }

  ProfileSummary? _mapProfileResponse(
    Map<String, dynamic>? data, {
    required String? fallbackUserId,
  }) {
    if (data == null) return null;

    final message = data['message'];
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
      status: _nullableString(profile['status']) ?? fallback.status,
    );
  }

  String? _nullableString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }
}
