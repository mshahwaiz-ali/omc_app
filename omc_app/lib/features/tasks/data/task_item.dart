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
    this.assignedTo,
    this.description,
    this.customerProfile,
    this.customerName,
    this.serviceRequest,
    this.supportTicket,
    this.completedOnLabel,
    this.createdAtLabel,
    this.updatedAtLabel,
    this.serverCanManageTasks = true,
    this.serverCanManageAssignedTasks = true,
  });

  final String id;
  final String title;
  final String status;
  final String erpStatus;
  final String operationStatus;
  final List<StaffTaskTransition> allowedTransitions;
  final String priority;
  final String dueDateLabel;
  final String? assignedTo;
  final String? description;
  final String? customerProfile;
  final String? customerName;
  final String? serviceRequest;
  final String? supportTicket;
  final String? completedOnLabel;
  final String? createdAtLabel;
  final String? updatedAtLabel;

  /// These are optional per-task hints only. The canonical user capability
  /// response and backend mutation guards remain authoritative.
  final bool serverCanManageTasks;
  final bool serverCanManageAssignedTasks;

  String? get caseReference => serviceRequest;
  String? get expectedCompletionDate => _nullableString(dueDateLabel);
  String? get completedOn => completedOnLabel;
  String? get createdAt => createdAtLabel;
  String? get updatedAt => updatedAtLabel;

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    final operationStatus = _stringValue(json['operation_status']);
    final erpStatus = _stringValue(
      json['erp_status'] ?? json['status'],
      fallback: 'Open',
    );
    final displayStatus = _stringValue(
      json['display_status'] ??
          (operationStatus.isNotEmpty ? operationStatus : null) ??
          json['status'] ??
          erpStatus,
      fallback: 'Open',
    );
    final customerProfile = _nullableString(
      json['customer_profile'] ?? json['customer'],
    );

    return TaskItem(
      id: _stringValue(json['name'] ?? json['id'] ?? json['task_id']),
      title: _stringValue(
        json['subject'] ?? json['title'] ?? json['task_name'],
        fallback: 'Untitled Task',
      ),
      status: displayStatus,
      erpStatus: erpStatus,
      operationStatus: operationStatus,
      allowedTransitions: _transitionList(json['allowed_transitions']),
      priority: _stringValue(json['priority'], fallback: 'Normal'),
      dueDateLabel: _stringValue(
        json['due_date'] ??
            json['exp_end_date'] ??
            json['expected_completion_date'] ??
            json['date'] ??
            json['deadline'],
      ),
      assignedTo: _nullableString(json['assigned_to'] ?? json['owner']),
      description: _nullableString(json['description'] ?? json['details']),
      customerProfile: customerProfile,
      customerName: _nullableString(json['customer_name']) ?? customerProfile,
      serviceRequest: _nullableString(
        json['service_request'] ?? json['case_id'],
      ),
      supportTicket: _nullableString(
        json['support_ticket'] ?? json['ticket_id'],
      ),
      completedOnLabel: _nullableString(json['completed_on']),
      createdAtLabel: _nullableString(json['created_at'] ?? json['creation']),
      updatedAtLabel: _nullableString(json['updated_at'] ?? json['modified']),
      serverCanManageTasks: _boolValue(
        json['can_manage_tasks'],
        fallback: true,
      ),
      serverCanManageAssignedTasks: _boolValue(
        json['can_manage_assigned_tasks'],
        fallback: true,
      ),
    );
  }

  static List<StaffTaskTransition> _transitionList(dynamic value) {
    if (value is! List) return const [];

    return value
        .whereType<Map>()
        .map(
          (item) => StaffTaskTransition.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .where((item) => item.status.isNotEmpty)
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

  static bool _boolValue(dynamic value, {bool fallback = false}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value.toString().trim().toLowerCase();
    if (text == 'true' || text == '1' || text == 'yes') return true;
    if (text == 'false' || text == '0' || text == 'no') return false;
    return fallback;
  }
}

class StaffTaskTransition {
  const StaffTaskTransition({
    required this.status,
    required this.label,
    required this.requiresRemarks,
    required this.terminal,
  });

  final String status;
  final String label;
  final bool requiresRemarks;
  final bool terminal;

  String get value => status;
  bool get requiresConfirmation => requiresRemarks;

  factory StaffTaskTransition.fromJson(Map<String, dynamic> json) {
    final status = TaskItem._stringValue(json['status'] ?? json['value']);
    return StaffTaskTransition(
      status: status,
      label: TaskItem._stringValue(json['label'], fallback: status),
      requiresRemarks: TaskItem._boolValue(
        json['requires_remarks'] ?? json['requires_confirmation'],
      ),
      terminal: TaskItem._boolValue(json['terminal']),
    );
  }
}

/// Backward-compatible name retained for older callers/tests.
typedef TaskTransition = StaffTaskTransition;

class TaskAssigneeOption {
  const TaskAssigneeOption({
    required this.user,
    required this.label,
    this.primaryRole = '',
  });

  final String user;
  final String label;
  final String primaryRole;

  factory TaskAssigneeOption.fromJson(Map<String, dynamic> json) {
    final user = TaskItem._stringValue(
      json['user'] ?? json['user_id'] ?? json['email'],
    );
    return TaskAssigneeOption(
      user: user,
      label: TaskItem._stringValue(
        json['label'] ?? json['full_name'] ?? user,
        fallback: user,
      ),
      primaryRole: TaskItem._stringValue(json['primary_role']),
    );
  }
}
