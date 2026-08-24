class TaskItem {
  const TaskItem({
    required this.id,
    required this.title,
    required this.status,
    required this.erpStatus,
    required this.operationStatus,
    this.workflowState = '',
    this.taskType,
    this.source,
    this.company,
    this.progress,
    this.expectedStartDate,
    required this.allowedTransitions,
    required this.priority,
    required this.dueDateLabel,
    required this.assignedTo,
    this.description,
    this.customerProfile,
    this.customerName,
    this.serviceRequest,
    this.supportTicket,
    this.completedOnLabel,
    this.createdAtLabel,
    this.updatedAtLabel,
    this.serverCanManageTasks = false,
    this.serverCanManageAssignedTasks = false,
    this.canViewLinkedServiceCase = false,
  });

  final String id;
  final String title;

  /// ERPNext Task.status is the display and filtering authority.
  final String status;
  final String erpStatus;

  /// ERPNext Workflow State. Display-only in OMC.
  final String workflowState;

  /// ERPNext custom operation status. Supplemental display metadata only.
  final String operationStatus;

  /// Direct ERP Task business context.
  final String? taskType;
  final String? source;
  final String? company;
  final double? progress;
  final String? expectedStartDate;

  /// Retained for wire/source compatibility. Mobile tasks are always read-only.
  final List<StaffTaskTransition> allowedTransitions;

  final String priority;
  final String dueDateLabel;
  final String assignedTo;
  final String? description;
  final String? customerProfile;
  final String? customerName;
  final String? serviceRequest;
  final String? supportTicket;
  final String? completedOnLabel;
  final String? createdAtLabel;
  final String? updatedAtLabel;

  /// Fail closed even if an old/stale backend response advertises write hints.
  final bool serverCanManageTasks;
  final bool serverCanManageAssignedTasks;

  /// Server-authoritative permission for this specific linked service case.
  final bool canViewLinkedServiceCase;

  String? get caseReference => serviceRequest;
  String? get expectedCompletionDate => _nullableString(dueDateLabel);
  String? get completedOn => completedOnLabel;
  String? get createdAt => createdAtLabel;
  String? get updatedAt => updatedAtLabel;

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    final operationStatus = _stringValue(json['operation_status']);
    final workflowState = _stringValue(json['workflow_state']);
    final erpStatus = _stringValue(
      json['erp_status'] ?? json['status'],
      fallback: 'Open',
    );
    final customerProfile = _nullableString(json['customer_profile']);
    final customerName =
        _nullableString(json['customer_name']) ??
        _nullableString(json['customer']) ??
        customerProfile;

    return TaskItem(
      id: _stringValue(json['name'] ?? json['id'] ?? json['task_id']),
      title: _stringValue(
        json['subject'] ?? json['title'] ?? json['task_name'],
        fallback: 'Untitled Task',
      ),
      status: erpStatus,
      erpStatus: erpStatus,
      operationStatus: operationStatus,
      workflowState: workflowState,
      taskType: _nullableString(json['task_type'] ?? json['type']),
      source: _nullableString(json['source']),
      company: _nullableString(json['company']),
      progress: _nullableDouble(json['progress']),
      expectedStartDate: _nullableString(
        json['expected_start_date'] ?? json['exp_start_date'],
      ),
      allowedTransitions: const <StaffTaskTransition>[],
      priority: _stringValue(json['priority'], fallback: 'Normal'),
      dueDateLabel: _stringValue(
        json['due_date'] ??
            json['exp_end_date'] ??
            json['expected_completion_date'] ??
            json['date'] ??
            json['deadline'],
      ),
      assignedTo: _stringValue(json['assigned_to'] ?? json['owner']),
      description: _nullableString(json['description'] ?? json['details']),
      customerProfile: customerProfile,
      customerName: customerName,
      serviceRequest: _nullableString(
        json['service_request'] ?? json['case_id'],
      ),
      supportTicket: _nullableString(
        json['support_ticket'] ?? json['ticket_id'],
      ),
      completedOnLabel: _nullableString(json['completed_on']),
      createdAtLabel: _nullableString(json['created_at'] ?? json['creation']),
      updatedAtLabel: _nullableString(json['updated_at'] ?? json['modified']),
      serverCanManageTasks: false,
      serverCanManageAssignedTasks: false,
      canViewLinkedServiceCase: _boolValue(
        json['can_view_linked_service_case'],
      ),
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

  static double? _nullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();

    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
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

/// Compatibility type retained for older payload/tests.
/// Mobile task tracking never consumes these as mutation actions.
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

typedef TaskTransition = StaffTaskTransition;

/// Compatibility model retained for callers that may still decode old data.
/// Task assignment changes are not exposed by TasksRepository.
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
