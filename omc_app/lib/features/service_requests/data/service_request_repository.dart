import 'dart:convert';

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
    this.customerMode,
    this.customerConsentReference,
    this.city,
    this.address,
    this.discountType,
    this.discountValue,
    this.discountReason,
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
  final String? customerMode;
  final String? customerConsentReference;
  final String? city;
  final String? address;
  final String? discountType;
  final double? discountValue;
  final String? discountReason;

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

    final normalizedCustomerMode = customerMode?.trim();
    if (normalizedCustomerMode != null && normalizedCustomerMode.isNotEmpty) {
      data['customer_mode'] = normalizedCustomerMode;
    }

    final normalizedConsentReference = customerConsentReference?.trim();
    if (normalizedConsentReference != null &&
        normalizedConsentReference.isNotEmpty) {
      data['customer_consent_reference'] = normalizedConsentReference;
    }

    final normalizedCity = city?.trim();
    if (normalizedCity != null && normalizedCity.isNotEmpty) {
      data['city'] = normalizedCity;
    }

    final normalizedAddress = address?.trim();
    if (normalizedAddress != null && normalizedAddress.isNotEmpty) {
      data['address'] = normalizedAddress;
    }

    final normalizedDiscountType = discountType?.trim();
    final normalizedDiscountValue = discountValue ?? 0;
    final normalizedDiscountReason = discountReason?.trim();

    if (normalizedDiscountType != null &&
        normalizedDiscountType.isNotEmpty &&
        normalizedDiscountValue > 0) {
      data['discount_type'] = normalizedDiscountType;
      data['discount_value'] = normalizedDiscountValue;
      if (normalizedDiscountReason != null &&
          normalizedDiscountReason.isNotEmpty) {
        data['discount_reason'] = normalizedDiscountReason;
      }
    }

    final normalizedRemarks = remarks.trim();
    if (normalizedRemarks.isNotEmpty) {
      data['remarks'] = normalizedRemarks;
    }

    if (normalizedDetails.isNotEmpty) {
      data['service_details'] = normalizedDetails;
      data['additional_details'] = normalizedDetails;
      data['form_data'] = normalizedDetails;
      data['form_data_json'] = jsonEncode(normalizedDetails);
    }

    if (service.formSchema.isNotEmpty) {
      data['form_schema'] = service.formSchema
          .map(
            (field) => {
              'fieldname': field.fieldname,
              'label': field.label,
              'fieldtype': field.fieldtype,
              'required': field.isRequired,
            },
          )
          .toList(growable: false);
    }

    if (service.stages.isNotEmpty) {
      data['stage_template'] = service.stages
          .where((stage) => stage.isCustomerVisible)
          .map(
            (stage) => {
              'stage_key': stage.stageKey,
              'title': stage.title,
              'description': stage.description,
            },
          )
          .toList(growable: false);
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

    if (service.hasBackendTemplate) {
      if (lines.isNotEmpty) lines.add('');
      lines.add('Request form used backend service template configuration.');
    }

    return lines.join('\n').trim();
  }

  String _serviceDetailLabel(String key) {
    switch (key.trim()) {
      case 'ntn_cnic':
        return 'Tax ID';
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
      case 'form_data_json':
        return 'Form data';
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

class AssistedCustomerOption {
  const AssistedCustomerOption({
    required this.mode,
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    this.cnic = '',
    this.city = '',
    this.customerStatus = '',
    this.approvalStatus = '',
    this.consentGranted = false,
    this.isManualCustomer = false,
  });

  final String mode;
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String cnic;
  final String city;
  final String customerStatus;
  final String approvalStatus;
  final bool consentGranted;
  final bool isManualCustomer;

  factory AssistedCustomerOption.fromJson(Map<String, dynamic> json) {
    final manualId = _staticString(json['manual_customer_id']);
    final customerId = _staticString(json['customer_id']);

    return AssistedCustomerOption(
      mode: _staticString(json['customer_mode']),
      id: manualId.isNotEmpty ? manualId : customerId,
      fullName: _staticString(json['full_name']),
      email: _staticString(json['email']),
      phone: _staticString(json['phone']),
      cnic: _staticString(json['cnic']),
      city: _staticString(json['city']),
      customerStatus: _staticString(json['customer_status']),
      approvalStatus: _staticString(json['approval_status']),
      consentGranted: _staticBool(json['consent_granted']),
      isManualCustomer: manualId.isNotEmpty,
    );
  }

  String get subtitle {
    final parts = <String>[
      if (phone.isNotEmpty) phone,
      if (email.isNotEmpty) email,
      if (city.isNotEmpty) city,
    ];
    return parts.join(' • ');
  }
}

class AssistedCustomerSelection {
  const AssistedCustomerSelection({
    required this.modes,
    required this.items,
    this.selectedMode,
  });

  final List<String> modes;
  final List<AssistedCustomerOption> items;
  final String? selectedMode;

  factory AssistedCustomerSelection.fromResponse(
    Map<String, dynamic> response,
  ) {
    final message = response['message'];
    final source = message is Map<String, dynamic> ? message : response;
    final rawModes = source['modes'];
    final rawItems = source['items'];

    return AssistedCustomerSelection(
      modes: rawModes is List
          ? rawModes
                .map(_staticString)
                .where((value) => value.isNotEmpty)
                .toList(growable: false)
          : const [],
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map(
                  (item) => AssistedCustomerOption.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .where((item) => item.id.isNotEmpty)
                .toList(growable: false)
          : const [],
      selectedMode: _nullableStaticString(source['selected_mode']),
    );
  }
}

String _staticString(Object? value) => value?.toString().trim() ?? '';

String? _nullableStaticString(Object? value) {
  final text = _staticString(value);
  return text.isEmpty ? null : text;
}

bool _staticBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return const {
    '1',
    'true',
    'yes',
    'on',
  }.contains(_staticString(value).toLowerCase());
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

  Future<AssistedCustomerSelection> getAssistedCustomerSelection({
    String? customerMode,
    String? search,
    int limitStart = 0,
    int limitPageLength = 50,
  }) async {
    final queryParameters = <String, dynamic>{
      'limit_start': limitStart,
      'limit_page_length': limitPageLength,
    };

    final cleanMode = customerMode?.trim();
    final cleanSearch = search?.trim();
    if (cleanMode != null && cleanMode.isNotEmpty) {
      queryParameters['customer_mode'] = cleanMode;
    }
    if (cleanSearch != null && cleanSearch.isNotEmpty) {
      queryParameters['search'] = cleanSearch;
    }

    final response = await _frappeClient.getMethod(
      ApiConfig.assistedCustomerSelectionMethod,
      queryParameters: queryParameters,
    );

    return AssistedCustomerSelection.fromResponse(response);
  }

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
    String? documentTitle,
    String? documentType,
  }) async {
    final uploadedFiles = <Map<String, dynamic>>[];
    final cleanDocumentTitle = documentTitle?.trim();
    final cleanDocumentType = documentType?.trim();

    for (final attachment in attachments) {
      if (!attachment.hasUploadData) {
        continue;
      }

      final uploadResponse = await _frappeClient.uploadFile(
        filePath: attachment.path,
        fileBytes: attachment.bytes,
        fileName: attachment.name,
      );

      final uploadedFileUrl = _extractFileUrl(uploadResponse);
      if (uploadedFileUrl == null) {
        uploadedFiles.add(uploadResponse);
        continue;
      }

      final documentResponse = await _frappeClient.postMethod(
        ApiConfig.uploadServiceDocumentMethod,
        data: {
          'case_id': requestId,
          'request_id': requestId,
          'service_request': requestId,
          'name': requestId,
          'document_title':
              cleanDocumentTitle != null && cleanDocumentTitle.isNotEmpty
              ? cleanDocumentTitle
              : attachment.name,
          'document_type':
              cleanDocumentType != null && cleanDocumentType.isNotEmpty
              ? cleanDocumentType
              : attachment.extension ?? '',
          'attachment': uploadedFileUrl,
          'file_url': uploadedFileUrl,
        },
      );

      uploadedFiles.add(documentResponse);
    }

    return uploadedFiles;
  }

  String? _extractFileUrl(Map<String, dynamic> response) {
    final message = response['message'];
    final data = message is Map<String, dynamic> ? message : response;
    final fileUrl = data['file_url'] ?? data['url'] ?? data['file'];

    return _stringOrNull(fileUrl);
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
