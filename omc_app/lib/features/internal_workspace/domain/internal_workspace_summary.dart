class InternalWorkspaceSummary {
  const InternalWorkspaceSummary({
    required this.openLeads,
    required this.activeCustomers,
    required this.pendingTasks,
    required this.pendingPayments,
    required this.myAssignedServices,
    required this.myActiveServices,
    required this.myCompletedServices,
    required this.myCompletedThisMonth,
  });

  factory InternalWorkspaceSummary.empty() {
    return const InternalWorkspaceSummary(
      openLeads: 0,
      activeCustomers: 0,
      pendingTasks: 0,
      pendingPayments: 0,
      myAssignedServices: 0,
      myActiveServices: 0,
      myCompletedServices: 0,
      myCompletedThisMonth: 0,
    );
  }

  factory InternalWorkspaceSummary.fromJson(Map<String, dynamic> json) {
    return InternalWorkspaceSummary(
      openLeads: _readInt(json['open_leads'] ?? json['leads']),
      activeCustomers: _readInt(json['active_customers'] ?? json['customers']),
      pendingTasks: _readInt(json['pending_tasks'] ?? json['tasks']),
      pendingPayments: _readInt(
        json['pending_payments'] ?? json['payments_due'],
      ),
      myAssignedServices: _readInt(json['my_assigned_services']),
      myActiveServices: _readInt(json['my_active_services']),
      myCompletedServices: _readInt(json['my_completed_services']),
      myCompletedThisMonth: _readInt(json['my_completed_this_month']),
    );
  }

  final int openLeads;
  final int activeCustomers;
  final int pendingTasks;
  final int pendingPayments;
  final int myAssignedServices;
  final int myActiveServices;
  final int myCompletedServices;
  final int myCompletedThisMonth;

  static int _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
