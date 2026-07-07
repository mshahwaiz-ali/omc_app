class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.subject,
    required this.message,
    required this.status,
    required this.priority,
    this.referenceServiceRequest,
    this.contactEmail,
    this.contactPhone,
    this.raisedOnLabel,
    this.closedOnLabel,
    this.createdAtLabel,
    this.updatedAtLabel,
    this.canUpdateStatus = false,
    this.canReply = false,
    this.messages = const [],
  });

  final String id;
  final String subject;
  final String message;
  final String status;
  final String priority;
  final String? referenceServiceRequest;
  final String? contactEmail;
  final String? contactPhone;
  final String? raisedOnLabel;
  final String? closedOnLabel;
  final String? createdAtLabel;
  final String? updatedAtLabel;
  final bool canUpdateStatus;
  final bool canReply;
  final List<SupportTicketMessage> messages;

  bool get isClosed {
    final normalized = status.trim().toLowerCase();
    return normalized.contains('closed') ||
        normalized.contains('resolved') ||
        normalized.contains('cancel') ||
        normalized.contains('done');
  }
}

class SupportTicketMessage {
  const SupportTicketMessage({
    required this.author,
    required this.message,
    required this.createdAtLabel,
    required this.type,
  });

  final String author;
  final String message;
  final String createdAtLabel;
  final String type;

  bool get isReply {
    final normalized = type.trim().toLowerCase();
    return normalized.contains('reply') ||
        normalized.contains('support') ||
        normalized.contains('staff') ||
        normalized.contains('agent');
  }
}
