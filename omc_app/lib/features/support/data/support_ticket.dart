class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.subject,
    required this.message,
    required this.status,
    required this.priority,
    this.lastMessage,
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
  final String? lastMessage;
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
    required this.id,
    required this.author,
    required this.message,
    required this.createdAtLabel,
    required this.type,
    this.senderUser,
    this.senderType,
    this.attachmentUrl,
    this.attachmentName,
    this.attachmentType,
    this.attachmentSize,
    this.isInternal = false,
  });

  final String id;
  final String author;
  final String message;
  final String createdAtLabel;
  final String type;
  final String? senderUser;
  final String? senderType;
  final String? attachmentUrl;
  final String? attachmentName;
  final String? attachmentType;
  final int? attachmentSize;
  final bool isInternal;

  bool get hasAttachment => attachmentUrl != null && attachmentUrl!.trim().isNotEmpty;

  bool get isReply {
    final normalized = type.trim().toLowerCase();
    return normalized.contains('reply') ||
        normalized.contains('support') ||
        normalized.contains('staff') ||
        normalized.contains('agent') ||
        normalized.contains('admin');
  }

  bool get isFromCustomer {
    final normalizedSender = (senderType ?? type).trim().toLowerCase();
    if (normalizedSender.contains('support') ||
        normalizedSender.contains('staff') ||
        normalizedSender.contains('agent') ||
        normalizedSender.contains('admin') ||
        normalizedSender.contains('system')) {
      return false;
    }
    return true;
  }
}
