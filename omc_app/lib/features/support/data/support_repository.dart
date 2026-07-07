import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/frappe_client.dart';
import 'support_config_data.dart';
import 'support_ticket.dart';

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  final frappeClient = ref.watch(frappeClientProvider);

  return SupportRepository(frappeClient: frappeClient);
});

final supportConfigProvider = FutureProvider<SupportConfigData>((ref) async {
  final repository = ref.watch(supportRepositoryProvider);
  return repository.fetchSupportConfig();
});

final supportTicketsProvider = FutureProvider<List<SupportTicket>>((ref) async {
  final repository = ref.watch(supportRepositoryProvider);
  return repository.fetchSupportTickets();
});

final supportTicketDetailProvider =
    FutureProvider.family<SupportTicket?, String>((ref, ticketId) {
      final repository = ref.watch(supportRepositoryProvider);
      return repository.fetchSupportTicket(ticketId);
    });

class SupportRepository {
  const SupportRepository({required this.frappeClient});

  final FrappeClient frappeClient;

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

  Future<List<SupportTicket>> fetchSupportTickets() async {
    try {
      final response = await frappeClient.getMethod(
        ApiConfig.supportTicketsMethod,
      );
      return _mapTicketsResponse(response);
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

  Future<SupportTicket?> fetchSupportTicket(String ticketId) async {
    final cleanTicketId = ticketId.trim();
    if (cleanTicketId.isEmpty) return null;

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

  Future<Map<String, dynamic>> addSupportTicketReply({
    required String ticketId,
    required String message,
  }) async {
    final cleanTicketId = ticketId.trim();
    final cleanMessage = message.trim();

    if (cleanTicketId.isEmpty) {
      throw const ApiError(message: 'Missing support ticket reference.');
    }

    if (cleanMessage.length < 2) {
      throw const ApiError(message: 'Please enter a reply message.');
    }

    return frappeClient.postMethod(
      ApiConfig.addSupportTicketReplyMethod,
      data: {
        'ticket_id': cleanTicketId,
        'name': cleanTicketId,
        'message': cleanMessage,
        'reply': cleanMessage,
      },
    );
  }

  Future<SupportTicket?> updateSupportTicketStatus({
    required String ticketId,
    required String status,
    String? remarks,
  }) async {
    final cleanTicketId = ticketId.trim();
    final cleanStatus = status.trim();
    final cleanRemarks = remarks?.trim();

    if (cleanTicketId.isEmpty) {
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

    return frappeClient.postMethod(
      ApiConfig.createSupportTicketMethod,
      data: {
        'subject': cleanTopic,
        'title': cleanTopic,
        'message': cleanMessage,
        'description': cleanMessage,
        'priority': 'Medium',
        'source': 'mobile_app',
      },
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
      id: _stringValue(json['id'] ?? json['name'] ?? json['ticket_id']),
      subject: _stringValue(json['subject'] ?? json['title']),
      message: _stringValue(json['message'] ?? json['description']),
      status: _stringValue(json['status']),
      priority: _stringValue(json['priority']),
      referenceServiceRequest: _nullableString(
        json['reference_service_request'] ??
            json['service_request'] ??
            json['case_id'],
      ),
      contactEmail: _nullableString(json['contact_email'] ?? json['email']),
      contactPhone: _nullableString(json['contact_phone'] ?? json['phone']),
      raisedOnLabel: _nullableString(json['raised_on']),
      closedOnLabel: _nullableString(json['closed_on']),
      createdAtLabel: _nullableString(json['created_at'] ?? json['creation']),
      updatedAtLabel: _nullableString(json['updated_at'] ?? json['modified']),
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

  List<SupportTicketMessage> _mapTicketMessages(dynamic value) {
    if (value is! List) return const [];

    return value
        .whereType<Map<String, dynamic>>()
        .map(
          (item) => SupportTicketMessage(
            author: _stringValue(
              item['author'] ?? item['user'] ?? item['owner'],
            ),
            message: _stringValue(
              item['message'] ?? item['body'] ?? item['text'],
            ),
            createdAtLabel: _stringValue(
              item['created_at'] ?? item['creation'] ?? item['timestamp'],
            ),
            type: _stringValue(item['type'] ?? item['message_type']),
          ),
        )
        .where((item) => item.message.trim().isNotEmpty && item.message != '-')
        .toList(growable: false);
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
