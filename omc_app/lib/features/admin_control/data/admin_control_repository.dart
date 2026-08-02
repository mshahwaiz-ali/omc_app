import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/frappe_client.dart';

final adminControlRepositoryProvider = Provider<AdminControlRepository>((ref) {
  return AdminControlRepository(ref.watch(frappeClientProvider));
});

final adminOverviewProvider = FutureProvider<AdminOverview>((ref) {
  return ref.watch(adminControlRepositoryProvider).fetchOverview();
});

final adminBusinessSettingsProvider = FutureProvider<Map<String, dynamic>>((
  ref,
) {
  return ref.watch(adminControlRepositoryProvider).fetchBusinessSettings();
});

class AdminControlRepository {
  const AdminControlRepository(this._client);

  final FrappeClient _client;

  Future<AdminOverview> fetchOverview() async {
    final response = await _client.getMethod(ApiConfig.adminOverviewMethod);
    return AdminOverview.fromJson(_payload(response));
  }

  Future<Map<String, dynamic>> fetchBusinessSettings() async {
    final response = await _client.getMethod(ApiConfig.businessSettingsMethod);
    return _payload(response);
  }

  Future<void> reviewRegistration({
    required String profileId,
    required bool approve,
    List<String> roles = const [],
    String? reason,
  }) async {
    await _client.postMethod(
      ApiConfig.reviewRegistrationMethod,
      data: {
        'profile_id': profileId,
        'decision': approve ? 'approve' : 'reject',
        if (roles.isNotEmpty) 'roles': roles,
        if (reason?.trim().isNotEmpty ?? false) 'reason': reason!.trim(),
      },
    );
  }

  Future<void> inviteStaff({
    required String fullName,
    required String email,
    required List<String> roles,
  }) async {
    await _client.postMethod(
      ApiConfig.inviteStaffMethod,
      data: {'full_name': fullName, 'email': email, 'roles': roles},
    );
  }

  Future<void> updateStaff({
    required AdminStaff staff,
    required bool enabled,
    required List<String> roles,
  }) async {
    await _client.postMethod(
      ApiConfig.updateStaffAccountMethod,
      data: {
        'user_id': staff.userId,
        'roles': roles,
        'enabled': enabled ? 1 : 0,
      },
    );
  }

  Future<void> updateBusinessSettings(Map<String, dynamic> settings) async {
    await _client.postMethod(
      ApiConfig.updateBusinessSettingsMethod,
      data: {'settings': settings},
    );
  }

  Future<Map<String, dynamic>> fetchCaseOptions(String caseId) async {
    final response = await _client.getMethod(
      ApiConfig.caseAdminOptionsMethod,
      queryParameters: {'service_request': caseId},
    );
    return _payload(response);
  }

  Future<void> reassignCase(String caseId, String userId) async {
    await _client.postMethod(
      ApiConfig.reassignServiceRequestMethod,
      data: {'service_request': caseId, 'assigned_staff': userId},
    );
  }

  Future<void> retrySync(String caseId) async {
    await _client.postMethod(
      ApiConfig.retryServiceSyncMethod,
      data: {'service_request': caseId},
    );
  }

  Future<void> reviewDiscount(String caseId, {required bool approve}) async {
    await _client.postMethod(
      ApiConfig.reviewDiscountMethod,
      data: {
        'service_request': caseId,
        'decision': approve ? 'approve' : 'reject',
      },
    );
  }

  Map<String, dynamic> _payload(Map<String, dynamic> response) {
    final message = response['message'];
    return message is Map<String, dynamic> ? message : response;
  }
}

class AdminOverview {
  const AdminOverview({
    required this.applications,
    required this.staff,
    required this.availableRoles,
  });

  final List<AdminApplication> applications;
  final List<AdminStaff> staff;
  final List<String> availableRoles;

  factory AdminOverview.fromJson(Map<String, dynamic> json) {
    return AdminOverview(
      applications: (json['applications'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AdminApplication.fromJson)
          .toList(growable: false),
      staff: (json['staff'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AdminStaff.fromJson)
          .toList(growable: false),
      availableRoles: (json['available_roles'] as List? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
    );
  }
}

class AdminApplication {
  const AdminApplication({
    required this.profileId,
    required this.fullName,
    required this.email,
    required this.applicationType,
    required this.requestedRole,
  });

  final String profileId;
  final String fullName;
  final String email;
  final String applicationType;
  final String requestedRole;

  factory AdminApplication.fromJson(Map<String, dynamic> json) {
    return AdminApplication(
      profileId: json['name']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      applicationType: json['application_type']?.toString() ?? 'customer',
      requestedRole: json['requested_role']?.toString() ?? '',
    );
  }
}

class AdminStaff {
  const AdminStaff({
    required this.userId,
    required this.fullName,
    required this.enabled,
    required this.roles,
  });

  final String userId;
  final String fullName;
  final bool enabled;
  final List<String> roles;

  factory AdminStaff.fromJson(Map<String, dynamic> json) {
    return AdminStaff(
      userId: json['user_id']?.toString() ?? '',
      fullName: json['full_name']?.toString() ?? '',
      enabled: json['enabled'] == true || json['enabled'] == 1,
      roles: (json['roles'] as List? ?? const [])
          .map((value) => value.toString())
          .toList(growable: false),
    );
  }
}
