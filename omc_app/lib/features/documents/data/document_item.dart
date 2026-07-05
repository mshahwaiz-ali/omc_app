enum DocumentStatus { uploaded, missing, pendingReview, approved, rejected }

class DocumentItem {
  const DocumentItem({
    required this.id,
    required this.title,
    required this.status,
    this.subtitle,
    this.fileName,
    this.updatedAtLabel,
    this.serviceReference,
    this.remarks,
  });

  final String id;
  final String title;
  final String? subtitle;
  final String? fileName;
  final String? updatedAtLabel;
  final String? serviceReference;
  final String? remarks;
  final DocumentStatus status;

  bool get requiresAction =>
      status == DocumentStatus.missing || status == DocumentStatus.rejected;
}

extension DocumentStatusLabel on DocumentStatus {
  String get label {
    switch (this) {
      case DocumentStatus.uploaded:
        return 'Uploaded';
      case DocumentStatus.missing:
        return 'Missing';
      case DocumentStatus.pendingReview:
        return 'Pending Review';
      case DocumentStatus.approved:
        return 'Approved';
      case DocumentStatus.rejected:
        return 'Rejected';
    }
  }
}
