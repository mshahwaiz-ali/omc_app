enum LeadStatus { newLead, contacted, qualified, converted, lost, unknown }

class LeadItem {
  const LeadItem({
    required this.id,
    required this.title,
    required this.customerName,
    required this.status,
    this.email,
    this.phone,
    this.source,
    this.createdAtLabel,
  });

  factory LeadItem.fromJson(Map<String, dynamic> json) {
    return LeadItem(
      id: _stringValue(json['id'] ?? json['name'] ?? json['lead_id']),
      title: _stringValue(
        json['title'] ?? json['lead_name'] ?? json['company_name'],
      ),
      customerName: _stringValue(
        json['customer_name'] ??
            json['person_name'] ??
            json['lead_name'] ??
            json['company_name'],
      ),
      status: _statusFromValue(json['status']),
      email: _nullableString(json['email'] ?? json['email_id']),
      phone: _nullableString(json['phone'] ?? json['mobile_no']),
      source: _nullableString(json['source']),
      createdAtLabel: _nullableString(
        json['created_at_label'] ?? json['creation'] ?? json['created_at'],
      ),
    );
  }

  final String id;
  final String title;
  final String customerName;
  final LeadStatus status;
  final String? email;
  final String? phone;
  final String? source;
  final String? createdAtLabel;

  static String _stringValue(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? '-' : text;
  }

  static String? _nullableString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  static LeadStatus _statusFromValue(dynamic value) {
    final status = value?.toString().trim().toLowerCase() ?? '';

    if (status.contains('new')) return LeadStatus.newLead;
    if (status.contains('contact')) return LeadStatus.contacted;
    if (status.contains('qualif')) return LeadStatus.qualified;
    if (status.contains('convert')) return LeadStatus.converted;
    if (status.contains('lost')) return LeadStatus.lost;

    return LeadStatus.unknown;
  }
}
