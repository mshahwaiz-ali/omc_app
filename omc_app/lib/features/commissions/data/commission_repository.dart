import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/frappe_client.dart';

final commissionRepositoryProvider = Provider<CommissionRepository>((ref) {
  return CommissionRepository(ref.watch(frappeClientProvider));
});

typedef CommissionPageLoader =
    Future<CommissionPage> Function({
      int start,
      int limit,
      String? periodMonth,
      String? status,
      String? customerProfile,
      String? service,
    });

typedef CommissionSummaryLoader =
    Future<List<CommissionSummary>> Function({String? periodMonth});

final commissionPageLoaderProvider = Provider<CommissionPageLoader>((ref) {
  return ref.watch(commissionRepositoryProvider).fetchPage;
});

final commissionSummaryLoaderProvider = Provider<CommissionSummaryLoader>((
  ref,
) {
  return ref.watch(commissionRepositoryProvider).fetchSummary;
});

class CommissionRepository {
  const CommissionRepository(this.client);
  final FrappeClient client;

  Future<CommissionPage> fetchPage({
    int start = 0,
    int limit = 20,
    String? periodMonth,
    String? status,
    String? customerProfile,
    String? service,
  }) async {
    final response = await client.getMethod(
      ApiConfig.getMyCommissionsMethod,
      queryParameters: {
        'start': start,
        'limit': limit,
        if (periodMonth?.isNotEmpty ?? false) 'period_month': periodMonth,
        if (status?.isNotEmpty ?? false) 'status': status,
        if (customerProfile?.isNotEmpty ?? false)
          'customer_profile': customerProfile,
        if (service?.isNotEmpty ?? false) 'service': service,
      },
    );
    final raw = _message(response);
    final items = (raw['items'] as List? ?? const [])
        .whereType<Map>()
        .map(
          (row) => CommissionEarning.fromJson(Map<String, dynamic>.from(row)),
        )
        .toList(growable: false);
    return CommissionPage(
      items: items,
      hasMore: _bool(raw['has_more']),
      nextStart: _int(raw['next_start'], start + items.length),
    );
  }

  Future<List<CommissionSummary>> fetchSummary({String? periodMonth}) async {
    final response = await client.getMethod(
      ApiConfig.getMyCommissionSummaryMethod,
      queryParameters: {
        if (periodMonth?.isNotEmpty ?? false) 'period_month': periodMonth,
      },
    );
    final currencies = _message(response)['currencies'];
    if (currencies is! Map) return const [];
    return currencies.entries
        .where((entry) => entry.value is Map)
        .map(
          (entry) => CommissionSummary.fromJson(
            entry.key.toString(),
            Map<String, dynamic>.from(entry.value as Map),
          ),
        )
        .toList(growable: false)
      ..sort((a, b) => a.currency.compareTo(b.currency));
  }

  Future<CommissionEarning> fetchOne(String id) async {
    final response = await client.getMethod(
      ApiConfig.getMyCommissionMethod,
      queryParameters: {'earning_id': id},
    );
    return CommissionEarning.fromJson(_message(response));
  }
}

class CommissionSummary {
  const CommissionSummary({
    required this.currency,
    required this.outstanding,
    required this.settled,
    required this.reversed,
    required this.count,
  });

  final String currency;
  final double outstanding;
  final double settled;
  final double reversed;
  final int count;

  factory CommissionSummary.fromJson(
    String currency,
    Map<String, dynamic> json,
  ) => CommissionSummary(
    currency: currency,
    outstanding: _double(json['outstanding']),
    settled: _double(json['settled']),
    reversed: _double(json['reversed']),
    count: _int(json['count'], 0),
  );
}

class CommissionPage {
  const CommissionPage({
    required this.items,
    required this.hasMore,
    required this.nextStart,
  });
  final List<CommissionEarning> items;
  final bool hasMore;
  final int nextStart;
}

class CommissionEarning {
  const CommissionEarning({
    required this.id,
    required this.status,
    required this.customer,
    required this.service,
    required this.request,
    required this.currency,
    required this.basis,
    required this.percent,
    required this.amount,
    required this.earnedOn,
    required this.settlement,
    required this.reversalReason,
  });
  final String id;
  final String status;
  final String customer;
  final String service;
  final String request;
  final String currency;
  final double basis;
  final double percent;
  final double amount;
  final String earnedOn;
  final String settlement;
  final String reversalReason;

  factory CommissionEarning.fromJson(Map<String, dynamic> json) =>
      CommissionEarning(
        id: _text(json['name'] ?? json['id']),
        status: _text(json['status'] ?? json['earning_status']),
        customer: _text(
          json['customer_name'] ?? json['customer_profile'] ?? json['customer'],
        ),
        service: _text(json['service_title'] ?? json['service']),
        request: _text(json['service_request'] ?? json['request']),
        currency: _text(json['currency']).isEmpty
            ? 'PKR'
            : _text(json['currency']),
        basis: _double(json['basis_amount']),
        percent: _double(
          json['commission_percent_snapshot'] ??
              json['commission_percent'] ??
              json['percent'],
        ),
        amount: _double(json['commission_amount'] ?? json['amount']),
        earnedOn: _text(json['earned_on']),
        settlement: _text(json['settlement_reference']),
        reversalReason: _text(json['reversal_reason']),
      );
}

Map<String, dynamic> _message(Map<String, dynamic>? response) {
  final value = response?['message'] ?? response ?? const <String, dynamic>{};
  return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
}

String _text(dynamic value) => value?.toString().trim() ?? '';
double _double(dynamic value) => double.tryParse(_text(value)) ?? 0;
int _int(dynamic value, int fallback) => int.tryParse(_text(value)) ?? fallback;
bool _bool(dynamic value) =>
    value == true || value == 1 || _text(value).toLowerCase() == 'true';
