class ReferralSummary {
  const ReferralSummary({
    required this.code,
    required this.status,
    required this.isActive,
    required this.totalReferrals,
    required this.consentedReferrals,
    required this.activeReferrals,
    required this.totalServices,
    required this.selfCreatedServices,
    required this.referrerCreatedServices,
    required this.statusCounts,
  });

  final String code;
  final String status;
  final bool isActive;
  final int totalReferrals;
  final int consentedReferrals;
  final int activeReferrals;
  final int totalServices;
  final int selfCreatedServices;
  final int referrerCreatedServices;
  final Map<String, int> statusCounts;

  factory ReferralSummary.fromResponse(Map<String, dynamic> response) {
    final message = response['message'];
    final source = message is Map<String, dynamic> ? message : response;
    final referral = source['referral'];
    final counts = source['counts'];

    final referralMap = referral is Map<String, dynamic>
        ? referral
        : const <String, dynamic>{};
    final countsMap = counts is Map<String, dynamic>
        ? counts
        : const <String, dynamic>{};

    return ReferralSummary(
      code: _string(referralMap['referral_code']),
      status: _string(referralMap['status']),
      isActive: _bool(referralMap['is_active']),
      totalReferrals: _int(countsMap['total_referrals']),
      consentedReferrals: _int(countsMap['consented_referrals']),
      activeReferrals: _int(countsMap['active_referrals']),
      totalServices: _int(countsMap['total_services']),
      selfCreatedServices: _int(countsMap['self_created_services']),
      referrerCreatedServices: _int(countsMap['referrer_created_services']),
      statusCounts: _intMap(source['status_counts']),
    );
  }

  bool get isUsable => code.isNotEmpty;

  static String _string(Object? value) => value?.toString().trim() ?? '';

  static bool _bool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = _string(value).toLowerCase();
    return const {'1', 'true', 'yes', 'on'}.contains(text);
  }

  static int _int(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(_string(value)) ?? 0;
  }

  static Map<String, int> _intMap(Object? value) {
    if (value is! Map) return const {};
    return value.map(
      (key, item) => MapEntry(key.toString(), _int(item)),
    );
  }
}
