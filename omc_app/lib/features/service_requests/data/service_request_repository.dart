import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/frappe_client.dart';
import '../../documents/data/document_attachment.dart';
import '../../service_catalogue/data/service_item.dart';

final serviceRequestRepositoryProvider = Provider<ServiceRequestRepository>((ref) {
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
    required this.attachments,
  });

  final ServiceItem service;
  final String fullName;
  final String phone;
  final String email;
  final String taxId;
  final String remarks;
  final List<DocumentAttachment> attachments;

  Map<String, dynamic> toJson() {
    return {
      'service_id': service.id,
      'service_title': service.title,
      'service_category': service.category,
      'full_name': fullName,
      'phone': phone,
      'email': email,
      'tax_id': taxId,
      'remarks': remarks,
      'attachments': attachments
          .map(
            (attachment) => {
              'file_name': attachment.name,
              'file_size': attachment.sizeInBytes,
              'file_extension': attachment.extension,
            },
          )
          .toList(growable: false),
    };
  }
}

class ServiceRequestResult {
  const ServiceRequestResult({
    required this.raw,
    this.requestId,
  });

  final Map<String, dynamic> raw;
  final String? requestId;
}

class ServiceRequestRepository {
  const ServiceRequestRepository({
    required FrappeClient frappeClient,
  }) : this._(frappeClient);

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
        doctype: 'Service Request',
        docname: requestId,
      );

      uploadedFiles.add(response);
    }

    return uploadedFiles;
  }

  String? _extractRequestId(Map<String, dynamic> response) {
    final message = response['message'];

    if (message is String && message.trim().isNotEmpty) {
      return message.trim();
    }

    if (message is Map<String, dynamic>) {
      final candidates = [
        message['name'],
        message['request_id'],
        message['service_request'],
      ];

      for (final candidate in candidates) {
        if (candidate is String && candidate.trim().isNotEmpty) {
          return candidate.trim();
        }
      }
    }

    final data = response['data'];
    if (data is Map<String, dynamic>) {
      final name = data['name'];
      if (name is String && name.trim().isNotEmpty) {
        return name.trim();
      }
    }

    return null;
  }
}