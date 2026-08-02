class ReferralDetail {
  const ReferralDetail({
    required this.customer,
    required this.counts,
    required this.statusCounts,
    required this.services,
    required this.requests,
  });

  final ReferralDetailCustomer customer;
  final ReferralServiceCounts counts;
  final Map<String, int> statusCounts;
  final List<ReferralServiceBreakdown> services;
  final List<ReferralRequestSummary> requests;

  factory ReferralDetail.fromResponse(Map<String, dynamic> response) {
    final message = response['message'];
    final source = message is Map<String, dynamic> ? message : response;
    final customer = source['customer'];
    final counts = source['counts'];
    final services = source['services'];
    final requests = source['requests'];

    return ReferralDetail(
      customer: ReferralDetailCustomer.fromJson(
        customer is Map ? Map<String, dynamic>.from(customer) : const {},
      ),
      counts: ReferralServiceCounts.fromJson(
        counts is Map ? Map<String, dynamic>.from(counts) : const {},
      ),
      statusCounts: _intMap(source['status_counts']),
      services: services is List
          ? services
                .whereType<Map>()
                .map(
                  (item) => ReferralServiceBreakdown.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
          : const [],
      requests: requests is List
          ? requests
                .whereType<Map>()
                .map(
                  (item) => ReferralRequestSummary.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList(growable: false)
          : const [],
    );
  }
}

class ReferralDetailCustomer {
  const ReferralDetailCustomer({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.customerStatus,
    required this.approvalStatus,
    required this.consentGranted,
    required this.isActive,
    required this.referralCodeUsed,
  });

  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String customerStatus;
  final String approvalStatus;
  final bool consentGranted;
  final bool isActive;
  final String referralCodeUsed;

  factory ReferralDetailCustomer.fromJson(Map<String, dynamic> json) {
    return ReferralDetailCustomer(
      id: _string(json['customer_id']),
      fullName: _string(json['full_name']),
      email: _string(json['email']),
      phone: _string(json['phone']),
      customerStatus: _string(json['customer_status']),
      approvalStatus: _string(json['approval_status']),
      consentGranted: _bool(json['consent_granted']),
      isActive: _bool(json['is_active']),
      referralCodeUsed: _string(json['referral_code_used']),
    );
  }

  String get displayName => fullName.isEmpty ? id : fullName;
}

class ReferralServiceCounts {
  const ReferralServiceCounts({
    required this.total,
    required this.selfCreated,
    required this.referrerCreated,
  });

  final int total;
  final int selfCreated;
  final int referrerCreated;

  factory ReferralServiceCounts.fromJson(Map<String, dynamic> json) {
    return ReferralServiceCounts(
      total: _int(json['total_services']),
      selfCreated: _int(json['self_created_services']),
      referrerCreated: _int(json['referrer_created_services']),
    );
  }
}

class ReferralServiceBreakdown {
  const ReferralServiceBreakdown({
    required this.service,
    required this.title,
    required this.total,
    required this.selfCreated,
    required this.referrerCreated,
    required this.statusCounts,
  });

  final String service;
  final String title;
  final int total;
  final int selfCreated;
  final int referrerCreated;
  final Map<String, int> statusCounts;

  factory ReferralServiceBreakdown.fromJson(Map<String, dynamic> json) {
    return ReferralServiceBreakdown(
      service: _string(json['service']),
      title: _string(json['service_title']),
      total: _int(json['total']),
      selfCreated: _int(json['self_created']),
      referrerCreated: _int(json['referrer_created']),
      statusCounts: _intMap(json['status_counts']),
    );
  }
}

class ReferralRequestSummary {
  const ReferralRequestSummary({
    required this.id,
    required this.title,
    required this.status,
    required this.createdByCustomer,
    required this.createdByReferrer,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String status;
  final bool createdByCustomer;
  final bool createdByReferrer;
  final String createdAt;

  factory ReferralRequestSummary.fromJson(Map<String, dynamic> json) {
    return ReferralRequestSummary(
      id: _string(json['request_id']),
      title: _string(json['service_title']).isNotEmpty
          ? _string(json['service_title'])
          : _string(json['title']),
      status: _string(json['status']),
      createdByCustomer: _bool(json['created_by_customer']),
      createdByReferrer: _bool(json['created_by_referrer']),
      createdAt: _string(json['creation']),
    );
  }
}

String _string(Object? value) => value?.toString().trim() ?? '';

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(_string(value)) ?? 0;
}

bool _bool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return const {
    '1',
    'true',
    'yes',
    'on',
  }.contains(_string(value).toLowerCase());
}

Map<String, int> _intMap(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, item) => MapEntry(key.toString(), _int(item)));
}
