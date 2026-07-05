import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/config/env.dart';
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
    // Backend-first hook.
    // TODO(backend): replace endpoint/mapping with confirmed OMC Frappe API.
    //
    // Expected responsibility:
    // - call authenticated Frappe endpoint
    // - map backend case/request records into ServiceCase
    // - never create fake production cases locally
    final response = await _frappeClient.getMethod(
      ApiConfig.serviceCasesMethod,
    );

    return _mapServiceCasesResponse(response);
  }

  Future<ServiceCase?> fetchServiceCaseDetail(String caseId) async {
    // Backend-first hook.
    // TODO(backend): replace endpoint/mapping with confirmed OMC Frappe API.
    final response = await _frappeClient.getMethod(
      ApiConfig.serviceCaseDetailMethod,
      queryParameters: {'case_id': caseId},
    );

    final cases = _mapServiceCasesResponse(response);
    if (cases.isEmpty) return null;

    return cases.first;
  }

  List<ServiceCase> _mapServiceCasesResponse(Map<String, dynamic>? data) {
    if (data == null) return const [];

    final message = data['message'];
    final rawCases = message is List
        ? message
        : message is Map<String, dynamic>
        ? message['cases']
        : data['cases'];

    if (rawCases is! List) return const [];

    return rawCases
        .whereType<Map<String, dynamic>>()
        .map(_mapServiceCase)
        .toList(growable: false);
  }

  ServiceCase _mapServiceCase(Map<String, dynamic> json) {
    return ServiceCase(
      id: _stringValue(json['id'] ?? json['name'] ?? json['case_id']),
      reference: _nullableString(json['reference'] ?? json['case_reference']),
      title: _stringValue(json['title'] ?? json['service_title']),
      category: _stringValue(json['category'] ?? json['service_category']),
      status: _stringValue(json['status']),
      createdAtLabel: _stringValue(json['created_at_label'] ?? json['created']),
      updatedAtLabel: _stringValue(
        json['updated_at_label'] ?? json['modified'],
      ),
      progress: _doubleValue(json['progress']),
      nextStep: _nullableString(json['next_step']),
      remarks: _nullableString(json['remarks']),
      requiredDocuments: _stringList(json['required_documents']),
      submittedDocuments: _stringList(json['submitted_documents']),
      missingDocuments: _stringList(json['missing_documents']),
      timeline: _timeline(json['timeline']),
    );
  }

  List<ServiceCaseTimelineStep> _timeline(dynamic value) {
    if (value is! List) return const [];

    return value
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => ServiceCaseTimelineStep(
            title: _stringValue(item['title']),
            subtitle: _stringValue(item['subtitle']),
            isDone: item['is_done'] == true || item['isDone'] == true,
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
