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

final adminOperationsProvider =
    FutureProvider.family<AdminOperationsPage, AdminOperationsQuery>((
      ref,
      query,
    ) {
      return ref.watch(adminControlRepositoryProvider).fetchOperations(query);
    });

final adminCaseOptionsProvider =
    FutureProvider.family<AdminCaseOptions, String>((ref, caseId) {
      return ref.watch(adminControlRepositoryProvider).fetchCaseOptions(caseId);
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

  Future<AdminOperationsPage> fetchOperations(
    AdminOperationsQuery query,
  ) async {
    final response = await _client.getMethod(
      ApiConfig.adminOperationsMethod,
      queryParameters: {
        'queue': query.queue.apiValue,
        'limit_start': query.start,
        'limit_page_length': query.pageLength,
        if (query.search.trim().isNotEmpty) 'search': query.search.trim(),
      },
    );
    return AdminOperationsPage.fromJson(_payload(response));
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

  Future<AdminCaseOptions> fetchCaseOptions(String caseId) async {
    final response = await _client.getMethod(
      ApiConfig.caseAdminOptionsMethod,
      queryParameters: {'service_request': caseId},
    );
    return AdminCaseOptions.fromJson(_payload(response));
  }

  Future<void> reassignCase(
    String caseId,
    String userId, {
    String? reason,
  }) async {
    await _client.postMethod(
      ApiConfig.reassignServiceRequestMethod,
      data: {
        'service_request': caseId,
        'assigned_staff': userId,
        if (reason?.trim().isNotEmpty ?? false) 'reason': reason!.trim(),
      },
    );
  }

  Future<void> retrySync(String caseId) async {
    await _client.postMethod(
      ApiConfig.retryServiceSyncMethod,
      data: {'service_request': caseId},
    );
  }

  Future<void> reviewDiscount(
    String caseId, {
    required bool approve,
    String? reason,
  }) async {
    await _client.postMethod(
      ApiConfig.reviewDiscountMethod,
      data: {
        'service_request': caseId,
        'decision': approve ? 'approve' : 'reject',
        if (reason?.trim().isNotEmpty ?? false) 'reason': reason!.trim(),
      },
    );
  }

  Map<String, dynamic> _payload(Map<String, dynamic> response) {
    final message = response['message'];
    return message is Map<String, dynamic> ? message : response;
  }
}

enum AdminOperationQueue { reassignment, sync, discount }

extension AdminOperationQueueApi on AdminOperationQueue {
  String get apiValue => name;

  String get label => switch (this) {
    AdminOperationQueue.reassignment => 'Reassignment',
    AdminOperationQueue.sync => 'Sync recovery',
    AdminOperationQueue.discount => 'Discount review',
  };
}

class AdminOperationsQuery {
  const AdminOperationsQuery({
    required this.queue,
    this.search = '',
    this.start = 0,
    this.pageLength = 20,
  });

  final AdminOperationQueue queue;
  final String search;
  final int start;
  final int pageLength;

  @override
  bool operator ==(Object other) =>
      other is AdminOperationsQuery &&
      other.queue == queue &&
      other.search == search &&
      other.start == start &&
      other.pageLength == pageLength;

  @override
  int get hashCode => Object.hash(queue, search, start, pageLength);
}

class AdminOperationsPage {
  const AdminOperationsPage({
    required this.items,
    required this.start,
    required this.pageLength,
    required this.total,
    required this.hasMore,
  });

  final List<AdminOperationItem> items;
  final int start;
  final int pageLength;
  final int total;
  final bool hasMore;

  factory AdminOperationsPage.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(AdminOperationItem.fromJson)
        .toList(growable: false);
    final total = _integer(json['total'], items.length);
    final start = _integer(json['limit_start'], 0);
    return AdminOperationsPage(
      items: items,
      start: start,
      pageLength: _integer(json['limit_page_length'], 20),
      total: total,
      hasMore: _boolean(json['has_more']) || start + items.length < total,
    );
  }
}

class AdminOperationItem {
  const AdminOperationItem({
    required this.id,
    required this.title,
    required this.customer,
    required this.service,
    required this.status,
    required this.assignedStaff,
    required this.syncStatus,
    required this.discountStatus,
    required this.retryCount,
    required this.lastError,
  });

  final String id;
  final String title;
  final String customer;
  final String service;
  final String status;
  final String assignedStaff;
  final String syncStatus;
  final String discountStatus;
  final int retryCount;
  final String lastError;

  factory AdminOperationItem.fromJson(Map<String, dynamic> json) =>
      AdminOperationItem(
        id: _textValue(json['name']),
        title: _textValue(json['title']),
        customer: _textValue(json['customer_name'] ?? json['customer_profile']),
        service: _textValue(json['service_title'] ?? json['service']),
        status: _textValue(json['status']),
        assignedStaff: _textValue(json['assigned_staff']),
        syncStatus: _textValue(json['erp_sync_status']),
        discountStatus: _textValue(json['discount_status']),
        retryCount: _integer(json['erp_retry_count'], 0),
        lastError: _textValue(json['erp_sync_error']),
      );
}

class AdminCaseOptions {
  const AdminCaseOptions(this.data);

  final Map<String, dynamic> data;

  factory AdminCaseOptions.fromJson(Map<String, dynamic> json) =>
      AdminCaseOptions(Map.unmodifiable(json));

  String text(String key) => _textValue(data[key]);
  int integer(String key) => _integer(data[key], 0);
  double number(String key) => double.tryParse('${data[key] ?? 0}') ?? 0;

  List<AdminAssignmentCandidate> get candidates =>
      (data['assignment_candidates'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(AdminAssignmentCandidate.fromJson)
          .toList(growable: false);
}

class AdminAssignmentCandidate {
  const AdminAssignmentCandidate({
    required this.userId,
    required this.fullName,
  });

  final String userId;
  final String fullName;

  factory AdminAssignmentCandidate.fromJson(Map<String, dynamic> json) =>
      AdminAssignmentCandidate(
        userId: _textValue(json['user_id']),
        fullName: _textValue(json['full_name']),
      );
}

String _textValue(Object? value) => value?.toString().trim() ?? '';

int _integer(Object? value, int fallback) =>
    value is int ? value : int.tryParse('${value ?? ''}') ?? fallback;

bool _boolean(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return {'1', 'true', 'yes'}.contains(value?.toString().toLowerCase());
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
