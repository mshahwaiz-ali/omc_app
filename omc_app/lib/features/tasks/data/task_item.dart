class TaskItem {
  const TaskItem({
    required this.id,
    required this.title,
    required this.status,
    required this.erpStatus,
    required this.operationStatus,
    required this.allowedTransitions,
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
  final String erpStatus;
  final String operationStatus;
  final List<TaskTransition> allowedTransitions;
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
      status: _stringValue(
        json['erp_status'] ?? json['status'] ?? json['display_status'],
        fallback: 'Open',
      ),
      erpStatus: _stringValue(
        json['erp_status'] ?? json['status'],
        fallback: 'Open',
      ),
      operationStatus: _stringValue(json['operation_status']),
      allowedTransitions: _transitionList(json['allowed_transitions']),
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

  static List<TaskTransition> _transitionList(dynamic value) {
    if (value is! List) return const [];

    return value
        .whereType<Map>()
        .map((item) => TaskTransition.fromJson(Map<String, dynamic>.from(item)))
        .where((item) => item.value.isNotEmpty)
        .toList(growable: false);
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

class TaskTransition {
  const TaskTransition({
    required this.value,
    required this.label,
    required this.requiresConfirmation,
    required this.terminal,
  });

  final String value;
  final String label;
  final bool requiresConfirmation;
  final bool terminal;

  factory TaskTransition.fromJson(Map<String, dynamic> json) {
    return TaskTransition(
      value: TaskItem._stringValue(json['value']),
      label: TaskItem._stringValue(
        json['label'],
        fallback: TaskItem._stringValue(json['value']),
      ),
      requiresConfirmation: _boolValue(json['requires_confirmation']),
      terminal: _boolValue(json['terminal']),
    );
  }

  static bool _boolValue(dynamic value) {
    return value == true || value == 1 || value == '1';
  }
}
