import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/network/frappe_client.dart';

const _settlementReviewsMethod =
    'omc_app.api.finance_reconciliation.get_settlement_reviews';
const _decideSettlementReviewMethod =
    'omc_app.api.finance_reconciliation.decide_settlement_review';

final financeReconciliationRepositoryProvider =
    Provider<FinanceReconciliationRepository>((ref) {
      return FinanceReconciliationRepository(ref.watch(frappeClientProvider));
    });

final financeReconciliationPageProvider = FutureProvider.family<
  FinanceReconciliationPage,
  FinanceReconciliationQuery
>((ref, query) {
  return ref.watch(financeReconciliationRepositoryProvider).fetchPage(query);
});

class FinanceReconciliationRepository {
  const FinanceReconciliationRepository(this._client);

  final FrappeClient _client;

  Future<FinanceReconciliationPage> fetchPage(
    FinanceReconciliationQuery query,
  ) async {
    final response = await _client.getMethod(
      _settlementReviewsMethod,
      queryParameters: {
        'limit_start': query.start,
        'limit_page_length': query.pageLength,
        'status': query.status,
        if (query.search.trim().isNotEmpty) 'search': query.search.trim(),
      },
    );
    return FinanceReconciliationPage.fromJson(_payload(response));
  }

  Future<void> decide({
    required String review,
    required FinanceReconciliationDecision decision,
    required String note,
  }) async {
    await _client.postMethod(
      _decideSettlementReviewMethod,
      data: {
        'review': review,
        'decision': decision.apiValue,
        'note': note.trim(),
      },
    );
  }

  Map<String, dynamic> _payload(Map<String, dynamic> response) {
    final message = response['message'];
    return message is Map<String, dynamic> ? message : response;
  }
}

enum FinanceReconciliationDecision { resolve, ignore }

extension FinanceReconciliationDecisionApi on FinanceReconciliationDecision {
  String get apiValue => name;
}

class FinanceReconciliationQuery {
  const FinanceReconciliationQuery({
    this.start = 0,
    this.pageLength = 20,
    this.search = '',
    this.status = 'Open',
  });

  final int start;
  final int pageLength;
  final String search;
  final String status;

  @override
  bool operator ==(Object other) =>
      other is FinanceReconciliationQuery &&
      other.start == start &&
      other.pageLength == pageLength &&
      other.search == search &&
      other.status == status;

  @override
  int get hashCode => Object.hash(start, pageLength, search, status);
}

class FinanceReconciliationPage {
  const FinanceReconciliationPage({
    required this.items,
    required this.start,
    required this.pageLength,
    required this.hasMore,
    required this.nextStart,
  });

  final List<FinanceReconciliationItem> items;
  final int start;
  final int pageLength;
  final bool hasMore;
  final int? nextStart;

  factory FinanceReconciliationPage.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(FinanceReconciliationItem.fromJson)
        .toList(growable: false);
    final start = _intValue(json['limit_start'], 0);
    final pageLength = _intValue(json['limit_page_length'], 20);
    final hasMore = _boolValue(json['has_more']);
    final parsedNext = int.tryParse('${json['next_start'] ?? ''}');
    return FinanceReconciliationPage(
      items: items,
      start: start,
      pageLength: pageLength,
      hasMore: hasMore,
      nextStart: hasMore ? (parsedNext ?? start + items.length) : null,
    );
  }
}

class FinanceReconciliationItem {
  const FinanceReconciliationItem({
    required this.id,
    required this.status,
    required this.reasonCode,
    required this.reasonLabel,
    required this.serviceRequest,
    required this.requestTitle,
    required this.customerName,
    required this.serviceTitle,
    required this.serviceStatus,
    required this.requestState,
    required this.sourceDoctype,
    required this.sourceName,
    required this.evidence,
    required this.createdAt,
    required this.resolvedBy,
    required this.resolvedAt,
    required this.resolutionNote,
    required this.allowedActions,
  });

  final String id;
  final String status;
  final String reasonCode;
  final String reasonLabel;
  final String serviceRequest;
  final String requestTitle;
  final String customerName;
  final String serviceTitle;
  final String serviceStatus;
  final String requestState;
  final String sourceDoctype;
  final String sourceName;
  final Map<String, dynamic> evidence;
  final String createdAt;
  final String resolvedBy;
  final String resolvedAt;
  final String resolutionNote;
  final Set<String> allowedActions;

  bool get canResolve => allowedActions.contains('resolve');
  bool get canIgnore => allowedActions.contains('ignore');
  bool get hasServiceRequest => serviceRequest.trim().isNotEmpty;

  factory FinanceReconciliationItem.fromJson(Map<String, dynamic> json) {
    return FinanceReconciliationItem(
      id: _text(json['name']),
      status: _text(json['status']),
      reasonCode: _text(json['reason_code']),
      reasonLabel: _text(json['reason_label']),
      serviceRequest: _text(json['service_request']),
      requestTitle: _text(json['request_title']),
      customerName: _text(json['customer_name']),
      serviceTitle: _text(json['service_title']),
      serviceStatus: _text(json['service_status']),
      requestState: _text(json['request_state']),
      sourceDoctype: _text(json['source_doctype']),
      sourceName: _text(json['source_name']),
      evidence: json['evidence'] is Map<String, dynamic>
          ? Map<String, dynamic>.unmodifiable(
              json['evidence'] as Map<String, dynamic>,
            )
          : const {},
      createdAt: _text(json['created_at']),
      resolvedBy: _text(json['resolved_by']),
      resolvedAt: _text(json['resolved_at']),
      resolutionNote: _text(json['resolution_note']),
      allowedActions: (json['allowed_actions'] as List? ?? const [])
          .map((value) => value.toString().trim().toLowerCase())
          .where((value) => value.isNotEmpty)
          .toSet(),
    );
  }
}

String _text(Object? value) => value?.toString().trim() ?? '';

int _intValue(Object? value, int fallback) =>
    value is int ? value : int.tryParse('${value ?? ''}') ?? fallback;

bool _boolValue(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return {'1', 'true', 'yes'}.contains(value?.toString().toLowerCase());
}
