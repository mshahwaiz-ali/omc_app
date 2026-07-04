class ServiceItem {
  const ServiceItem({
    required this.id,
    required this.title,
    required this.category,
    required this.feeLabel,
    required this.completionTime,
    required this.requirements,
    this.governmentFeeLabel,
  });

  final String id;
  final String title;
  final String category;
  final String feeLabel;
  final String? governmentFeeLabel;
  final String completionTime;
  final List<String> requirements;

  factory ServiceItem.fromJson(Map<String, dynamic> json) {
    final requirements = json['requirements'];

    return ServiceItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      category: json['category'] as String? ?? '',
      feeLabel: json['feeLabel'] as String? ?? '',
      governmentFeeLabel: json['governmentFeeLabel'] as String?,
      completionTime: json['completionTime'] as String? ?? '',
      requirements: requirements is List
          ? requirements.whereType<String>().toList(growable: false)
          : const [],
    );
  }
}
