import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/frappe_client.dart';
import '../../../core/network/mutation_intent.dart';
import '../../../core/uploads/upload_coordinator.dart';
import 'document_attachment.dart';
import 'document_item.dart';

class AuthenticatedDocumentFile {
  const AuthenticatedDocumentFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

class DocumentPage {
  const DocumentPage({
    required this.items,
    required this.start,
    required this.pageLength,
    required this.hasMore,
    required this.nextStart,
  });

  const DocumentPage.empty()
    : items = const [],
      start = 0,
      pageLength = 20,
      hasMore = false,
      nextStart = null;

  final List<DocumentItem> items;
  final int start;
  final int pageLength;
  final bool hasMore;
  final int? nextStart;
}

final documentsRepositoryProvider = Provider<DocumentsRepository>((ref) {
  final frappeClient = ref.watch(frappeClientProvider);

  return DocumentsRepository(frappeClient);
});

final documentPageProvider = FutureProvider<DocumentPage>((ref) async {
  final repository = ref.watch(documentsRepositoryProvider);
  return repository.fetchDocumentPage();
});

final assistedDocumentPageProvider =
    FutureProvider.family<DocumentPage, String>((ref, serviceRequest) async {
      final repository = ref.watch(documentsRepositoryProvider);
      return repository.fetchDocumentPage(
        serviceRequest: serviceRequest,
        assisted: true,
      );
    });

// Compatibility providers for callers that do not need pagination controls.
// New list screens should consume DocumentPage so has_more is never discarded.
final documentsProvider = FutureProvider<List<DocumentItem>>((ref) async {
  return (await ref.watch(documentPageProvider.future)).items;
});

final assistedDocumentsProvider =
    FutureProvider.family<List<DocumentItem>, String>((
      ref,
      serviceRequest,
    ) async {
      return (await ref.watch(assistedDocumentPageProvider(serviceRequest).future))
          .items;
    });

final documentDetailProvider = FutureProvider.family<DocumentItem?, String>((
  ref,
  documentId,
) {
  final repository = ref.watch(documentsRepositoryProvider);

  return repository.fetchDocumentDetail(documentId);
});

final assistedDocumentDetailProvider =
    FutureProvider.family<DocumentItem?, String>((ref, documentId) {
      final repository = ref.watch(documentsRepositoryProvider);

      return repository.fetchDocumentDetail(documentId, assisted: true);
    });

class DocumentsRepository {
  DocumentsRepository(FrappeClient frappeClient)
    : _frappeClient = frappeClient,
      _uploadCoordinator = UploadCoordinator(frappeClient);

  final FrappeClient _frappeClient;
  final UploadCoordinator _uploadCoordinator;
  final Map<String, MutationIntent> _uploadIntents = {};

  Future<DocumentPage> fetchDocumentPage({
    bool? showArchived,
    String? queue,
    String? customer,
    String? serviceRequest,
    String? status,
    bool assisted = false,
    int start = 0,
    int limit = 20,
  }) async {
    final safeStart = start < 0 ? 0 : start;
    final safeLimit = limit.clamp(1, 100);
    final queryParameters = <String, dynamic>{
      'limit_start': safeStart,
      'limit_page_length': safeLimit,
    };

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
    if (assisted) {
      queryParameters['assisted'] = '1';
    }

    final response = await _frappeClient.getMethod(
      ApiConfig.documentsMethod,
      queryParameters: queryParameters,
    );
    return _mapDocumentPageResponse(
      response,
      requestedStart: safeStart,
      requestedLimit: safeLimit,
    );
  }

  Future<List<DocumentItem>> fetchDocuments({
    bool? showArchived,
    String? queue,
    String? customer,
    String? serviceRequest,
    String? status,
    bool assisted = false,
    int start = 0,
    int limit = 20,
  }) async {
    return (
      await fetchDocumentPage(
        showArchived: showArchived,
        queue: queue,
        customer: customer,
        serviceRequest: serviceRequest,
        status: status,
        assisted: assisted,
        start: start,
        limit: limit,
      )
    ).items;
  }

  Future<DocumentItem?> fetchDocumentDetail(
    String documentId, {
    bool assisted = false,
  }) async {
    final cleanDocumentId = documentId.trim();
    if (cleanDocumentId.isEmpty) return null;

    final response = await _frappeClient.getMethod(
      ApiConfig.documentDetailMethod,
      queryParameters: {
        'document_id': cleanDocumentId,
        'name': cleanDocumentId,
        if (assisted) 'assisted': '1',
      },
    );

    return _mapDocumentDetailResponse(response);
  }

  Future<AuthenticatedDocumentFile> downloadDocument(
    DocumentItem document,
  ) async {
    final location =
        (document.previewUrl ?? document.fileUrl ?? document.downloadUrl)
            ?.trim() ??
        '';

    if (location.isEmpty) {
      throw const ApiError(
        message: 'No uploaded file is attached to this document.',
      );
    }

    final uri = Uri.tryParse(location);
    final name = uri?.pathSegments.isNotEmpty == true
        ? Uri.decodeComponent(uri!.pathSegments.last)
        : 'document-file';

    return AuthenticatedDocumentFile(
      name: name.isEmpty ? 'document-file' : name,
      bytes: await _frappeClient.getAuthenticatedFile(location),
    );
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

      final uploadResponse = await _uploadCoordinator.upload(
        filePath: attachment.path,
        fileBytes: attachment.bytes,
        fileName: attachment.name,
        sizeBytes: attachment.sizeInBytes,
        policy: const UploadPolicy(
          allowedExtensions: {'pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'},
          maxSizeBytes: 10 * 1024 * 1024,
        ),
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

      final data = {
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
      };
      final intent = _uploadIntents.putIfAbsent(
        '$cleanServiceRequestId:${attachment.id}',
        MutationIntent.new,
      );
      final key = intent.keyFor({
        'case_id': cleanServiceRequestId,
        'attachment_id': attachment.id,
        'file_name': attachment.name,
        'file_size': attachment.sizeInBytes,
      });
      final response = await _frappeClient.postMethod(
        ApiConfig.uploadServiceDocumentMethod,
        data: {...data, 'idempotency_key': key},
        idempotencyKey: key,
      );

      uploadedFiles.add(response);
      intent.complete();
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

  DocumentPage _mapDocumentPageResponse(
    Map<String, dynamic>? data, {
    required int requestedStart,
    required int requestedLimit,
  }) {
    if (data == null) {
      return DocumentPage(
        items: const [],
        start: requestedStart,
        pageLength: requestedLimit,
        hasMore: false,
        nextStart: null,
      );
    }

    final items = _mapDocumentsResponse(data);
    final message = data['message'];
    final payload = message is Map<String, dynamic> ? message : data;
    final hasMore = _boolValue(payload['has_more']);
    final start = _intValue(payload['limit_start']) ?? requestedStart;
    final pageLength =
        _intValue(payload['limit_page_length']) ?? requestedLimit;
    final parsedNextStart = _intValue(payload['next_start']);

    return DocumentPage(
      items: items,
      start: start,
      pageLength: pageLength,
      hasMore: hasMore,
      nextStart: hasMore ? (parsedNextStart ?? start + items.length) : null,
    );
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
      requestTitle: _nullableString(json['request_title']),
      serviceTitle: serviceTitle,
      serviceStatus: _nullableString(json['service_status']),
      documentType: type,
      customerProfile: _nullableString(json['customer_profile']),
      customerName: _nullableString(json['customer_name'] ?? json['full_name']),
      customerEmail: _nullableString(json['contact_email'] ?? json['email']),
      customerPhone: _nullableString(json['contact_phone'] ?? json['phone']),
      customerNtn: _nullableString(json['ntn'] ?? json['customer_ntn']),
      customerCnic: _nullableString(json['cnic'] ?? json['customer_cnic']),
      companyName: _nullableString(json['company_name']),
      customerType: _nullableString(json['customer_type']),
      source: _nullableString(json['source']),
      uploadedBy: _nullableString(json['uploaded_by']),
      reviewedBy: _nullableString(json['reviewed_by']),
      reviewedOnLabel: _nullableString(json['reviewed_on']),
      canReviewDocuments: _boolValue(json['can_review_documents']),
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

  int? _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
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
