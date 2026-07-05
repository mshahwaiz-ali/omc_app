import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/frappe_client.dart';
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
    try {
      final response = await _frappeClient.getMethod(ApiConfig.documentsMethod);
      return _mapDocumentsResponse(response);
    } on ApiError {
      return const [];
    } catch (_) {
      return const [];
    }
  }

  Future<DocumentItem?> fetchDocumentDetail(String documentId) async {
    final cleanDocumentId = documentId.trim();
    if (cleanDocumentId.isEmpty) return null;

    try {
      final response = await _frappeClient.getMethod(
        ApiConfig.documentDetailMethod,
        queryParameters: {
          'document_id': cleanDocumentId,
          'name': cleanDocumentId,
        },
      );

      return _mapDocumentDetailResponse(response);
    } on ApiError {
      return null;
    } catch (_) {
      return null;
    }
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
      subtitle: _nullableString(json['subtitle'] ?? json['description']),
      fileName: _nullableString(json['file_name'] ?? json['filename']),
      updatedAtLabel: _nullableString(
        json['updated_at_label'] ?? json['modified'] ?? json['updated_at'],
      ),
      serviceReference: _nullableString(
        json['service_reference'] ?? json['case_reference'],
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
