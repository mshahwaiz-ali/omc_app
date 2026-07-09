import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/frappe_client.dart';
import 'document_attachment.dart';
import 'document_item.dart';

final documentsRepositoryProvider = Provider<DocumentsRepository>((ref) {
  final frappeClient = ref.watch(frappeClientProvider);

  return DocumentsRepository(frappeClient);
});

final documentsProvider = FutureProvider<List<DocumentItem>>((ref) async {
  final repository = ref.watch(documentsRepositoryProvider);
  return repository.fetchDocuments();
});

final documentDetailProvider = FutureProvider.family<DocumentItem?, String>((
  ref,
  documentId,
) {
  final repository = ref.watch(documentsRepositoryProvider);

  return repository.fetchDocumentDetail(documentId);
});

class DocumentsRepository {
  const DocumentsRepository(this._frappeClient);

  final FrappeClient _frappeClient;

  Future<List<DocumentItem>> fetchDocuments({
    bool? showArchived,
    String? queue,
    String? customer,
    String? serviceRequest,
    String? status,
  }) async {
    final queryParameters = <String, dynamic>{};

    if (showArchived != null) {
      queryParameters['show_archived'] = showArchived ? '1' : '0';
    }
    if (queue != null && queue.trim().isNotEmpty) {
      queryParameters['queue'] = queue.trim();
    }
    if (customer != null && customer.trim().isNotEmpty) {
      queryParameters['customer'] = customer.trim();
    }
    if (serviceRequest != null && serviceRequest.trim().isNotEmpty) {
      queryParameters['service_request'] = serviceRequest.trim();
    }
    if (status != null && status.trim().isNotEmpty) {
      queryParameters['status'] = status.trim();
    }

    final response = await _frappeClient.getMethod(
      ApiConfig.documentsMethod,
      queryParameters: queryParameters.isEmpty ? null : queryParameters,
    );
    return _mapDocumentsResponse(response);
  }

  Future<DocumentItem?> fetchDocumentDetail(String documentId) async {
    final cleanDocumentId = documentId.trim();
    if (cleanDocumentId.isEmpty) return null;

    final response = await _frappeClient.getMethod(
      ApiConfig.documentDetailMethod,
      queryParameters: {
        'document_id': cleanDocumentId,
        'name': cleanDocumentId,
      },
    );

    return _mapDocumentDetailResponse(response);
  }

  Future<void> updateServiceDocumentStatus({
    required String documentId,
    required String status,
    String? remarks,
  }) async {
    final cleanDocumentId = documentId.trim();
    final cleanStatus = status.trim();

    if (cleanDocumentId.isEmpty) {
      throw const ApiError(message: 'Missing document reference.');
    }
    if (cleanStatus.isEmpty) {
      throw const ApiError(message: 'Missing document status.');
    }

    await _frappeClient.postMethod(
      ApiConfig.updateServiceDocumentStatusMethod,
      data: {
        'document_id': cleanDocumentId,
        'status': cleanStatus,
        if (remarks != null) 'remarks': remarks.trim(),
      },
    );
  }

  Future<List<Map<String, dynamic>>> uploadDocumentAttachments({
    required String serviceRequestId,
    required List<DocumentAttachment> attachments,
  }) async {
    final cleanServiceRequestId = serviceRequestId.trim();
    if (cleanServiceRequestId.isEmpty) {
      throw const ApiError(
        message: 'Missing service request reference for upload.',
      );
    }

    final uploadableAttachments = attachments
        .where((attachment) => attachment.hasUploadPath)
        .toList(growable: false);

    if (uploadableAttachments.isEmpty) {
      throw const ApiError(
        message: 'Selected file is not available for upload on this device.',
      );
    }

    final uploadedFiles = <Map<String, dynamic>>[];

    for (final attachment in uploadableAttachments) {
      if (!attachment.hasUploadData) {
        continue;
      }

      final uploadResponse = await _frappeClient.uploadFile(
        filePath: attachment.path,
        fileBytes: attachment.bytes,
        fileName: attachment.name,
        doctype: ApiConfig.serviceRequestUploadDoctype,
        docname: cleanServiceRequestId,
      );

      final uploadedFileUrl = _extractFileUrl(uploadResponse);
      if (uploadedFileUrl == null) {
        throw const ApiError(
          message:
              'Document uploaded but the server did not return a file URL.',
        );
      }

      final response = await _frappeClient.postMethod(
        ApiConfig.uploadServiceDocumentMethod,
        data: {
          'case_id': cleanServiceRequestId,
          'request_id': cleanServiceRequestId,
          'service_request': cleanServiceRequestId,
          'name': cleanServiceRequestId,
          'document_title': attachment.name,
          'document_type': attachment.extension,
          'file_url': uploadedFileUrl,
          'attachment': uploadedFileUrl,
          'status': 'Uploaded',
          'source': 'Service Upload',
        },
      );

      uploadedFiles.add(response);
    }

    return uploadedFiles;
  }

  String? _extractFileUrl(Map<String, dynamic> response) {
    final message = response['message'];
    final data = message is Map<String, dynamic> ? message : response;

    final fileUrl =
        data['file_url'] ??
        data['fileurl'] ??
        data['url'] ??
        data['file'] ??
        data['file_name'];

    final text = fileUrl?.toString().trim();
    if (text == null || text.isEmpty) return null;

    return text;
  }

  List<DocumentItem> _mapDocumentsResponse(Map<String, dynamic>? data) {
    if (data == null) return const [];

    final message = data['message'];
    final rawDocuments = message is List
        ? message
        : message is Map<String, dynamic>
        ? message['documents'] ??
              message['document_list'] ??
              message['attachments'] ??
              message['files'] ??
              message['data'] ??
              message['items'] ??
              message['rows'] ??
              message['results'] ??
              message['records']
        : data['documents'] ??
              data['document_list'] ??
              data['attachments'] ??
              data['files'] ??
              data['data'] ??
              data['items'] ??
              data['rows'] ??
              data['results'] ??
              data['records'];

    if (rawDocuments is! List) return const [];

    return rawDocuments
        .whereType<Map<String, dynamic>>()
        .map(_mapDocument)
        .toList(growable: false);
  }

  DocumentItem? _mapDocumentDetailResponse(Map<String, dynamic>? data) {
    if (data == null) return null;

    final message = data['message'];
    final rawDocument = message is Map<String, dynamic>
        ? message['document'] ??
              message['attachment'] ??
              message['file'] ??
              message['document_detail'] ??
              message['data'] ??
              message['item'] ??
              message['record'] ??
              message
        : data['document'] ??
              data['attachment'] ??
              data['file'] ??
              data['document_detail'] ??
              data['data'] ??
              data['item'] ??
              data['record'];

    if (rawDocument is! Map<String, dynamic>) return null;

    return _mapDocument(rawDocument);
  }

  DocumentItem _mapDocument(Map<String, dynamic> json) {
    final title = _stringValue(
      json['title'] ?? json['document_title'] ?? json['document_name'],
    );
    final type = _nullableString(json['type'] ?? json['document_type']);
    final serviceTitle = _nullableString(json['service_title']);
    final serviceReference = _nullableString(
      json['service_reference'] ?? json['case_reference'] ?? json['case_id'],
    );

    return DocumentItem(
      id: _stringValue(json['id'] ?? json['name'] ?? json['document_id']),
      title: title,
      subtitle: _documentSubtitle(
        type: type,
        serviceTitle: serviceTitle,
        serviceReference: serviceReference,
      ),
      fileName: _nullableString(json['file_name'] ?? json['filename']),
      fileUrl: _nullableString(json['file_url'] ?? json['file'] ?? json['url']),
      previewUrl: _nullableString(
        json['preview_url'] ?? json['file_url'] ?? json['file'] ?? json['url'],
      ),
      downloadUrl: _nullableString(
        json['download_url'] ?? json['file_url'] ?? json['file'] ?? json['url'],
      ),
      updatedAtLabel: _nullableString(
        json['updated_at_label'] ??
            json['modified'] ??
            json['updated_at'] ??
            json['created_at'] ??
            json['uploaded_on'],
      ),
      serviceReference: serviceReference,
      serviceTitle: serviceTitle,
      serviceStatus: _nullableString(json['service_status']),
      source: _nullableString(json['source']),
      remarks: _nullableString(
        json['review_remarks'] ?? json['remarks'] ?? json['notes'],
      ),
      isArchived: _boolValue(json['is_archived'] ?? json['archived']),
      archivedOnLabel: _nullableString(json['archived_on']),
      archiveReason: _nullableString(json['archive_reason']),
      status: _statusFromValue(json['status']),
    );
  }

  String? _documentSubtitle({
    required String? type,
    required String? serviceTitle,
    required String? serviceReference,
  }) {
    final parts = [
      type,
      serviceTitle,
      serviceReference,
    ].where((value) => value != null && value.trim().isNotEmpty).toList();

    if (parts.isEmpty) return null;
    return parts.join(' · ');
  }

  DocumentStatus _statusFromValue(dynamic value) {
    final status = value?.toString().trim().toLowerCase() ?? '';

    if (status.contains('approve')) return DocumentStatus.approved;
    if (status.contains('reject')) return DocumentStatus.rejected;
    if (status.contains('missing') || status.contains('required')) {
      return DocumentStatus.missing;
    }
    if (status.contains('review') || status.contains('pending')) {
      return DocumentStatus.pendingReview;
    }
    if (status.contains('upload') || status.contains('submit')) {
      return DocumentStatus.uploaded;
    }

    return DocumentStatus.pendingReview;
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
    if (value is num) return value != 0;

    final text = value?.toString().trim().toLowerCase() ?? '';
    return text == '1' || text == 'true' || text == 'yes';
  }
}
