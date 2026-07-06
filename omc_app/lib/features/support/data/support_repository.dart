import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/frappe_client.dart';
import 'support_ticket.dart';

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  final frappeClient = ref.watch(frappeClientProvider);

  return SupportRepository(frappeClient: frappeClient);
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
        ? message['tickets']
        : data['tickets'];

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
        ? message['ticket'] ?? message['data'] ?? message['item'] ?? message
        : data['ticket'] ?? data['data'] ?? data['item'];

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
    );
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
