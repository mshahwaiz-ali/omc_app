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
  });

  factory CustomerItem.fromJson(Map<String, dynamic> json) {
    return CustomerItem(
      id: _stringValue(json['id'] ?? json['name'] ?? json['customer_id']),
      name: _stringValue(
        json['customer_name'] ?? json['full_name'] ?? json['name'],
      ),
      companyName: _nullableString(json['company_name'] ?? json['company']),
      status: _statusFromValue(json['status'] ?? json['customer_status']),
      email: _nullableString(json['email'] ?? json['email_id']),
      phone: _nullableString(json['phone'] ?? json['mobile_no']),
      city: _nullableString(json['city'] ?? json['territory']),
      lastActivityLabel: _nullableString(
        json['last_activity_label'] ??
            json['last_activity'] ??
            json['modified'],
      ),
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

  static String _stringValue(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? '-' : text;
  }

  static String? _nullableString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  static CustomerStatus _statusFromValue(dynamic value) {
    final status = value?.toString().trim().toLowerCase() ?? '';

    if (status.contains('active')) return CustomerStatus.active;
    if (status.contains('inactive')) return CustomerStatus.inactive;
    if (status.contains('prospect')) return CustomerStatus.prospect;
    if (status.contains('block') || status.contains('disabled')) {
      return CustomerStatus.blocked;
    }

    return CustomerStatus.unknown;
  }
}
