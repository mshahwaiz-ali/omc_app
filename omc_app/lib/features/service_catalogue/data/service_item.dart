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
  });

  final String id;
  final String title;
  final String category;
  final String feeLabel;
  final String? governmentFeeLabel;
  final String completionTime;
  final List<String> requirements;
  final String? description;

  factory ServiceItem.fromJson(Map<String, dynamic> json) {
    final requirements = json['requirements'];

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
      requirements: requirements is List
          ? requirements
                .map((value) => value.toString().trim())
                .where((value) => value.isNotEmpty)
                .toList(growable: false)
          : const [],
    );
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