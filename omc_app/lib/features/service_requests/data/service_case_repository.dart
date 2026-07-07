import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/config/env.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/frappe_client.dart';
import 'service_case.dart';

final serviceCaseRepositoryProvider = Provider<ServiceCaseRepository>((ref) {
  final frappeClient = ref.watch(frappeClientProvider);

  return ServiceCaseRepository(frappeClient: frappeClient);
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
  const ServiceCaseRepository({required this._frappeClient});

  final FrappeClient _frappeClient;

  Future<List<ServiceCase>> fetchServiceCases() async {
    try {
      final response = await _frappeClient.getMethod(
        ApiConfig.serviceCasesMethod,
      );

      return _mapServiceCasesResponse(response);
    } on ApiError catch (error) {
      throw _trackingApiUnavailable(error);
    } catch (error) {
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
              message['rows']
        : data['cases'] ??
              data['service_cases'] ??
              data['requests'] ??
              data['data'] ??
              data['items'] ??
              data['rows'];

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
              message
        : data['case'] ??
              data['service_case'] ??
              data['request'] ??
              data['service_request'];

    if (rawCase is Map<String, dynamic>) {
      return [_mapServiceCase(rawCase)];
    }

    return const [];
  }

  ServiceCase _mapServiceCase(Map<String, dynamic> json) {
    return ServiceCase(
      id: _stringValue(json['id'] ?? json['name'] ?? json['case_id']),
      reference: _nullableString(
        json['reference'] ??
            json['case_reference'] ??
            json['service_request'] ??
            json['request_id'],
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
      status: _stringValue(json['status']),
      createdAtLabel: _stringValue(
        json['created_at_label'] ?? json['created'] ?? json['creation'],
      ),
      updatedAtLabel: _stringValue(
        json['updated_at_label'] ?? json['modified'],
      ),
      progress: _doubleValue(json['progress'] ?? json['progress_percent']),
      nextStep: _nullableString(json['next_step'] ?? json['next_action']),
      remarks: _nullableString(json['remarks']),
      requiredDocuments: _stringList(json['required_documents']),
      submittedDocuments: _stringList(json['submitted_documents']),
      missingDocuments: _stringList(json['missing_documents']),
      documentDetails: _documentDetails(
        json['submitted_documents'] ??
            json['required_documents'] ??
            json['missing_documents'],
      ),
      timeline: _timeline(
        json['timeline'] ?? json['activity'] ?? json['recent_activity'],
      ),
      canUpdateStatus: _boolValue(json['can_update_status']),
      canReviewDocuments: _boolValue(json['can_review_documents']),
      canViewInternalNotes: _boolValue(json['can_view_internal_notes']),
    );
  }

  List<ServiceCaseDocument> _documentDetails(dynamic value) {
    if (value is! List) return const [];

    return value
        .whereType<Map<String, dynamic>>()
        .map((item) {
          return ServiceCaseDocument(
            id: _stringValue(item['id'] ?? item['name'] ?? item['document_id']),
            title: _stringValue(
              item['title'] ?? item['document_title'] ?? item['label'],
            ),
            type: _stringValue(item['type'] ?? item['document_type']),
            status: _stringValue(item['status']),
            fileUrl: _nullableString(
              item['file_url'] ?? item['attachment'] ?? item['url'],
            ),
            remarks: _nullableString(item['remarks'] ?? item['notes']),
          );
        })
        .toList(growable: false);
  }

  List<ServiceCaseTimelineStep> _timeline(dynamic value) {
    if (value is! List) return const [];

    return value
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => ServiceCaseTimelineStep(
            title: _stringValue(
              item['title'] ?? item['status'] ?? item['activity_type'],
            ),
            subtitle: _stringValue(
              item['subtitle'] ??
                  item['description'] ??
                  item['remarks'] ??
                  item['creation'],
            ),
            isDone:
                item['is_done'] == true ||
                item['isDone'] == true ||
                item['status'] == 'Completed',
          ),
        )
        .toList(growable: false);
  }

  List<String> _stringList(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList(growable: false);
    }

    return const [];
  }

  String _stringValue(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? '-' : text;
  }

  String? _nullableString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  bool _boolValue(dynamic value) {
    if (value is bool) return value;
    final text = value?.toString().trim().toLowerCase();
    return text == 'true' || text == '1' || text == 'yes';
  }

  double _doubleValue(dynamic value) {
    if (value is num) return value.toDouble().clamp(0, 1);
    final parsed = double.tryParse(value?.toString() ?? '');
    return (parsed ?? 0).clamp(0, 1);
  }

  List<ServiceCase> sampleCasesForUiPreview() {
    return const [
      ServiceCase(
        id: 'case-001',
        reference: 'OMC-2026-001',
        title: 'Annual Income Tax Filing - Salaried',
        category: 'Income Tax Return',
        status: 'In Review',
        createdAtLabel: 'Today',
        updatedAtLabel: 'Just now',
        progress: 0.35,
        nextStep: 'OMC team is reviewing your salary and tax documents.',
        remarks: 'Upload any missing withholding certificates if available.',
        requiredDocuments: [
          'CNIC front image',
          'CNIC back image',
          'Salary certificate',
          'Tax deduction certificates',
          'Bank statement if required',
        ],
        submittedDocuments: [
          'CNIC front image',
          'CNIC back image',
          'Salary certificate',
        ],
        missingDocuments: [
          'Tax deduction certificates',
          'Bank statement if required',
        ],
        timeline: [
          ServiceCaseTimelineStep(
            title: 'Request received',
            subtitle: 'Today',
            isDone: true,
          ),
          ServiceCaseTimelineStep(
            title: 'Documents review',
            subtitle: 'In progress',
            isDone: true,
          ),
          ServiceCaseTimelineStep(
            title: 'OMC processing',
            subtitle: 'Pending',
            isDone: false,
          ),
          ServiceCaseTimelineStep(
            title: 'Completed',
            subtitle: 'Pending',
            isDone: false,
          ),
        ],
      ),
      ServiceCase(
        id: 'case-002',
        reference: 'OMC-2026-002',
        title: 'NTN Registration',
        category: 'NTN Registration',
        status: 'Documents Required',
        createdAtLabel: 'Yesterday',
        updatedAtLabel: '2 hours ago',
        progress: 0.55,
        nextStep: 'CNIC back image is required to continue.',
        remarks: 'Please upload a clear CNIC back image.',
        requiredDocuments: [
          'CNIC front image',
          'CNIC back image',
          'Mobile number linked with CNIC',
          'Email address',
        ],
        submittedDocuments: [
          'CNIC front image',
          'Mobile number linked with CNIC',
          'Email address',
        ],
        missingDocuments: ['CNIC back image'],
        timeline: [
          ServiceCaseTimelineStep(
            title: 'Request received',
            subtitle: 'Yesterday',
            isDone: true,
          ),
          ServiceCaseTimelineStep(
            title: 'Basic details checked',
            subtitle: 'Completed',
            isDone: true,
          ),
          ServiceCaseTimelineStep(
            title: 'Documents required',
            subtitle: 'CNIC back image pending',
            isDone: true,
          ),
          ServiceCaseTimelineStep(
            title: 'Submitted to FBR',
            subtitle: 'Pending',
            isDone: false,
          ),
        ],
      ),
      ServiceCase(
        id: 'case-003',
        reference: 'OMC-2026-003',
        title: 'IRIS Profile Update',
        category: 'IRIS Profile',
        status: 'Completed',
        createdAtLabel: 'Last week',
        updatedAtLabel: 'Completed',
        progress: 1,
        nextStep: 'No action required.',
        remarks: 'Your IRIS profile update has been completed.',
        requiredDocuments: [
          'CNIC front and back',
          'IRIS login details',
          'Updated contact information',
        ],
        submittedDocuments: [
          'CNIC front and back',
          'IRIS login details',
          'Updated contact information',
        ],
        missingDocuments: [],
        timeline: [
          ServiceCaseTimelineStep(
            title: 'Request received',
            subtitle: 'Last week',
            isDone: true,
          ),
          ServiceCaseTimelineStep(
            title: 'Documents verified',
            subtitle: 'Completed',
            isDone: true,
          ),
          ServiceCaseTimelineStep(
            title: 'Profile updated',
            subtitle: 'Completed',
            isDone: true,
          ),
          ServiceCaseTimelineStep(
            title: 'Completed',
            subtitle: 'Completed',
            isDone: true,
          ),
        ],
      ),
    ];
  }
}
