import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/frappe_client.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import 'referral_detail.dart';
import 'referral_summary.dart';

final referralRepositoryProvider = Provider<ReferralRepository>((ref) {
  return ReferralRepository(ref.watch(frappeClientProvider));
});

final referralSummaryProvider = FutureProvider.autoDispose<ReferralSummary?>((
  ref,
) async {
  final auth = ref.watch(authControllerProvider);
  if (auth.status != AuthStatus.authenticated ||
      !auth.capabilities.canOwnReferrals) {
    return null;
  }

  return ref.watch(referralRepositoryProvider).fetchSummary();
});

class ReferralRepository {
  const ReferralRepository(this._client);

  final FrappeClient _client;

  Future<ReferralSummary> fetchSummary() async {
    final response = await _client.getMethod(
      ApiConfig.getMyReferralSummaryMethod,
    );
    return ReferralSummary.fromResponse(response);
  }

  Future<ReferralPage> fetchReferralPage({
    String? search,
    int limitStart = 0,
    int limitPageLength = 20,
  }) async {
    final queryParameters = <String, dynamic>{
      'limit_start': limitStart,
      'limit_page_length': limitPageLength,
    };

    final cleanSearch = search?.trim();
    if (cleanSearch != null && cleanSearch.isNotEmpty) {
      queryParameters['search'] = cleanSearch;
    }

    final response = await _client.getMethod(
      ApiConfig.getMyReferralsMethod,
      queryParameters: queryParameters,
    );

    final message = response['message'];
    final source = message is Map<String, dynamic> ? message : response;
    final items = source['items'];
    final parsed = items is List
        ? items
              .whereType<Map>()
              .map(
                (item) =>
                    ReferralCustomer.fromJson(Map<String, dynamic>.from(item)),
              )
              .where((item) => item.id.isNotEmpty)
              .toList(growable: false)
        : const <ReferralCustomer>[];

    return ReferralPage(
      items: parsed,
      hasMore: ReferralCustomer._bool(source['has_more']),
      nextStart: source['next_start'] == null
          ? null
          : ReferralCustomer._int(source['next_start']),
    );
  }

  Future<List<ReferralCustomer>> fetchReferrals({
    String? search,
    int limitStart = 0,
    int limitPageLength = 50,
  }) async {
    final page = await fetchReferralPage(
      search: search,
      limitStart: limitStart,
      limitPageLength: limitPageLength,
    );
    return page.items;
  }

  Future<ReferralDetail> fetchReferralDetail(String customerProfile) async {
    final cleanId = customerProfile.trim();
    if (cleanId.isEmpty) {
      throw const ApiError(message: 'Customer profile is required.');
    }

    final response = await _client.getMethod(
      ApiConfig.getMyReferralDetailMethod,
      queryParameters: {'customer_profile': cleanId},
    );
    return ReferralDetail.fromResponse(response);
  }
}

class ReferralPage {
  const ReferralPage({
    required this.items,
    required this.hasMore,
    required this.nextStart,
  });

  final List<ReferralCustomer> items;
  final bool hasMore;
  final int? nextStart;
}

class ReferralCustomer {
  const ReferralCustomer({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.customerStatus,
    required this.approvalStatus,
    required this.consentGranted,
    required this.customerOrigin,
    required this.totalServices,
    required this.selfCreatedServices,
    required this.referrerCreatedServices,
    required this.statusCounts,
    this.referralCodeUsed = '',
    this.isActive = false,
  });

  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String customerStatus;
  final String approvalStatus;
  final bool consentGranted;
  final String customerOrigin;
  final int totalServices;
  final int selfCreatedServices;
  final int referrerCreatedServices;
  final Map<String, int> statusCounts;
  final String referralCodeUsed;
  final bool isActive;

  factory ReferralCustomer.fromJson(Map<String, dynamic> json) {
    final counts = json['service_counts'];
    final countMap = counts is Map
        ? Map<String, dynamic>.from(counts)
        : const <String, dynamic>{};

    return ReferralCustomer(
      id: _string(json['customer_id']),
      fullName: _string(json['full_name']),
      email: _string(json['email']),
      phone: _string(json['phone']),
      customerStatus: _string(json['customer_status']),
      approvalStatus: _string(json['approval_status']),
      consentGranted: _bool(json['consent_granted']),
      customerOrigin: _string(json['customer_origin']),
      totalServices: _int(countMap['total_services']),
      selfCreatedServices: _int(countMap['self_created_services']),
      referrerCreatedServices: _int(countMap['referrer_created_services']),
      statusCounts: _intMap(json['service_status_counts']),
      referralCodeUsed: _string(json['referral_code_used']),
      isActive: _bool(json['is_active']),
    );
  }

  String get displayName => fullName.isEmpty ? id : fullName;

  String get contactLine {
    final values = <String>[
      if (phone.isNotEmpty) phone,
      if (email.isNotEmpty) email,
    ];

    return values.isEmpty ? 'No contact details available' : values.join(' • ');
  }

  static String _string(Object? value) => value?.toString().trim() ?? '';

  static int _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(_string(value)) ?? 0;
  }

  static bool _bool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;

    return const {
      '1',
      'true',
      'yes',
      'on',
    }.contains(_string(value).toLowerCase());
  }

  static Map<String, int> _intMap(Object? value) {
    if (value is! Map) return const {};
    return value.map((key, item) => MapEntry(key.toString(), _int(item)));
  }
}
