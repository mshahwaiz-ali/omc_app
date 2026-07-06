import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/frappe_client.dart';
import 'document_attachment.dart';
import 'document_item.dart';

final documentsRepositoryProvider = Provider<DocumentsRepository>((ref) {
  final frappeClient = ref.watch(frappeClientProvider);

  return DocumentsRepository(frappeClient: frappeClient);
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
  const DocumentsRepository({required this._frappeClient});

  final FrappeClient _frappeClient;

  Future<List<DocumentItem>> fetchDocuments() async {
    final response = await _frappeClient.getMethod(ApiConfig.documentsMethod);
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

  Future<List<Map<String, dynamic>>> uploadDocumentAttachments({
    required String documentId,
    required List<DocumentAttachment> attachments,
  }) async {
    final cleanDocumentId = documentId.trim();
    if (cleanDocumentId.isEmpty) {
      throw const ApiError(message: 'Missing document reference for upload.');
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
      final filePath = attachment.path;
      if (filePath == null || filePath.trim().isEmpty) {
        continue;
      }

      final uploadResponse = await _frappeClient.uploadFile(
        filePath: filePath,
        fileName: attachment.name,
        doctype: ApiConfig.documentUploadDoctype,
        docname: cleanDocumentId,
      );

      final uploadedFileUrl = _extractFileUrl(uploadResponse);
      if (uploadedFileUrl == null) {
        throw const ApiError(
          message: 'Document uploaded but the server did not return a file URL.',
        );
      }

      final response = await _frappeClient.postMethod(
        ApiConfig.uploadServiceDocumentMethod,
        data: {
          'case_id': cleanDocumentId,
          'document_title': attachment.name,
          'document_type': attachment.extension,
          'file_url': uploadedFileUrl,
          'attachment': uploadedFileUrl,
          'status': 'Uploaded',
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
        data['file_url'.replaceAll('_', '')] ??
        data['url'] ??
        data['file'];

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
        ? message['documents'] ?? message['data'] ?? message['items']
        : data['documents'] ?? data['data'] ?? data['items'];

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
        ? message['document'] ?? message['data'] ?? message['item'] ?? message
        : data['document'] ?? data['data'] ?? data['item'];

    if (rawDocument is! Map<String, dynamic>) return null;

    return _mapDocument(rawDocument);
  }

  DocumentItem _mapDocument(Map<String, dynamic> json) {
    return DocumentItem(
      id: _stringValue(json['id'] ?? json['name'] ?? json['document_id']),
      title: _stringValue(
        json['title'] ?? json['document_name'] ?? json['name'],
      ),
      subtitle: _nullableString(
        json['subtitle'] ?? json['description'] ?? json['type'],
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
      serviceReference: _nullableString(
        json['service_reference'] ?? json['case_reference'] ?? json['case_id'],
      ),
      remarks: _nullableString(json['remarks'] ?? json['notes']),
      status: _statusFromValue(json['status']),
    );
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
}
