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
  final List<SupportTicketMessage> messages;
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

  bool get isReply => type.trim().toLowerCase() == 'reply';
}
