import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/config/env.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/frappe_client.dart';
import '../../../core/storage/json_cache_service.dart';
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
  );
});

final serviceCasesProvider = FutureProvider<List<ServiceCase>>((ref) async {
  final repository = ref.watch(serviceCaseRepositoryProvider);

  if (Env.useServicePreview) {
    return repository.sampleCasesForUiPreview();
  }

  return repository.fetchServiceCases();
});

final serviceCaseDetailProvider = FutureProvider.family<ServiceCase?, String>((
  ref,
  caseId,
) async {
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
  }) : this._(frappeClient, cacheService);

  const ServiceCaseRepository._(this._frappeClient, this._cacheService);

  static const String _serviceCasesCacheKey = 'service_cases_cache_v1';

  final FrappeClient _frappeClient;
  final JsonCacheService? _cacheService;

  Future<List<ServiceCase>> fetchServiceCases() async {
    try {
      final response = await _frappeClient.getMethod(
        ApiConfig.serviceCasesMethod,
      );

      await _cacheService?.saveMap(_serviceCasesCacheKey, response);

      return _mapServiceCasesResponse(response);
    } on ApiError catch (error) {
      final cachedResponse = _cacheService?.readMap(_serviceCasesCacheKey);
      if (cachedResponse != null) {
        return _mapServiceCasesResponse(cachedResponse);
      }

      throw _trackingApiUnavailable(error);
    } catch (error) {
      final cachedResponse = _cacheService?.readMap(_serviceCasesCacheKey);
      if (cachedResponse != null) {
        return _mapServiceCasesResponse(cachedResponse);
      }

      throw _trackingApiUnavailable(error);
    }
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
      status: _stringValue(json['status'] ?? json['current_stage']),
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
        json['next_step'] ?? json['next_action'] ?? json['customer_next_step'],
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
      customerName: _nullableString(json['customer_name'] ?? json['full_name']),
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
    );
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
                ? 'Pending'
                : 'Pending',
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
            status: 'Open',
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
