import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/frappe_client.dart';

final financeCommissionRepositoryProvider = Provider<FinanceCommissionRepository>(
  (ref) => FinanceCommissionRepository(ref.watch(frappeClientProvider)),
);

class FinanceCommissionRepository {
  const FinanceCommissionRepository(this._client);

  final FrappeClient _client;

  static const String _listMethod =
      'omc_app.api.commission_operations.get_commission_allocations';
  static const String _detailMethod =
      'omc_app.api.commission_operations.get_commission_allocation';
  static const String _reviewMethod =
      'omc_app.api.commission_lifecycle.review_allocation';
  static const String _markPayableMethod =
      'omc_app.api.commission_lifecycle.mark_payable';
  static const String _markPaidMethod =
      'omc_app.api.commission_lifecycle.mark_paid';

  Future<FinanceCommissionPage> fetchPage({
    int start = 0,
    int limit = 20,
    String? status,
    String? evidenceStatus,
    String? search,
  }) async {
    final response = await _client.getMethod(
      _listMethod,
      queryParameters: {
        'limit_start': start,
        'limit_page_length': limit.clamp(1, 100),
        if (status?.trim().isNotEmpty ?? false) 'status': status!.trim(),
        if (evidenceStatus?.trim().isNotEmpty ?? false)
          'evidence_status': evidenceStatus!.trim(),
        if (search?.trim().isNotEmpty ?? false) 'search': search!.trim(),
      },
    );
    final payload = _message(response);
    final rawItems = payload['items'];
    final items = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map(
                (item) => FinanceCommissionAllocation.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
        : const <FinanceCommissionAllocation>[];

    return FinanceCommissionPage(
      items: items,
      hasMore: _bool(payload['has_more']),
      nextStart: _nullableInt(payload['next_start']),
    );
  }

  Future<FinanceCommissionAllocation> fetchDetail(String allocationId) async {
    final id = allocationId.trim();
    if (id.isEmpty) {
      throw const ApiError(message: 'Commission allocation is required.');
    }
    final response = await _client.getMethod(
      _detailMethod,
      queryParameters: {'allocation': id},
    );
    return FinanceCommissionAllocation.fromJson(_message(response));
  }

  Future<void> approve(String allocationId) async {
    await _review(
      allocationId: allocationId,
      decision: 'approve',
    );
  }

  Future<void> reject({
    required String allocationId,
    required String reason,
  }) async {
    final cleanReason = reason.trim();
    if (cleanReason.isEmpty) {
      throw const ApiError(message: 'A rejection reason is required.');
    }
    await _review(
      allocationId: allocationId,
      decision: 'reject',
      reason: cleanReason,
    );
  }

  Future<void> _review({
    required String allocationId,
    required String decision,
    String? reason,
  }) async {
    final id = allocationId.trim();
    if (id.isEmpty) {
      throw const ApiError(message: 'Commission allocation is required.');
    }
    await _client.postMethod(
      _reviewMethod,
      data: {
        'allocation': id,
        'decision': decision,
        if (reason?.trim().isNotEmpty ?? false) 'reason': reason!.trim(),
      },
    );
  }

  Future<void> markPayable(String allocationId) async {
    final id = allocationId.trim();
    if (id.isEmpty) {
      throw const ApiError(message: 'Commission allocation is required.');
    }
    await _client.postMethod(
      _markPayableMethod,
      data: {'allocation': id},
    );
  }

  Future<void> markPaid({
    required String allocationId,
    required String settlementReference,
    String? settledOn,
  }) async {
    final id = allocationId.trim();
    final reference = settlementReference.trim();
    if (id.isEmpty) {
      throw const ApiError(message: 'Commission allocation is required.');
    }
    if (reference.isEmpty) {
      throw const ApiError(message: 'Settlement reference is required.');
    }
    await _client.postMethod(
      _markPaidMethod,
      data: {
        'allocation': id,
        'settlement_reference': reference,
        if (settledOn?.trim().isNotEmpty ?? false)
          'settled_on': settledOn!.trim(),
      },
    );
  }
}

class FinanceCommissionPage {
  const FinanceCommissionPage({
    required this.items,
    required this.hasMore,
    required this.nextStart,
  });

  final List<FinanceCommissionAllocation> items;
  final bool hasMore;
  final int? nextStart;
}

class FinanceCommissionAllocation {
  const FinanceCommissionAllocation({
    required this.id,
    required this.status,
    required this.evidenceStatus,
    required this.allowedActions,
    required this.beneficiary,
    required this.beneficiaryUser,
    required this.beneficiaryType,
    required this.sourcePersona,
    required this.component,
    required this.serviceRequest,
    required this.customerProfile,
    required this.customerName,
    required this.service,
    required this.serviceTitle,
    required this.currency,
    required this.basisAmount,
    required this.commissionPercent,
    required this.commissionAmount,
    required this.earnedOn,
    required this.approvedBy,
    required this.approvedAt,
    required this.payableMarkedBy,
    required this.payableMarkedAt,
    required this.rejectedBy,
    required this.rejectedAt,
    required this.rejectionReason,
    required this.settlementReference,
    required this.settledBy,
    required this.settledOn,
    required this.reversalReason,
    required this.reversedOn,
  });

  final String id;
  final String status;
  final String evidenceStatus;
  final Set<String> allowedActions;
  final String beneficiary;
  final String beneficiaryUser;
  final String beneficiaryType;
  final String sourcePersona;
  final String component;
  final String serviceRequest;
  final String customerProfile;
  final String customerName;
  final String service;
  final String serviceTitle;
  final String currency;
  final double basisAmount;
  final double commissionPercent;
  final double commissionAmount;
  final String earnedOn;
  final String approvedBy;
  final String approvedAt;
  final String payableMarkedBy;
  final String payableMarkedAt;
  final String rejectedBy;
  final String rejectedAt;
  final String rejectionReason;
  final String settlementReference;
  final String settledBy;
  final String settledOn;
  final String reversalReason;
  final String reversedOn;

  bool get canApprove => allowedActions.contains('approve');
  bool get canReject => allowedActions.contains('reject');
  bool get canMarkPayable => allowedActions.contains('mark_payable');
  bool get canMarkPaid => allowedActions.contains('mark_paid');
  bool get accountingReady => evidenceStatus == 'Matched';

  factory FinanceCommissionAllocation.fromJson(Map<String, dynamic> json) {
    final rawActions = json['allowed_actions'];
    return FinanceCommissionAllocation(
      id: _text(json['id'] ?? json['name']),
      status: _text(json['status']),
      evidenceStatus: _text(json['accounting_evidence_status']),
      allowedActions: rawActions is List
          ? rawActions.map(_text).where((item) => item.isNotEmpty).toSet()
          : const <String>{},
      beneficiary: _text(json['beneficiary']),
      beneficiaryUser: _text(json['beneficiary_user']),
      beneficiaryType: _text(json['beneficiary_type']),
      sourcePersona: _text(json['source_persona']),
      component: _text(json['component']),
      serviceRequest: _text(json['service_request']),
      customerProfile: _text(json['customer_profile']),
      customerName: _text(json['customer_name']),
      service: _text(json['service']),
      serviceTitle: _text(json['service_title']),
      currency: _text(json['currency']).isEmpty ? 'PKR' : _text(json['currency']),
      basisAmount: _double(json['basis_amount']),
      commissionPercent: _double(json['commission_percent']),
      commissionAmount: _double(json['commission_amount']),
      earnedOn: _text(json['earned_on']),
      approvedBy: _text(json['approved_by']),
      approvedAt: _text(json['approved_at']),
      payableMarkedBy: _text(json['payable_marked_by']),
      payableMarkedAt: _text(json['payable_marked_at']),
      rejectedBy: _text(json['rejected_by']),
      rejectedAt: _text(json['rejected_at']),
      rejectionReason: _text(json['rejection_reason']),
      settlementReference: _text(json['settlement_reference']),
      settledBy: _text(json['settled_by']),
      settledOn: _text(json['settled_on']),
      reversalReason: _text(json['reversal_reason']),
      reversedOn: _text(json['reversed_on']),
    );
  }
}

Map<String, dynamic> _message(Map<String, dynamic> response) {
  final value = response['message'];
  return value is Map ? Map<String, dynamic>.from(value) : response;
}

String _text(dynamic value) => value?.toString().trim() ?? '';
double _double(dynamic value) => double.tryParse(_text(value)) ?? 0;
int? _nullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  return int.tryParse(_text(value));
}

bool _bool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = _text(value).toLowerCase();
  return text == 'true' || text == '1' || text == 'yes';
}
