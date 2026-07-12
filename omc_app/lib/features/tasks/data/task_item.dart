class TaskItem {
  const TaskItem({
    required this.id,
    required this.title,
    required this.status,
    required this.priority,
    required this.dueDateLabel,
    required this.assignedTo,
    this.description,
    this.customerProfile,
    this.serviceRequest,
    this.supportTicket,
    this.completedOnLabel,
    this.createdAtLabel,
    this.updatedAtLabel,
  });

  final String id;
  final String title;
  final String status;
  final String priority;
  final String dueDateLabel;
  final String assignedTo;
  final String? description;
  final String? customerProfile;
  final String? serviceRequest;
  final String? supportTicket;
  final String? completedOnLabel;
  final String? createdAtLabel;
  final String? updatedAtLabel;

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    return TaskItem(
      id: _stringValue(json['name'] ?? json['id'] ?? json['task_id']),
      title: _stringValue(
        json['subject'] ?? json['title'] ?? json['task_name'],
        fallback: 'Untitled Task',
      ),
      status: _stringValue(json['status'], fallback: 'Open'),
      priority: _stringValue(json['priority'], fallback: 'Normal'),
      dueDateLabel: _stringValue(
        json['exp_end_date'] ??
            json['due_date'] ??
            json['date'] ??
            json['deadline'],
      ),
      assignedTo: _stringValue(json['assigned_to'] ?? json['owner']),
      description: _nullableString(json['description'] ?? json['details']),
      customerProfile: _nullableString(
        json['customer_profile'] ?? json['customer'],
      ),
      serviceRequest: _nullableString(
        json['service_request'] ?? json['case_id'],
      ),
      supportTicket: _nullableString(
        json['support_ticket'] ?? json['ticket_id'],
      ),
      completedOnLabel: _nullableString(json['completed_on']),
      createdAtLabel: _nullableString(json['created_at'] ?? json['creation']),
      updatedAtLabel: _nullableString(json['updated_at'] ?? json['modified']),
    );
  }

  static String _stringValue(dynamic value, {String fallback = ''}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static String? _nullableString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }
}
