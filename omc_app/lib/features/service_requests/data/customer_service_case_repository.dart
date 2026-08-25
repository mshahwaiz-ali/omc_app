import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/frappe_client.dart';

final customerServiceCaseRepositoryProvider =
    Provider<CustomerServiceCaseRepository>((ref) {
      return CustomerServiceCaseRepository(
        frappeClient: ref.watch(frappeClientProvider),
      );
    });

final customerServiceCaseDetailProvider =
    FutureProvider.family<CustomerServiceCaseDetail?, String>((
      ref,
      caseId,
    ) async {
      return ref
          .watch(customerServiceCaseRepositoryProvider)
          .fetchDetail(caseId);
    });

class CustomerServiceCaseRepository {
  const CustomerServiceCaseRepository({required this.frappeClient});

  static const String _detailMethod =
      'omc_app.api.service_case_contract.get_service_case';

  final FrappeClient frappeClient;

  Future<CustomerServiceCaseDetail?> fetchDetail(String caseId) async {
    final cleanCaseId = caseId.trim();
    if (cleanCaseId.isEmpty) {
      throw const ApiError(message: 'Missing service request reference.');
    }

    try {
      final response = await frappeClient.getMethod(
        _detailMethod,
        queryParameters: {'case_id': cleanCaseId},
      );
      return CustomerServiceCaseDetail.fromResponse(response);
    } on ApiError {
      rethrow;
    } catch (error) {
      throw ApiError(
        message: 'This service request could not be loaded right now.',
        code: 'customer_service_case_unavailable',
        details: error,
      );
    }
  }

  Future<void> cancelRequest(String caseId) async {
    final cleanCaseId = caseId.trim();
    if (cleanCaseId.isEmpty) {
      throw const ApiError(message: 'Missing service request reference.');
    }

    await frappeClient.postMethod(
      ApiConfig.cancelServiceRequestMethod,
      data: {'case_id': cleanCaseId},
    );
  }
}

class CustomerServiceCaseDetail {
  const CustomerServiceCaseDetail({
    required this.id,
    required this.title,
    required this.statusLabel,
    required this.requestState,
    required this.operationalStatus,
    required this.currentStage,
    required this.progressPercent,
    required this.actionRequired,
    required this.isTerminal,
    required this.isCompleted,
    required this.paymentNotRequired,
    required this.nextAction,
    required this.milestones,
    required this.documents,
    required this.activities,
    required this.receiptStatus,
    required this.paymentStatus,
    required this.paymentId,
    required this.settlementStatus,
    required this.payableAmount,
    required this.currency,
    required this.createdAtLabel,
    required this.updatedAtLabel,
    required this.canCancel,
    required this.createdOnBehalf,
    required this.submittedByName,
  });

  final String id;
  final String title;
  final String statusLabel;
  final String requestState;
  final String operationalStatus;
  final String currentStage;
  final int progressPercent;
  final bool actionRequired;
  final bool isTerminal;
  final bool isCompleted;
  final bool paymentNotRequired;
  final CustomerServiceCaseAction? nextAction;
  final List<CustomerServiceCaseMilestone> milestones;
  final List<CustomerServiceCaseDocument> documents;
  final List<CustomerServiceCaseActivity> activities;
  final String receiptStatus;
  final String paymentStatus;
  final String paymentId;
  final String settlementStatus;
  final double payableAmount;
  final String currency;
  final String createdAtLabel;
  final String updatedAtLabel;
  final bool canCancel;
  final bool createdOnBehalf;
  final String submittedByName;

  List<CustomerServiceCaseDocument> get requiredDocuments => documents
      .where((document) => document.isRequired)
      .toList(growable: false);

  int get documentsNeedingUpload =>
      requiredDocuments.where((document) => document.needsUpload).length;

  bool get paymentUnderReview {
    final actionType = nextAction?.type.trim().toLowerCase();
    if (actionType == 'await_payment_review') return true;
    final receipt = receiptStatus.trim().toLowerCase();
    final payment = paymentStatus.trim().toLowerCase();
    return receipt == 'submitted' ||
        receipt == 'receipt submitted' ||
        receipt == 'under review' ||
        payment == 'receipt submitted' ||
        payment == 'under review';
  }

  bool get paymentNeedsCorrection {
    final actionType = nextAction?.type.trim().toLowerCase();
    return actionType == 'correct_payment_receipt' ||
        receiptStatus.trim().toLowerCase() == 'rejected' ||
        paymentStatus.trim().toLowerCase() == 'rejected';
  }

  factory CustomerServiceCaseDetail.fromResponse(
    Map<String, dynamic> response,
  ) {
    final payload = _payloadFromResponse(response);
    final lifecycle = _map(payload['customer_lifecycle']);
    final receipt = _map(payload['receipt']);
    final settlement = _map(payload['settlement']);
    final action = _map(lifecycle['next_action']);

    return CustomerServiceCaseDetail(
      id: _text(
        payload['name'] ??
            payload['id'] ??
            payload['reference'] ??
            payload['case_reference'],
      ),
      title: _text(
        payload['service_title'] ?? payload['title'] ?? 'Service Request',
      ),
      statusLabel: _text(
        payload['display_status'] ??
            payload['request_state'] ??
            payload['status'] ??
            'Open',
      ),
      requestState: _text(payload['request_state']),
      operationalStatus: _text(
        payload['operational_status'] ?? payload['status'],
      ),
      currentStage: _text(
        lifecycle['current_stage'] ?? payload['current_stage'],
      ),
      progressPercent: _intValue(
        lifecycle['progress_percent'] ?? payload['progress_percent'],
      ).clamp(0, 100).toInt(),
      actionRequired: _boolValue(lifecycle['action_required']),
      isTerminal: _boolValue(lifecycle['terminal']),
      isCompleted: _boolValue(lifecycle['completed']),
      paymentNotRequired:
          _boolValue(lifecycle['payment_not_required']) ||
          _text(payload['request_state']).toLowerCase() ==
              'payment not required' ||
          _text(receipt['status']).toLowerCase() == 'not required' ||
          _text(settlement['status']).toLowerCase() == 'not required',
      nextAction: action.isEmpty
          ? null
          : CustomerServiceCaseAction.fromJson(action),
      milestones: _mapList(lifecycle['milestones'])
          .map(CustomerServiceCaseMilestone.fromJson)
          .where((item) => item.label.isNotEmpty)
          .toList(growable: false),
      documents:
          _mapList(
                payload['document_details'] ??
                    payload['required_document_details'],
              )
              .map(CustomerServiceCaseDocument.fromJson)
              .where((item) => item.title.isNotEmpty)
              .toList(growable: false),
      activities: _mapList(payload['recent_activity'])
          .map(CustomerServiceCaseActivity.fromJson)
          .where((item) => item.title.isNotEmpty)
          .toList(growable: false),
      receiptStatus: _text(
        receipt['status'] ?? payload['receipt_status'] ?? 'Not Submitted',
      ),
      paymentStatus: _text(
        receipt['payment_status'] ?? payload['payment_status'],
      ),
      paymentId: _text(receipt['payment_id'] ?? payload['payment_id']),
      settlementStatus: _text(
        settlement['status'] ?? payload['accounting_status'],
      ),
      payableAmount: _doubleValue(
        settlement['payable_amount'] ?? payload['payable_amount'],
      ),
      currency: _text(settlement['currency'] ?? 'PKR'),
      createdAtLabel: _text(
        payload['submitted_on'] ??
            payload['created_at_label'] ??
            payload['created_at'] ??
            payload['creation'],
      ),
      updatedAtLabel: _text(
        payload['updated_at_label'] ??
            payload['updated_at'] ??
            payload['modified'],
      ),
      canCancel: _boolValue(payload['can_cancel']),
      createdOnBehalf: _boolValue(payload['created_on_behalf']),
      submittedByName: _text(
        payload['submitted_by_internal_name'] ?? payload['submitted_by_name'],
      ),
    );
  }
}

class CustomerServiceCaseAction {
  const CustomerServiceCaseAction({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.route,
    required this.buttonLabel,
    required this.required,
  });

  final String type;
  final String title;
  final String subtitle;
  final String route;
  final String buttonLabel;
  final bool required;

  factory CustomerServiceCaseAction.fromJson(Map<String, dynamic> json) {
    return CustomerServiceCaseAction(
      type: _text(json['type']),
      title: _text(json['title']),
      subtitle: _text(json['subtitle']),
      route: _text(json['route']),
      buttonLabel: _text(json['button_label']),
      required: _boolValue(json['required']),
    );
  }
}

class CustomerServiceCaseMilestone {
  const CustomerServiceCaseMilestone({
    required this.key,
    required this.label,
    required this.state,
    required this.detail,
  });

  final String key;
  final String label;
  final String state;
  final String detail;

  bool get isComplete => state.toLowerCase() == 'complete';
  bool get isCurrent => state.toLowerCase() == 'current';
  bool get isAttention => state.toLowerCase() == 'attention';
  bool get isSkipped => state.toLowerCase() == 'skipped';

  factory CustomerServiceCaseMilestone.fromJson(Map<String, dynamic> json) {
    return CustomerServiceCaseMilestone(
      key: _text(json['key']),
      label: _text(json['label']),
      state: _text(json['state']),
      detail: _text(json['detail']),
    );
  }
}

class CustomerServiceCaseDocument {
  const CustomerServiceCaseDocument({
    required this.id,
    required this.title,
    required this.status,
    required this.remarks,
    required this.fileUrl,
    required this.isRequired,
    this.documentKey = '',
    this.documentType = '',
  });

  final String id;
  final String title;
  final String documentKey;
  final String documentType;
  final String status;
  final String remarks;
  final String fileUrl;
  final bool isRequired;

  String get normalizedStatus => status.trim().toLowerCase();

  String get uploadIdentity {
    final key = documentKey.trim().toLowerCase();
    if (key.isNotEmpty) return 'key:$key';

    return 'legacy:${title.trim().toLowerCase()}|${documentType.trim().toLowerCase()}';
  }

  bool get isApproved =>
      normalizedStatus == 'approved' || normalizedStatus == 'verified';

  bool get isRejected => normalizedStatus == 'rejected';

  bool get isUnderReview =>
      normalizedStatus == 'uploaded' ||
      normalizedStatus == 'submitted' ||
      normalizedStatus == 'under review';

  bool get needsUpload {
    if (!isRequired) return false;
    if (isRejected) return true;
    if (fileUrl.trim().isNotEmpty) return false;
    return normalizedStatus == 'pending' ||
        normalizedStatus == 'missing' ||
        normalizedStatus == 'required' ||
        normalizedStatus == 'expired' ||
        normalizedStatus.isEmpty;
  }

  factory CustomerServiceCaseDocument.fromJson(Map<String, dynamic> json) {
    return CustomerServiceCaseDocument(
      id: _text(json['id'] ?? json['name']),
      title: _text(json['title'] ?? json['document_title']),
      documentKey: _text(json['document_key'] ?? json['key']),
      documentType: _text(json['document_type'] ?? json['type']),
      status: _text(json['status']),
      remarks: _text(json['remarks'] ?? json['instructions']),
      fileUrl: _text(json['file_url'] ?? json['attachment']),
      isRequired: _boolValue(json['is_required']),
    );
  }
}

class CustomerServiceCaseActivity {
  const CustomerServiceCaseActivity({
    required this.title,
    required this.subtitle,
    required this.dateLabel,
  });

  final String title;
  final String subtitle;
  final String dateLabel;

  factory CustomerServiceCaseActivity.fromJson(Map<String, dynamic> json) {
    return CustomerServiceCaseActivity(
      title: _text(json['title'] ?? json['event_type']),
      subtitle: _text(json['subtitle'] ?? json['description']),
      dateLabel: _text(
        json['event_time'] ??
            json['created_at'] ??
            json['created_on'] ??
            json['creation'],
      ),
    );
  }
}

Map<String, dynamic> _payloadFromResponse(Map<String, dynamic> response) {
  final message = _map(response['message']);
  final envelope = message.isEmpty ? response : message;
  final nested = _map(
    envelope['case'] ??
        envelope['service_case'] ??
        envelope['request'] ??
        envelope['service_request'],
  );
  return nested.isEmpty ? envelope : nested;
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const <String, dynamic>{};
}

List<Map<String, dynamic>> _mapList(dynamic value) {
  if (value is! List) return const [];
  return value
      .map(_map)
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

String _text(dynamic value) => value?.toString().trim() ?? '';

bool _boolValue(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = _text(value).toLowerCase();
  return normalized == 'true' || normalized == '1' || normalized == 'yes';
}

int _intValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(_text(value)) ?? 0;
}

double _doubleValue(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(_text(value)) ?? 0;
}
