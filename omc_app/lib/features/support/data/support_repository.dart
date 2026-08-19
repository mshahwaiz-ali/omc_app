import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/frappe_client.dart';
import '../../../core/network/mutation_intent.dart';
import '../../../core/uploads/upload_coordinator.dart';
import 'support_config_data.dart';
import 'support_ticket.dart';

class SupportTicketPage {
  const SupportTicketPage({
    required this.items,
    required this.start,
    required this.pageLength,
    required this.hasMore,
    required this.nextStart,
  });

  const SupportTicketPage.empty()
    : items = const [],
      start = 0,
      pageLength = 20,
      hasMore = false,
      nextStart = null;

  final List<SupportTicket> items;
  final int start;
  final int pageLength;
  final bool hasMore;
  final int? nextStart;
}

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  final frappeClient = ref.watch(frappeClientProvider);

  return SupportRepository(frappeClient: frappeClient);
});

final supportConfigProvider = FutureProvider<SupportConfigData>((ref) async {
  final repository = ref.watch(supportRepositoryProvider);
  return repository.fetchSupportConfig();
});

final supportTicketPageProvider = FutureProvider<SupportTicketPage>((ref) async {
  final repository = ref.watch(supportRepositoryProvider);
  return repository.fetchSupportTicketPage();
});

final supportTicketsProvider = FutureProvider<List<SupportTicket>>((ref) async {
  return (await ref.watch(supportTicketPageProvider.future)).items;
});

final supportTicketDetailProvider =
    FutureProvider.family<SupportTicket?, String>((ref, ticketId) {
      final repository = ref.watch(supportRepositoryProvider);
      return repository.fetchSupportTicket(ticketId);
    });

final activeSupportTicketProvider = FutureProvider<SupportTicket?>((ref) {
  final repository = ref.watch(supportRepositoryProvider);
  return repository.fetchActiveSupportTicket();
});

final supportUnreadCountProvider = FutureProvider<int>((ref) {
  final repository = ref.watch(supportRepositoryProvider);
  return repository.fetchSupportUnreadCount();
});

class SupportRepository {
  SupportRepository({required FrappeClient frappeClient})
    : frappeClient = frappeClient,
      _uploadCoordinator = UploadCoordinator(frappeClient);

  final FrappeClient frappeClient;
  final UploadCoordinator _uploadCoordinator;
  final MutationIntent _createIntent = MutationIntent();
  final Map<String, MutationIntent> _replyIntents = {};

  Future<SupportConfigData> fetchSupportConfig() async {
    try {
      final response = await frappeClient.getMethod(
        ApiConfig.supportConfigMethod,
      );
      return SupportConfigData.fromApiResponse(response);
    } catch (_) {
      return SupportConfigData.fallback;
    }
  }

  Future<SupportTicketPage> fetchSupportTicketPage({
    int start = 0,
    int limit = 20,
  }) async {
    final safeStart = start < 0 ? 0 : start;
    final safeLimit = limit.clamp(1, 100).toInt();
    try {
      final response = await frappeClient.getMethod(
        ApiConfig.supportTicketsMethod,
        queryParameters: {
          'limit_start': safeStart,
          'limit_page_length': safeLimit,
        },
      );
      return _mapTicketPageResponse(
        response,
        requestedStart: safeStart,
        requestedLimit: safeLimit,
      );
    } on ApiError {
      rethrow;
    } catch (error) {
      throw ApiError(
        message:
            'Support tickets could not be loaded from the server right now.',
        code: 'support_tickets_unavailable',
        details: error,
      );
    }
  }

  Future<List<SupportTicket>> fetchSupportTickets({
    int start = 0,
    int limit = 20,
  }) async {
    return (await fetchSupportTicketPage(start: start, limit: limit)).items;
  }

  Future<SupportTicket?> fetchSupportTicket(String ticketId) async {
    final cleanTicketId = ticketId.trim();
    if (!_isUsableTicketId(cleanTicketId)) return null;

    try {
      final response = await frappeClient.getMethod(
        ApiConfig.supportTicketDetailMethod,
        queryParameters: {'ticket_id': cleanTicketId, 'name': cleanTicketId},
      );
      return _mapTicketDetailResponse(response);
    } on ApiError {
      rethrow;
    } catch (error) {
      throw ApiError(
        message:
            'This support ticket could not be loaded from the server right now.',
        code: 'support_ticket_detail_unavailable',
        details: error,
      );
    }
  }

  Future<SupportTicket?> fetchActiveSupportTicket() async {
    try {
      final response = await frappeClient.getMethod(
        ApiConfig.activeSupportTicketMethod,
      );
      return _mapTicketDetailResponse(response);
    } on ApiError {
      rethrow;
    } catch (error) {
      throw ApiError(
        message: 'Active support ticket could not be checked right now.',
        code: 'active_support_ticket_unavailable',
        details: error,
      );
    }
  }

  Future<int> fetchSupportUnreadCount() async {
    try {
      final response = await frappeClient.getMethod(
        ApiConfig.supportUnreadCountMethod,
      );
      final message = response['message'];
      final rawCount = message is Map<String, dynamic>
          ? message['count']
          : response['count'];
      return _intValue(rawCount) ?? 0;
    } on ApiError {
      rethrow;
    } catch (error) {
      throw ApiError(
        message: 'Unread support count could not be loaded right now.',
        code: 'support_unread_count_unavailable',
        details: error,
      );
    }
  }

  Future<int> markSupportTicketRead(String ticketId) async {
    final cleanTicketId = ticketId.trim();
    if (!_isUsableTicketId(cleanTicketId)) return 0;

    final response = await frappeClient.postMethod(
      ApiConfig.markSupportTicketReadMethod,
      data: {'ticket_id': cleanTicketId, 'name': cleanTicketId},
    );
    final message = response['message'];
    final rawUpdated = message is Map<String, dynamic>
        ? message['updated']
        : response['updated'];
    return _intValue(rawUpdated) ?? 0;
  }

  Future<String> uploadSupportTicketAttachment({
    required String ticketId,
    String? filePath,
    Uint8List? fileBytes,
    required String fileName,
    required int sizeBytes,
  }) async {
    final cleanTicketId = ticketId.trim();
    final cleanFileName = fileName.trim();

    if (!_isUsableTicketId(cleanTicketId)) {
      throw const ApiError(message: 'Missing support ticket reference.');
    }

    if (cleanFileName.isEmpty) {
      throw const ApiError(message: 'Selected attachment has no file name.');
    }

    final response = await _uploadCoordinator.upload(
      filePath: filePath,
      fileBytes: fileBytes,
      fileName: cleanFileName,
      sizeBytes: sizeBytes,
      policy: const UploadPolicy(
        allowedExtensions: {'pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'},
        maxSizeBytes: 10 * 1024 * 1024,
      ),
      method: ApiConfig.uploadSupportTicketAttachmentMethod,
      doctype: ApiConfig.supportTicketUploadDoctype,
      docname: cleanTicketId,
    );

    final uploadedFileUrl = _extractFileUrl(response);
    if (uploadedFileUrl == null) {
      throw const ApiError(
        message:
            'Attachment uploaded but the server did not return a file URL.',
      );
    }

    return uploadedFileUrl;
  }

  Future<Map<String, dynamic>> addSupportTicketReply({
    required String ticketId,
    String message = '',
    String? attachmentUrl,
    String? attachmentName,
    String? attachmentType,
  }) async {
    final cleanTicketId = ticketId.trim();
    final cleanMessage = message.trim();
    final cleanAttachmentUrl = attachmentUrl?.trim();

    if (!_isUsableTicketId(cleanTicketId)) {
      throw const ApiError(message: 'Missing support ticket reference.');
    }

    if (cleanMessage.isEmpty &&
        (cleanAttachmentUrl == null || cleanAttachmentUrl.isEmpty)) {
      throw const ApiError(message: 'Please enter a message or attach a file.');
    }

    final data = <String, dynamic>{
      'ticket_id': cleanTicketId,
      'name': cleanTicketId,
      'message': cleanMessage,
      'reply': cleanMessage,
    };

    if (cleanAttachmentUrl != null && cleanAttachmentUrl.isNotEmpty) {
      data['attachment'] = cleanAttachmentUrl;
      data['file_url'] = cleanAttachmentUrl;
    }

    final cleanAttachmentName = attachmentName?.trim();
    if (cleanAttachmentName != null && cleanAttachmentName.isNotEmpty) {
      data['attachment_name'] = cleanAttachmentName;
    }

    final cleanAttachmentType = attachmentType?.trim();
    if (cleanAttachmentType != null && cleanAttachmentType.isNotEmpty) {
      data['attachment_type'] = cleanAttachmentType;
    }

    final intent = _replyIntents.putIfAbsent(cleanTicketId, MutationIntent.new);
    final key = intent.keyFor({
      'ticket_id': cleanTicketId,
      'message': cleanMessage,
      'attachment_name': cleanAttachmentName ?? '',
      'attachment_type': cleanAttachmentType ?? '',
    });
    final response = await frappeClient.postMethod(
      ApiConfig.addSupportTicketReplyMethod,
      data: {...data, 'idempotency_key': key},
      idempotencyKey: key,
    );
    intent.complete();
    return response;
  }

  Future<SupportTicket?> updateSupportTicketStatus({
    required String ticketId,
    required String status,
    String? remarks,
  }) async {
    final cleanTicketId = ticketId.trim();
    final cleanStatus = status.trim();
    final cleanRemarks = remarks?.trim();

    if (!_isUsableTicketId(cleanTicketId)) {
      throw const ApiError(message: 'Missing support ticket reference.');
    }

    if (cleanStatus.isEmpty) {
      throw const ApiError(message: 'Select a valid ticket status.');
    }

    final data = <String, dynamic>{
      'ticket_id': cleanTicketId,
      'status': cleanStatus,
    };

    if (cleanRemarks != null && cleanRemarks.isNotEmpty) {
      data['remarks'] = cleanRemarks;
    }

    final response = await frappeClient.postMethod(
      ApiConfig.updateSupportTicketStatusMethod,
      data: data,
    );

    return _mapTicketDetailResponse(response);
  }

  Future<Map<String, dynamic>> createSupportTicket({
    required String topic,
    required String message,
  }) async {
    final cleanTopic = topic.trim();
    final cleanMessage = message.trim();

    if (cleanTopic.isEmpty) {
      throw const ApiError(message: 'Please select a support topic.');
    }

    if (cleanMessage.length < 10) {
      throw const ApiError(
        message: 'Please enter at least 10 characters for support message.',
      );
    }

    final data = {
      'subject': cleanTopic,
      'title': cleanTopic,
      'message': cleanMessage,
      'description': cleanMessage,
      'priority': 'Medium',
      'source': 'mobile_app',
    };
    final key = _createIntent.keyFor(data);
    final response = await frappeClient.postMethod(
      ApiConfig.createSupportTicketMethod,
      data: {...data, 'idempotency_key': key},
      idempotencyKey: key,
    );
    _createIntent.complete();
    return response;
  }

  SupportTicketPage _mapTicketPageResponse(
    Map<String, dynamic>? data, {
    required int requestedStart,
    required int requestedLimit,
  }) {
    if (data == null) {
      return SupportTicketPage(
        items: const [],
        start: requestedStart,
        pageLength: requestedLimit,
        hasMore: false,
        nextStart: null,
      );
    }

    final items = _mapTicketsResponse(data);
    final message = data['message'];
    final payload = message is Map<String, dynamic> ? message : data;
    final hasMore = _boolValue(payload['has_more']);
    final start = _intValue(payload['limit_start']) ?? requestedStart;
    final pageLength =
        _intValue(payload['limit_page_length']) ?? requestedLimit;
    final parsedNextStart = _intValue(payload['next_start']);

    return SupportTicketPage(
      items: items,
      start: start,
      pageLength: pageLength,
      hasMore: hasMore,
      nextStart: hasMore ? (parsedNextStart ?? start + items.length) : null,
    );
  }

  List<SupportTicket> _mapTicketsResponse(Map<String, dynamic>? data) {
    if (data == null) return const [];

    final message = data['message'];
    final rawTickets = message is List
        ? message
        : message is Map<String, dynamic>
        ? message['tickets'] ??
              message['support_tickets'] ??
              message['data'] ??
              message['items'] ??
              message['rows'] ??
              message['results'] ??
              message['records']
        : data['tickets'] ??
              data['support_tickets'] ??
              data['data'] ??
              data['items'] ??
              data['rows'] ??
              data['results'] ??
              data['records'];

    if (rawTickets is! List) return const [];

    return rawTickets
        .whereType<Map<String, dynamic>>()
        .map(_mapTicket)
        .where((ticket) => _isUsableTicketId(ticket.id))
        .toList(growable: false);
  }

  SupportTicket? _mapTicketDetailResponse(Map<String, dynamic>? data) {
    if (data == null) return null;

    final message = data['message'];
    final rawTicket = message is Map<String, dynamic>
        ? message['ticket'] ??
              message['support_ticket'] ??
              message['data'] ??
              message['item'] ??
              message['record'] ??
              message
        : data['ticket'] ??
              data['support_ticket'] ??
              data['data'] ??
              data['item'] ??
              data['record'];

    if (rawTicket is! Map<String, dynamic>) return null;

    return _mapTicket(rawTicket);
  }

  SupportTicket _mapTicket(Map<String, dynamic> json) {
    return SupportTicket(
      id: _identifierValue(json['id'] ?? json['name'] ?? json['ticket_id']),
      subject: _stringValue(json['subject'] ?? json['title']),
      message: _stringValue(json['message'] ?? json['description']),
      lastMessage: _nullableString(json['last_message'] ?? json['lastMessage']),
      status: _stringValue(json['status']),
      priority: _stringValue(json['priority']),
      referenceServiceRequest: _nullableString(
        json['reference_service_request'] ??
            json['service_request'] ??
            json['case_id'],
      ),
      contactEmail: _nullableString(json['contact_email'] ?? json['email']),
      contactPhone: _nullableString(json['contact_phone'] ?? json['phone']),
      raisedOnLabel: _dateTimeLabel(json['raised_on']),
      closedOnLabel: _dateTimeLabel(json['closed_on']),
      createdAtLabel: _dateTimeLabel(json['created_at'] ?? json['creation']),
      updatedAtLabel: _dateTimeLabel(json['updated_at'] ?? json['modified']),
      canUpdateStatus: _boolValue(json['can_update_status']),
      canReply: _boolValue(json['can_reply']),
      messages: _mapTicketMessages(
        json['messages'] ??
            json['replies'] ??
            json['conversation'] ??
            json['timeline'],
      ),
    );
  }

  bool _boolValue(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;

    final text = value?.toString().trim().toLowerCase() ?? '';
    return text == 'true' || text == '1' || text == 'yes' || text == 'on';
  }

  int? _intValue(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().trim());
  }

  List<SupportTicketMessage> _mapTicketMessages(dynamic value) {
    if (value is! List) return const [];

    return value
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => SupportTicketMessage(
            id: _stringValue(item['id'] ?? item['name']),
            author: _stringValue(
              item['author'] ??
                  item['user'] ??
                  item['sender_user'] ??
                  item['owner'],
            ),
            message: _stringValue(
              item['message'] ?? item['body'] ?? item['text'],
            ),
            createdAtLabel:
                _dateTimeLabel(
                  item['created_at'] ?? item['creation'] ?? item['timestamp'],
                ) ??
                '-',
            type: _stringValue(
              item['type'] ?? item['message_type'] ?? item['sender_type'],
            ),
            senderUser: _nullableString(item['sender_user'] ?? item['user']),
            senderType: _nullableString(item['sender_type'] ?? item['type']),
            attachmentUrl: _nullableString(
              item['attachment_url'] ?? item['file_url'] ?? item['attachment'],
            ),
            attachmentName: _nullableString(
              item['attachment_name'] ?? item['file_name'],
            ),
            attachmentType: _nullableString(
              item['attachment_type'] ?? item['file_type'],
            ),
            attachmentSize: _intValue(
              item['attachment_size'] ?? item['file_size'],
            ),
            isInternal: _boolValue(item['is_internal']),
          ),
        )
        .where(
          (item) =>
              (item.message.trim().isNotEmpty && item.message != '-') ||
              item.hasAttachment,
        )
        .toList(growable: false);
  }

  String? _extractFileUrl(Map<String, dynamic> response) {
    final message = response['message'];
    final candidates = <dynamic>[
      response['file_url'],
      response['file'],
      response['url'],
      response['name'],
      if (message is Map<String, dynamic>) ...[
        message['file_url'],
        message['file'],
        message['url'],
        message['name'],
      ],
    ];

    for (final candidate in candidates) {
      final value = candidate?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }

    return null;
  }

  bool _isUsableTicketId(String value) {
    final normalized = value.trim().toLowerCase();
    return normalized.isNotEmpty &&
        normalized != '-' &&
        normalized != 'null' &&
        normalized != 'undefined';
  }

  String _identifierValue(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return _isUsableTicketId(text) ? text : '';
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

  String? _dateTimeLabel(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;

    final parsed = DateTime.tryParse(text.replaceFirst(' ', 'T'));
    if (parsed != null) return _formatDateTime(parsed);

    final match = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2})(?::(\d{2}))?',
    ).firstMatch(text);
    if (match == null) return text;

    final second = match.group(6) ?? '00';
    return '${match.group(1)}-${match.group(2)}-${match.group(3)} '
        '${match.group(4)}:${match.group(5)}:$second';
  }

  String _formatDateTime(DateTime value) {
    return '${_two(value.year, 4)}-${_two(value.month)}-${_two(value.day)} '
        '${_two(value.hour)}:${_two(value.minute)}:${_two(value.second)}';
  }

  String _two(int value, [int width = 2]) {
    return value.toString().padLeft(width, '0');
  }
}
