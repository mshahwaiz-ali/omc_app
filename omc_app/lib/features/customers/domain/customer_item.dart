enum CustomerStatus { active, inactive, prospect, blocked, unknown }

class CustomerItem {
  const CustomerItem({
    required this.id,
    required this.name,
    required this.status,
    this.companyName,
    this.email,
    this.phone,
    this.city,
    this.lastActivityLabel,
    this.approvalStatus,
    this.isActive,
    this.linkedErpnextCustomer,
    this.createdAtLabel,
    this.updatedAtLabel,
  });

  factory CustomerItem.fromJson(Map<String, dynamic> json) {
    return CustomerItem(
      id: _stringValue(json['id'] ?? json['name'] ?? json['customer_id']),
      name: _stringValue(
        json['customer_name'] ?? json['full_name'] ?? json['name'],
      ),
      companyName: _nullableString(json['company_name'] ?? json['company']),
      status: _statusFromValue(
        json['status'] ?? json['customer_status'] ?? json['approval_status'],
      ),
      email: _nullableString(json['email'] ?? json['email_id']),
      phone: _nullableString(json['phone'] ?? json['mobile_no']),
      city: _nullableString(json['city'] ?? json['territory']),
      lastActivityLabel: _nullableString(
        json['last_activity_label'] ??
            json['last_activity'] ??
            json['updated_at'] ??
            json['modified'],
      ),
      approvalStatus: _nullableString(json['approval_status']),
      isActive: _boolOrNull(json['is_active']),
      linkedErpnextCustomer: _nullableString(json['linked_erpnext_customer']),
      createdAtLabel: _nullableString(json['created_at'] ?? json['creation']),
      updatedAtLabel: _nullableString(json['updated_at'] ?? json['modified']),
    );
  }

  final String id;
  final String name;
  final CustomerStatus status;
  final String? companyName;
  final String? email;
  final String? phone;
  final String? city;
  final String? lastActivityLabel;
  final String? approvalStatus;
  final bool? isActive;
  final String? linkedErpnextCustomer;
  final String? createdAtLabel;
  final String? updatedAtLabel;

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

  static CustomerStatus _statusFromValue(dynamic value) {
    final status = value?.toString().trim().toLowerCase() ?? '';

    if (status.contains('inactive')) return CustomerStatus.inactive;
    if (status.contains('block') || status.contains('disabled')) {
      return CustomerStatus.blocked;
    }
    if (status.contains('prospect')) return CustomerStatus.prospect;
    if (status.contains('active')) return CustomerStatus.active;

    return CustomerStatus.unknown;
  }
}
