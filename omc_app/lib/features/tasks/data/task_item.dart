class TaskItem {
  const TaskItem({
    required this.id,
    required this.title,
    required this.status,
    required this.priority,
    required this.dueDateLabel,
    required this.assignedTo,
  });

  final String id;
  final String title;
  final String status;
  final String priority;
  final String dueDateLabel;
  final String assignedTo;

  factory TaskItem.fromJson(Map<String, dynamic> json) {
    return TaskItem(
      id: (json['name'] ?? json['id'] ?? '').toString(),
      title:
          (json['subject'] ??
                  json['title'] ??
                  json['task_name'] ??
                  'Untitled Task')
              .toString(),
      status: (json['status'] ?? 'Open').toString(),
      priority: (json['priority'] ?? 'Normal').toString(),
      dueDateLabel:
          (json['exp_end_date'] ??
                  json['due_date'] ??
                  json['date'] ??
                  json['deadline'] ??
                  '')
              .toString(),
      assignedTo: (json['assigned_to'] ?? json['owner'] ?? '').toString(),
    );
  }
}
