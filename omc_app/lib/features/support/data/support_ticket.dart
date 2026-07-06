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
}
