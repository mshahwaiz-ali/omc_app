class ServiceItem {
  const ServiceItem({
    required this.id,
    required this.title,
    required this.category,
    required this.feeLabel,
    required this.completionTime,
    required this.requirements,
    this.governmentFeeLabel,
    this.description,
    this.shortDescription,
    this.processSteps = const [],
    this.requiredDocuments = const [],
    this.supportMessage,
    this.wizardType,
  });

  final String id;
  final String title;
  final String category;
  final String feeLabel;
  final String? governmentFeeLabel;
  final String completionTime;
  final List<String> requirements;
  final String? description;
  final String? shortDescription;
  final List<String> processSteps;
  final List<String> requiredDocuments;
  final String? supportMessage;
  final String? wizardType;

  factory ServiceItem.fromJson(Map<String, dynamic> json) {
    return ServiceItem(
      id: _readString(json, ['id', 'name', 'service_id']),
      title: _readString(json, ['title', 'service_name', 'serviceName']),
      category: _readString(json, ['category', 'service_category']),
      feeLabel: _readString(json, ['feeLabel', 'fee_label', 'fee']),
      governmentFeeLabel: _readNullableString(json, [
        'governmentFeeLabel',
        'government_fee_label',
        'government_fee',
      ]),
      completionTime: _readString(json, [
        'completionTime',
        'completion_time',
        'timeline',
        'duration',
      ]),
      description: _readNullableString(json, ['description', 'details']),
      shortDescription: _readNullableString(json, [
        'shortDescription',
        'short_description',
        'summary',
      ]),
      supportMessage: _readNullableString(json, [
        'supportMessage',
        'support_message',
        'whatsapp_message',
      ]),
      wizardType: _readNullableString(json, [
        'wizardType',
        'wizard_type',
        'request_wizard_type',
      ]),
      requirements: _readStringList(json, ['requirements']),
      processSteps: _readStringList(json, [
        'processSteps',
        'process_steps',
        'steps',
      ]),
      requiredDocuments: _readStringList(json, [
        'requiredDocuments',
        'required_documents',
        'documents',
      ]),
    );
  }

  static List<String> _readStringList(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];

      if (value is List) {
        return value
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false);
      }
    }

    return const [];
  }

  static String _readString(Map<String, dynamic> json, List<String> keys) {
    return _readNullableString(json, keys) ?? '';
  }

  static String? _readNullableString(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];

      if (value == null) continue;

      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }

    return null;
  }
}
