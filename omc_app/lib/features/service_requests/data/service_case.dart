class ServiceCase {
  const ServiceCase({
    required this.id,
    required this.title,
    required this.category,
    required this.status,
    required this.createdAtLabel,
    required this.updatedAtLabel,
    required this.progress,
    this.reference,
    this.nextStep,
    this.remarks,
  });

  final String id;
  final String title;
  final String category;
  final String status;
  final String createdAtLabel;
  final String updatedAtLabel;
  final double progress;
  final String? reference;
  final String? nextStep;
  final String? remarks;
}


typedef ServiceCaseSummary = ServiceCase;

class ServiceCaseStatusStyle {
  const ServiceCaseStatusStyle({
    required this.icon,
    required this.label,
  });

  final dynamic icon;
  final String label;
}
