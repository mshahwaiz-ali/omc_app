import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/frappe_client.dart';
import '../../documents/data/document_attachment.dart';
import '../../service_catalogue/data/service_item.dart';

final serviceRequestRepositoryProvider = Provider<ServiceRequestRepository>((
  ref,
) {
  return ServiceRequestRepository(
    frappeClient: ref.watch(frappeClientProvider),
  );
});

class ServiceRequestPayload {
  const ServiceRequestPayload({
    required this.service,
    required this.fullName,
    required this.phone,
    required this.email,
    required this.taxId,
    required this.remarks,
    required this.additionalDetails,
    required this.attachments,
    this.customerId,
    this.customerName,
  });

  final ServiceItem service;
  final String fullName;
  final String phone;
  final String email;
  final String taxId;
  final String remarks;
  final Map<String, String> additionalDetails;
  final List<DocumentAttachment> attachments;
  final String? customerId;
  final String? customerName;

  Map<String, dynamic> toJson() {
    final normalizedDetails = _normalizedAdditionalDetails();
    final normalizedEmail = email.trim();
    final normalizedPhone = phone.trim();

    final data = <String, dynamic>{
      'service_id': service.id.trim(),
      'service_title': service.title.trim(),
      'service_category': service.category.trim(),
      'title': service.title.trim(),
      'full_name': fullName.trim(),
      'phone': normalizedPhone,
      'contact_phone': normalizedPhone,
      'email': normalizedEmail,
      'contact_email': normalizedEmail,
      'description': _buildRequestDescription(normalizedDetails),
    };

    final normalizedWizardType = service.wizardType?.trim();
    if (normalizedWizardType != null && normalizedWizardType.isNotEmpty) {
      data['wizard_type'] = normalizedWizardType;
    }

    final normalizedTaxId = taxId.trim();
    if (normalizedTaxId.isNotEmpty) {
      data['tax_id'] = normalizedTaxId;
    }

    final normalizedCustomerId = customerId?.trim();
    if (normalizedCustomerId != null && normalizedCustomerId.isNotEmpty) {
      data['customer_id'] = normalizedCustomerId;
      data['customer'] = normalizedCustomerId;
    }

    final normalizedCustomerName = customerName?.trim();
    if (normalizedCustomerName != null && normalizedCustomerName.isNotEmpty) {
      data['customer_name'] = normalizedCustomerName;
    }

    final normalizedRemarks = remarks.trim();
    if (normalizedRemarks.isNotEmpty) {
      data['remarks'] = normalizedRemarks;
    }

    if (normalizedDetails.isNotEmpty) {
      data['service_details'] = normalizedDetails;
    }

    if (attachments.isNotEmpty) {
      data['attachments'] = attachments
          .map(
            (attachment) => {
              'file_name': attachment.name,
              'file_size': attachment.sizeInBytes,
              'file_extension': attachment.extension,
            },
          )
          .toList(growable: false);
    }

    return data;
  }

  Map<String, String> _normalizedAdditionalDetails() {
    final normalizedDetails = <String, String>{};
    for (final entry in additionalDetails.entries) {
      final key = entry.key.trim();
      final value = entry.value.trim();

      if (key.isNotEmpty && value.isNotEmpty) {
        normalizedDetails[key] = value;
      }
    }

    return normalizedDetails;
  }

  String _buildRequestDescription(Map<String, String> normalizedDetails) {
    final lines = <String>[];
    final normalizedRemarks = remarks.trim();

    if (normalizedRemarks.isNotEmpty) {
      lines.add(normalizedRemarks);
    }

    if (normalizedDetails.isNotEmpty) {
      if (lines.isNotEmpty) lines.add('');
      lines.add('Service details:');
      for (final entry in normalizedDetails.entries) {
        lines.add('- ${_serviceDetailLabel(entry.key)}: ${entry.value}');
      }
    }

    if (service.wizardConfig.isNotEmpty) {
      if (lines.isNotEmpty) lines.add('');
      lines.add('Request form used backend wizard configuration.');
    }

    return lines.join('\n').trim();
  }

  String _serviceDetailLabel(String key) {
    switch (key.trim()) {
      case 'ntn_cnic':
        return 'CNIC';
      case 'occupation':
        return 'Occupation';
      case 'source_of_income':
        return 'Source of income';
      case 'iris_income_source':
        return 'IRIS income source';
      case 'gst_business_type':
        return 'GST business type';
      case 'gst_business_nature':
        return 'GST business nature';
      case 'consumer_number':
        return 'Consumer number';
      case 'business_option':
        return 'Business option';
      case 'business_context':
        return 'Business context';
      default:
        return key
            .trim()
            .replaceAll('_', ' ')
            .split(' ')
            .where((word) => word.isNotEmpty)
            .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
            .join(' ');
    }
  }
}

class ServiceRequestResult {
  const ServiceRequestResult({required this.raw, this.requestId});

  final Map<String, dynamic> raw;
  final String? requestId;
}

class ServiceRequestRepository {
  const ServiceRequestRepository({required FrappeClient frappeClient})
    : this._(frappeClient);

  const ServiceRequestRepository._(this._frappeClient);

  final FrappeClient _frappeClient;

  Future<ServiceRequestResult> createServiceRequest(
    ServiceRequestPayload payload,
  ) async {
    final response = await _frappeClient.postMethod(
      ApiConfig.createServiceMethod,
      data: payload.toJson(),
    );

    return ServiceRequestResult(
      raw: response,
      requestId: _extractRequestId(response),
    );
  }

  Future<List<Map<String, dynamic>>> uploadRequestAttachments({
    required String requestId,
    required List<DocumentAttachment> attachments,
  }) async {
    final uploadedFiles = <Map<String, dynamic>>[];

    for (final attachment in attachments) {
      final filePath = attachment.path;
      if (filePath == null || filePath.trim().isEmpty) {
        continue;
      }

      final response = await _frappeClient.uploadFile(
        filePath: filePath,
        fileName: attachment.name,
        doctype: ApiConfig.serviceRequestUploadDoctype,
        docname: requestId,
      );

      uploadedFiles.add(response);
    }

    return uploadedFiles;
  }

  String? _extractRequestId(Map<String, dynamic> response) {
    final directCandidates = [
      response['name'],
      response['request_id'],
      response['service_request'],
      response['service_request_id'],
      response['case_id'],
      response['reference'],
      response['docname'],
    ];

    for (final candidate in directCandidates) {
      final value = _stringOrNull(candidate);
      if (value != null) return value;
    }

    final message = response['message'];

    final messageValue = _stringOrNull(message);
    if (messageValue != null) return messageValue;

    if (message is Map<String, dynamic>) {
      final nestedCandidates = [
        message['name'],
        message['request_id'],
        message['service_request'],
        message['service_request_id'],
        message['case_id'],
        message['reference'],
        message['docname'],
      ];

      for (final candidate in nestedCandidates) {
        final value = _stringOrNull(candidate);
        if (value != null) return value;
      }
    }

    final data = response['data'];
    if (data is Map<String, dynamic>) {
      final dataCandidates = [
        data['name'],
        data['request_id'],
        data['service_request'],
        data['service_request_id'],
        data['case_id'],
        data['reference'],
        data['docname'],
      ];

      for (final candidate in dataCandidates) {
        final value = _stringOrNull(candidate);
        if (value != null) return value;
      }
    }

    return null;
  }

  String? _stringOrNull(Object? value) {
    if (value == null) return null;

    final text = value.toString().trim();
    if (text.isEmpty) return null;

    return text;
  }
}
