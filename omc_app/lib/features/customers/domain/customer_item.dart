enum CustomerStatus { active, pending, inactive, prospect, blocked, unknown }

class CustomerItem {
  const CustomerItem({
    required this.id,
    required this.name,
    required this.status,
    this.companyName,
    this.avatarUrl,
    this.email,
    this.phone,
    this.city,
    this.cnic,
    this.ntn,
    this.lastActivityLabel,
    this.approvalStatus,
    this.isActive,
    this.linkedErpnextCustomer,
    this.createdAtLabel,
    this.updatedAtLabel,
  });

  factory CustomerItem.fromJson(Map<String, dynamic> json) {
    final approvalStatus = _nullableString(json['approval_status']);
    final customerStatus = _nullableString(
      json['customer_status'] ?? json['status'],
    );
    final isActive = _boolOrNull(json['is_active']);

    return CustomerItem(
      id: _stringValue(json['customer_id'] ?? json['id'] ?? json['name']),
      name: _stringValue(
        json['customer_name'] ?? json['full_name'] ?? json['name'],
      ),
      companyName: _nullableString(json['company_name'] ?? json['company']),
      avatarUrl: _nullableString(
        json['avatar_url'] ??
            json['user_image'] ??
            json['profile_image'] ??
            json['image'],
      ),
      status: _statusFromValues(
        customerStatus: customerStatus,
        approvalStatus: approvalStatus,
        isActive: isActive,
      ),
      email: _nullableString(json['email'] ?? json['email_id']),
      phone: _nullableString(json['phone'] ?? json['mobile_no']),
      city: _nullableString(json['city'] ?? json['territory']),
      cnic: _nullableString(json['cnic']),
      ntn: _nullableString(json['ntn']),
      lastActivityLabel: _nullableString(
        json['last_activity_label'] ??
            json['last_activity'] ??
            json['updated_at'] ??
            json['modified'],
      ),
      approvalStatus: approvalStatus,
      isActive: isActive,
      linkedErpnextCustomer: _nullableString(json['linked_erpnext_customer']),
      createdAtLabel: _nullableString(json['created_at'] ?? json['creation']),
      updatedAtLabel: _nullableString(json['updated_at'] ?? json['modified']),
    );
  }

  final String id;
  final String name;
  final CustomerStatus status;
  final String? companyName;
  final String? avatarUrl;
  final String? email;
  final String? phone;
  final String? city;
  final String? cnic;
  final String? ntn;
  final String? lastActivityLabel;
  final String? approvalStatus;
  final bool? isActive;
  final String? linkedErpnextCustomer;
  final String? createdAtLabel;
  final String? updatedAtLabel;

  String get statusLabel {
    switch (status) {
      case CustomerStatus.active:
        return 'Active';
      case CustomerStatus.pending:
        return 'Pending approval';
      case CustomerStatus.inactive:
        return 'Inactive';
      case CustomerStatus.prospect:
        return 'Prospect';
      case CustomerStatus.blocked:
        return 'Blocked';
      case CustomerStatus.unknown:
        return approvalStatus ?? 'Unknown';
    }
  }

  String get searchableText {
    return [
      id,
      name,
      companyName,
      email,
      phone,
      city,
      cnic,
      ntn,
      approvalStatus,
      linkedErpnextCustomer,
    ].whereType<String>().join(' ').toLowerCase();
  }

  static String _stringValue(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? '-' : text;
  }

  static String? _nullableString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  static bool? _boolOrNull(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;

    final text = value.toString().trim().toLowerCase();
    if (text.isEmpty) return null;

    if (text == '1' || text == 'true' || text == 'yes' || text == 'active') {
      return true;
    }

    if (text == '0' || text == 'false' || text == 'no' || text == 'inactive') {
      return false;
    }

    return null;
  }

  static CustomerStatus _statusFromValues({
    required String? customerStatus,
    required String? approvalStatus,
    required bool? isActive,
  }) {
    final approval = approvalStatus?.trim().toLowerCase() ?? '';
    final status = customerStatus?.trim().toLowerCase() ?? '';

    if (approval.contains('pending') ||
        approval.contains('review') ||
        approval.contains('await')) {
      return CustomerStatus.pending;
    }

    if (approval.contains('reject') ||
        status.contains('block') ||
        status.contains('disabled')) {
      return CustomerStatus.blocked;
    }

    if (status.contains('inactive') || isActive == false) {
      return CustomerStatus.inactive;
    }

    if (status.contains('prospect')) {
      return CustomerStatus.prospect;
    }

    if (status.contains('active') || isActive == true) {
      return CustomerStatus.active;
    }

    return CustomerStatus.unknown;
  }
}
