import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/config/env.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/frappe_client.dart';
import '../../../core/storage/json_cache_service.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';
import 'service_case.dart';

final serviceCaseCacheProvider = FutureProvider<JsonCacheService>((ref) {
  return JsonCacheService.create();
});

final serviceCaseRepositoryProvider = Provider<ServiceCaseRepository>((ref) {
  final frappeClient = ref.watch(frappeClientProvider);
  final cacheService = ref
      .watch(serviceCaseCacheProvider)
      .maybeWhen(data: (cacheService) => cacheService, orElse: () => null);

  return ServiceCaseRepository(
    frappeClient: frappeClient,
    cacheService: cacheService,
    cacheNamespace: _cacheNamespace(ref.watch(authControllerProvider).userId),
  );
});

String _cacheNamespace(String? userId) {
  final identity = userId?.trim().toLowerCase();
  final value = identity == null || identity.isEmpty
      ? 'guest-device'
      : identity;
  return base64Url.encode(utf8.encode(value)).replaceAll('=', '');
}

final serviceCasesProvider = FutureProvider.autoDispose<List<ServiceCase>>((
  ref,
) async {
  final authState = ref.watch(authControllerProvider);
  if (authState.status != AuthStatus.authenticated) {
    return const <ServiceCase>[];
  }
  final repository = ref.watch(serviceCaseRepositoryProvider);

  if (Env.useServicePreview) {
    return repository.sampleCasesForUiPreview();
  }

  return repository.fetchServiceCases();
});

final serviceCasePageProvider = FutureProvider.autoDispose
    .family<ServiceCasePage, ServiceCasePageQuery>((ref, query) async {
      final repository = ref.watch(serviceCaseRepositoryProvider);
      if (Env.useServicePreview) {
        final items = repository.sampleCasesForUiPreview();
        return ServiceCasePage(
          items: items,
          start: 0,
          pageLength: items.length,
          nextStart: null,
          hasMore: false,
        );
      }
      return repository.fetchServiceCasePage(query);
    });

final serviceCaseDetailProvider = FutureProvider.autoDispose
    .family<ServiceCase?, String>((ref, caseId) async {
      final repository = ref.watch(serviceCaseRepositoryProvider);

      if (Env.useServicePreview) {
        final cases = repository.sampleCasesForUiPreview();

        for (final serviceCase in cases) {
          if (serviceCase.id == caseId || serviceCase.reference == caseId) {
            return serviceCase;
          }
        }

        return null;
      }

      return repository.fetchServiceCaseDetail(caseId);
    });

class ServiceCaseRepository {
  const ServiceCaseRepository({
    required FrappeClient frappeClient,
    JsonCacheService? cacheService,
    required String cacheNamespace,
  }) : this._(frappeClient, cacheService, cacheNamespace);

  const ServiceCaseRepository._(
    this._frappeClient,
    this._cacheService,
    this._cacheNamespace,
  );

  static const String _serviceCasesCachePrefix = 'service_cases_cache_v3';

  final FrappeClient _frappeClient;
  final JsonCacheService? _cacheService;
  final String _cacheNamespace;

  String get _serviceCasesCacheKey =>
      '$_serviceCasesCachePrefix::$_cacheNamespace';

  Future<List<ServiceCase>> fetchServiceCases() async {
    return (await fetchServiceCasePage(
      const ServiceCasePageQuery(pageLength: 100),
    )).items;
  }

  Future<ServiceCasePage> fetchServiceCasePage(
    ServiceCasePageQuery query,
  ) async {
    try {
      final response = await _frappeClient.getMethod(
        ApiConfig.serviceCasesMethod,
        queryParameters: {
          'limit_start': query.start,
          'limit_page_length': query.pageLength,
        },
      );

      if (query.start == 0) {
        await _cacheService?.saveMap(_serviceCasesCacheKey, response);
      }
      return _mapServiceCasePage(response, query);
    } on ApiError catch (error) {
      if (query.start == 0) {
        final cachedResponse = _cacheService?.readMap(_serviceCasesCacheKey);
        if (cachedResponse != null) {
          return _mapServiceCasePage(cachedResponse, query);
        }
      }
      throw _trackingApiUnavailable(error);
    } catch (error) {
      if (query.start == 0) {
        final cachedResponse = _cacheService?.readMap(_serviceCasesCacheKey);
        if (cachedResponse != null) {
          return _mapServiceCasePage(cachedResponse, query);
        }
      }
      throw _trackingApiUnavailable(error);
    }
  }

  ServiceCasePage _mapServiceCasePage(
    Map<String, dynamic> response,
    ServiceCasePageQuery query,
  ) {
    final payload = _payloadMap(response);
    final items = _mapServiceCasesResponse(response);
    final start = _nullableIntValue(payload['limit_start']) ?? query.start;
    final pageLength =
        _nullableIntValue(payload['limit_page_length']) ?? query.pageLength;
    final nextStart = _nullableIntValue(payload['next_start']);
    final hasMore = _boolValue(payload['has_more']) || nextStart != null;
    return ServiceCasePage(
      items: items,
      start: start,
      pageLength: pageLength,
      nextStart: hasMore ? nextStart ?? start + items.length : null,
      hasMore: hasMore,
    );
  }

  Future<ServiceCase?> fetchServiceCaseDetail(String caseId) async {
    try {
      final response = await _frappeClient.getMethod(
        ApiConfig.serviceCaseDetailMethod,
        queryParameters: {
          'case_id': caseId,
          'name': caseId,
          'service_request': caseId,
          'request_id': caseId,
        },
      );

      final cases = _mapServiceCasesResponse(response);
      if (cases.isEmpty) return null;

      return cases.first;
    } on ApiError catch (error) {
      throw _trackingApiUnavailable(error);
    } catch (error) {
      throw _trackingApiUnavailable(error);
    }
  }

  Future<Map<String, dynamic>> updateServiceDocumentStatus({
    required String documentId,
    required String status,
    String? remarks,
  }) async {
    final cleanDocumentId = documentId.trim();
    final cleanStatus = status.trim();
    final cleanRemarks = remarks?.trim();

    if (cleanDocumentId.isEmpty) {
      throw const ApiError(message: 'Missing document reference.');
    }

    if (cleanStatus.isEmpty) {
      throw const ApiError(message: 'Select a valid document status.');
    }

    final data = <String, dynamic>{
      'document_id': cleanDocumentId,
      'status': cleanStatus,
    };

    if (cleanRemarks != null && cleanRemarks.isNotEmpty) {
      data['remarks'] = cleanRemarks;
    }

    return _frappeClient.postMethod(
      ApiConfig.updateServiceDocumentStatusMethod,
      data: data,
    );
  }

  Future<Map<String, dynamic>> cancelServiceRequest({
    required String caseId,
  }) async {
    final cleanCaseId = caseId.trim();
    if (cleanCaseId.isEmpty) {
      throw const ApiError(message: 'Missing service case reference.');
    }

    return _frappeClient.postMethod(
      ApiConfig.cancelServiceRequestMethod,
      data: {'case_id': cleanCaseId},
    );
  }

  Future<ServiceCase?> updateServiceCaseStatus({
    required String caseId,
    required String status,
    String? note,
    String? expectedCompletionDate,
  }) async {
    final cleanCaseId = caseId.trim();
    final cleanStatus = status.trim();
    final cleanNote = note?.trim();
    final cleanExpectedCompletionDate = expectedCompletionDate?.trim();

    if (cleanCaseId.isEmpty) {
      throw const ApiError(message: 'Missing service case reference.');
    }

    if (cleanStatus.isEmpty) {
      throw const ApiError(message: 'Select a valid service case status.');
    }

    final data = <String, dynamic>{
      'case_id': cleanCaseId,
      'status': cleanStatus,
    };

    if (cleanNote != null && cleanNote.isNotEmpty) {
      data['note'] = cleanNote;
    }

    if (cleanExpectedCompletionDate != null &&
        cleanExpectedCompletionDate.isNotEmpty) {
      data['expected_completion_date'] = cleanExpectedCompletionDate;
    }

    final response = await _frappeClient.postMethod(
      ApiConfig.updateServiceCaseStatusMethod,
      data: data,
    );

    final updatedCases = _mapServiceCasesResponse(response);
    if (updatedCases.isNotEmpty) {
      return updatedCases.first;
    }

    return fetchServiceCaseDetail(cleanCaseId);
  }

  ApiError _trackingApiUnavailable(Object details) {
    return ApiError(
      message:
          'Service tracking is unavailable on the server right now. Your submitted requests are still sent to OMC, and live tracking will appear when service updates are available.',
      code: 'service_tracking_unavailable',
      details: details,
    );
  }

  Map<String, dynamic> _payloadMap(Map<String, dynamic> data) {
    final message = data['message'];
    return message is Map<String, dynamic> ? message : data;
  }

  List<ServiceCase> _mapServiceCasesResponse(Map<String, dynamic>? data) {
    if (data == null) return const [];

    final message = data['message'];
    final rawCases = message is List
        ? message
        : message is Map<String, dynamic>
        ? message['cases'] ??
              message['service_cases'] ??
              message['requests'] ??
              message['data'] ??
              message['items'] ??
              message['rows'] ??
              message['results'] ??
              message['records']
        : data['cases'] ??
              data['service_cases'] ??
              data['requests'] ??
              data['data'] ??
              data['items'] ??
              data['rows'] ??
              data['results'] ??
              data['records'];

    if (rawCases is List) {
      return rawCases
          .whereType<Map<String, dynamic>>()
          .map(_mapServiceCase)
          .toList(growable: false);
    }

    final rawCase = message is Map<String, dynamic>
        ? message['case'] ??
              message['service_case'] ??
              message['request'] ??
              message['service_request'] ??
              message['result'] ??
              message['record'] ??
              message
        : data['case'] ??
              data['service_case'] ??
              data['request'] ??
              data['service_request'] ??
              data['result'] ??
              data['record'];

    if (rawCase is Map<String, dynamic>) {
      return [_mapServiceCase(rawCase)];
    }

    return const [];
  }

  ServiceCase _mapServiceCase(Map<String, dynamic> json) {
    final timelineSource =
        json['timeline'] ??
        json['stages'] ??
        json['service_stages'] ??
        json['tracking_timeline'] ??
        json['service_timeline'] ??
        json['activity'] ??
        json['recent_activity'];

    final documentDetails = _documentDetails(
      json['document_details'] ??
          json['required_document_details'] ??
          json['documents'],
    );

    final paymentDetails = _paymentDetails(
      json['payment_details'] ?? json['payments'] ?? json['service_payments'],
    );
    final receipt = _mapValue(json['receipt']);
    final settlement = _mapValue(json['settlement']);
    final activation = _mapValue(json['activation']);
    final hold = _mapValue(json['hold'] ?? json['financial_hold']);

    return ServiceCase(
      id: _stringValue(json['id'] ?? json['name'] ?? json['case_id']),
      reference: _nullableString(
        json['reference'] ??
            json['case_reference'] ??
            json['service_request'] ??
            json['request_id'],
      ),
      serviceId: _nullableString(
        json['service_id'] ?? json['service'] ?? json['service_code'],
      ),
      title: _stringValue(
        json['title'] ??
            json['service_title'] ??
            json['subject'] ??
            json['service_name'],
      ),
      category: _stringValue(
        json['category'] ?? json['service_category'] ?? json['service_group'],
      ),
      status: _stringValue(json['status'] ?? json['operational_status']),
      requestState: _nullableString(json['request_state']),
      operationalStatus: _nullableString(
        json['operational_status'] ?? json['status'],
      ),
      receipt: ServiceCaseReceipt(
        status:
            _nullableString(receipt['status'] ?? json['receipt_status']) ??
            'Not Submitted',
        paymentStatus:
            _nullableString(
              receipt['payment_status'] ?? json['payment_status'],
            ) ??
            '',
        paymentId:
            _nullableString(receipt['payment_id'] ?? json['payment_id']) ?? '',
      ),
      settlement: ServiceCaseSettlement(
        status:
            _nullableString(
              settlement['status'] ?? json['accounting_status'],
            ) ??
            'Unmatched',
        allocatedAmount: _moneyValue(settlement['allocated_amount']),
        payableAmount: _moneyValue(settlement['payable_amount']),
        currency: _nullableString(settlement['currency']) ?? 'PKR',
        outstandingAmount: _moneyValue(settlement['outstanding_amount']),
        reviewKind: _nullableString(settlement['review_kind']) ?? '',
      ),
      activation: ServiceCaseActivation(
        state:
            _nullableString(activation['state'] ?? json['request_state']) ?? '',
        bridgeState:
            _nullableString(activation['bridge_state']) ?? 'Not Started',
        attemptCount: _nullableIntValue(activation['attempt_count']) ?? 0,
        activated: _boolValue(activation['activated']),
        evidenceComplete: _boolValue(activation['evidence_complete']),
        readyAt: _nullableString(activation['ready_at']) ?? '',
        activatedAt: _nullableString(activation['activated_at']) ?? '',
      ),
      hold: ServiceCaseHold(
        active: _boolValue(hold['active']),
        reason:
            _nullableString(hold['reason'] ?? json['financial_hold_reason']) ??
            '',
      ),
      createdAtLabel: _displayDate(
        json['created_at_label'] ??
            json['created'] ??
            json['created_at'] ??
            json['submitted_on'] ??
            json['creation'],
      ),
      updatedAtLabel: _displayDate(
        json['updated_at_label'] ?? json['updated_at'] ?? json['modified'],
      ),
      progress: _doubleValue(json['progress'] ?? json['progress_percent']),
      nextStep: _nullableString(
        json['next_step'] ??
            _nextActionLabel(json['next_action']) ??
            json['customer_next_step'],
      ),
      remarks: _nullableString(json['remarks']),
      requiredDocuments: _stringList(json['required_documents']),
      submittedDocuments: _stringList(json['submitted_documents']),
      missingDocuments: _stringList(json['missing_documents']),
      documentDetails: documentDetails.isNotEmpty
          ? documentDetails
          : _fallbackDocumentDetails(json),
      paymentDetails: paymentDetails,
      timeline: _timeline(timelineSource),
      progressPercent: _nullableIntValue(json['progress_percent']),
      currentStage: _nullableString(json['current_stage'] ?? json['stage']),
      customerProfile: _nullableString(json['customer_profile']),
      customerMode: _nullableString(json['customer_mode']),
      submissionMode: _nullableString(json['submission_mode']),
      createdOnBehalf: _boolValue(json['created_on_behalf']),
      customerName: _nullableString(json['customer_name'] ?? json['full_name']),
      submittedByUser: _nullableString(json['submitted_by_user']),
      submittedByName: _nullableString(json['submitted_by_name']),
      submittedByInternalUser: _nullableString(
        json['submitted_by_internal_user'],
      ),
      submittedByInternalName: _nullableString(
        json['submitted_by_internal_name'],
      ),
      customerEmail: _nullableString(json['contact_email'] ?? json['email']),
      customerPhone: _nullableString(json['contact_phone'] ?? json['phone']),
      customerNtn: _nullableString(json['ntn'] ?? json['customer_ntn']),
      customerCnic: _nullableString(json['cnic'] ?? json['customer_cnic']),
      companyName: _nullableString(json['company_name']),
      priority: _nullableString(json['priority']),
      customerActionRequired: _boolValue(json['customer_action_required']),
      requiredDocumentsCount: _nullableIntValue(
        json['required_documents_count'],
      ),
      submittedDocumentsCount: _nullableIntValue(
        json['submitted_documents_count'],
      ),
      missingDocumentsCount: _nullableIntValue(json['missing_documents_count']),
      canUpdateStatus:
          _boolValue(json['can_update_status']) &&
          _boolValue(json['can_view_internal_notes']),
      canReviewDocuments:
          _boolValue(json['can_review_documents']) &&
          _boolValue(json['can_view_internal_notes']),
      canViewInternalNotes: _boolValue(json['can_view_internal_notes']),
      canCancel: _boolValue(json['can_cancel']),
      documentsComplete: _boolValue(json['documents_complete']),
      paymentEligible: _boolValue(json['payment_eligible']),
      paymentId: _nullableString(json['payment_id'] ?? receipt['payment_id']),
      paymentStatus: _nullableString(
        json['payment_status'] ?? receipt['payment_status'],
      ),
      paymentBlockReason: _nullableString(json['payment_block_reason']),
      nextAction: _nextActionLabel(json['next_action']),
      displayStatus: _nullableString(json['display_status']),
      milestones: _plainStringList(json['milestones']),
      completionBlockers: _plainStringList(json['completion_blockers']),
      completionEligible: _boolValue(json['completion_eligible']),
    );
  }

  Map<String, dynamic> _mapValue(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, item) => MapEntry(key.toString(), item));
    }
    return const <String, dynamic>{};
  }

  String? _nextActionLabel(dynamic value) {
    if (value is Map<String, dynamic>) {
      return _nullableString(
        value['label'] ?? value['action'] ?? value['type'],
      );
    }
    return _nullableString(value);
  }

  List<String> _plainStringList(dynamic value) {
    if (value is! List) return const [];
    return value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }

  List<ServiceCaseDocument> _fallbackDocumentDetails(
    Map<String, dynamic> json,
  ) {
    final required = _stringList(json['required_documents']);
    if (required.isEmpty) return const [];

    final submitted = _stringSet(json['submitted_documents']);
    final missing = _stringSet(json['missing_documents']);

    return required
        .map(
          (title) => ServiceCaseDocument(
            id: '-',
            title: title,
            type: '',
            status: submitted.contains(title.toLowerCase())
                ? 'Uploaded'
                : missing.contains(title.toLowerCase())
                ? 'Missing'
                : 'Required',
          ),
        )
        .toList(growable: false);
  }

  List<ServiceCaseDocument> _documentDetails(dynamic value) {
    if (value is! List) return const [];

    return value
        .whereType<Map<String, dynamic>>()
        .map((item) {
          final status = _stringValue(item['status']);
          final fileUrl = _nullableString(
            item['file_url'] ?? item['attachment'] ?? item['url'],
          );

          return ServiceCaseDocument(
            id: _stringValue(item['id'] ?? item['name'] ?? item['document_id']),
            title: _stringValue(
              item['title'] ?? item['document_title'] ?? item['label'],
            ),
            type: _stringValue(item['type'] ?? item['document_type']),
            status: status == 'Required' ? 'Pending' : status,
            fileUrl: status.toLowerCase() == 'rejected' ? null : fileUrl,
            remarks: _nullableString(item['remarks'] ?? item['notes']),
          );
        })
        .where((item) => item.title.trim().isNotEmpty && item.title != '-')
        .toList(growable: false);
  }

  List<ServiceCasePayment> _paymentDetails(dynamic value) {
    if (value is! List) return const [];

    return value
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => ServiceCasePayment(
            id: _stringValue(item['id'] ?? item['name'] ?? item['payment_id']),
            title: _stringValue(
              item['title'] ?? item['payment_title'] ?? item['label'],
            ),
            status: _stringValue(item['status'] ?? item['payment_status']),
            amount: _moneyValue(item['amount'] ?? item['payment_amount']),
            currency: _stringValue(item['currency'] ?? 'PKR'),
            dueDateLabel: _nullableString(_displayDate(item['due_date'])),
            paidOnLabel: _nullableString(_displayDate(item['paid_on'])),
            paymentReference: _nullableString(item['payment_reference']),
            receiptUrl: _nullableString(
              item['receipt_url'] ??
                  item['receipt_attachment'] ??
                  item['attachment'],
            ),
            remarks: _nullableString(item['remarks'] ?? item['notes']),
          ),
        )
        .where((item) => item.title.trim().isNotEmpty && item.title != '-')
        .toList(growable: false);
  }

  List<ServiceCaseTimelineStep> _timeline(dynamic value) {
    if (value is! List) return const [];

    return value
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => ServiceCaseTimelineStep(
            title: _stringValue(
              item['title'] ??
                  item['stage_title'] ??
                  item['label'] ??
                  item['status'] ??
                  item['type'] ??
                  item['activity_type'] ??
                  item['event_type'],
            ),
            subtitle: _timelineSubtitle(item),
            isDone: _timelineStepIsDone(item),
          ),
        )
        .where((step) => step.title.trim().isNotEmpty && step.title != '-')
        .toList(growable: false);
  }

  String _timelineSubtitle(Map<String, dynamic> item) {
    final mainText = _nullableString(
      item['subtitle'] ??
          item['description'] ??
          item['message'] ??
          item['remarks'] ??
          item['expected_duration_label'],
    );

    final timestamp = _nullableString(
      item['created_at'] ??
          item['created_on'] ??
          item['creation'] ??
          item['date'] ??
          item['updated_at'] ??
          item['modified'] ??
          item['event_time'],
    );

    final formattedTimestamp = _nullableString(_displayDate(timestamp));

    if (mainText != null &&
        formattedTimestamp != null &&
        !mainText.contains(formattedTimestamp)) {
      return '$mainText\n$formattedTimestamp';
    }

    return mainText ?? formattedTimestamp ?? '-';
  }

  bool _timelineStepIsDone(Map<String, dynamic> item) {
    if (item['is_done'] == true || item['isDone'] == true) return true;
    if (item['completed'] == true || item['is_completed'] == true) return true;

    final status = _nullableString(
      item['status'] ?? item['state'] ?? item['completion_status'],
    )?.toLowerCase();

    return status == 'completed' ||
        status == 'complete' ||
        status == 'done' ||
        status == 'approved';
  }

  List<String> _stringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) {
            if (item is Map<String, dynamic>) {
              return _stringValue(
                item['title'] ?? item['document_title'] ?? item['label'],
              );
            }

            return item.toString().trim();
          })
          .where((item) => item.isNotEmpty && item != '-')
          .toList(growable: false);
    }

    return const [];
  }

  Set<String> _stringSet(dynamic value) {
    return _stringList(value).map((item) => item.toLowerCase()).toSet();
  }

  String _stringValue(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? '-' : text;
  }

  String? _nullableString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text == '-') return null;
    return text;
  }

  String _displayDate(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty || raw == '-') return '-';

    final alreadyClean =
        RegExp(r'^[0-9]{1,2} [A-Za-z]{3} [0-9]{4}').hasMatch(raw) ||
        RegExp(r'^[A-Za-z]+$').hasMatch(raw) ||
        raw.toLowerCase().contains('ago') ||
        raw.toLowerCase().contains('pending') ||
        raw.toLowerCase().contains('completed');
    if (alreadyClean) return raw;

    final withoutMicroseconds = raw.replaceFirst(RegExp(r'\.\d+'), '');
    final isoCandidate = withoutMicroseconds.contains('T')
        ? withoutMicroseconds
        : withoutMicroseconds.replaceFirst(' ', 'T');

    final parsed = DateTime.tryParse(isoCandidate);
    if (parsed == null) return withoutMicroseconds;

    return DateFormat('dd MMM yyyy, h:mm a').format(parsed.toLocal());
  }

  bool _boolValue(dynamic value) {
    if (value is bool) return value;
    final text = value?.toString().trim().toLowerCase();
    return text == 'true' || text == '1' || text == 'yes';
  }

  int? _nullableIntValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();

    final parsed = int.tryParse(value?.toString().trim() ?? '');
    return parsed;
  }

  double _doubleValue(dynamic value) {
    final number = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '') ?? 0;

    final normalized = number > 1 ? number / 100 : number;
    return normalized.clamp(0, 1).toDouble();
  }

  double _moneyValue(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  List<ServiceCase> sampleCasesForUiPreview() {
    return const [
      ServiceCase(
        id: 'case-001',
        reference: 'OMC-2026-001',
        title: 'Annual Income Tax Filing - Salaried',
        category: 'Income Tax Return',
        status: 'Waiting for Payment',
        requestState: 'Pending Payment',
        operationalStatus: 'Waiting for Payment',
        receipt: ServiceCaseReceipt(status: 'Not Submitted'),
        settlement: ServiceCaseSettlement(
          status: 'Unmatched',
          payableAmount: 5000,
          currency: 'PKR',
        ),
        activation: ServiceCaseActivation(state: 'Pending Payment'),
        createdAtLabel: 'Today',
        updatedAtLabel: 'Just now',
        progress: 0.35,
        nextStep: 'Please complete the pending payment or submit its receipt.',
        remarks: 'Upload any missing withholding certificates if available.',
        requiredDocuments: [
          'CNIC front image',
          'CNIC back image',
          'Salary certificate',
        ],
        submittedDocuments: [
          'CNIC front image',
          'CNIC back image',
          'Salary certificate',
        ],
        documentDetails: [
          ServiceCaseDocument(
            id: 'doc-001',
            title: 'CNIC front image',
            type: 'CNIC',
            status: 'Approved',
            fileUrl: '/files/cnic-front.jpg',
          ),
          ServiceCaseDocument(
            id: 'doc-002',
            title: 'CNIC back image',
            type: 'CNIC',
            status: 'Approved',
            fileUrl: '/files/cnic-back.jpg',
          ),
          ServiceCaseDocument(
            id: 'doc-003',
            title: 'Salary certificate',
            type: 'Tax',
            status: 'Approved',
            fileUrl: '/files/salary.pdf',
          ),
        ],
        paymentDetails: [
          ServiceCasePayment(
            id: 'pay-001',
            title: 'Service fee',
            status: 'Pending',
            amount: 5000,
            currency: 'PKR',
            dueDateLabel: 'Today',
          ),
        ],
        timeline: [
          ServiceCaseTimelineStep(
            title: 'Request Created',
            subtitle: 'Today',
            isDone: true,
          ),
          ServiceCaseTimelineStep(
            title: 'Documents Approved',
            subtitle: 'All required documents approved.',
            isDone: true,
          ),
          ServiceCaseTimelineStep(
            title: 'Payment Opened',
            subtitle: 'Service fee is pending.',
            isDone: false,
          ),
        ],
      ),
    ];
  }
}

class ServiceCasePageQuery {
  const ServiceCasePageQuery({this.start = 0, this.pageLength = 20});

  final int start;
  final int pageLength;

  @override
  bool operator ==(Object other) =>
      other is ServiceCasePageQuery &&
      other.start == start &&
      other.pageLength == pageLength;

  @override
  int get hashCode => Object.hash(start, pageLength);
}

class ServiceCasePage {
  const ServiceCasePage({
    required this.items,
    required this.start,
    required this.pageLength,
    required this.nextStart,
    required this.hasMore,
  });

  final List<ServiceCase> items;
  final int start;
  final int pageLength;
  final int? nextStart;
  final bool hasMore;
}
