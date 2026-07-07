enum DocumentStatus { uploaded, missing, pendingReview, approved, rejected }

class DocumentItem {
  const DocumentItem({
    required this.id,
    required this.title,
    required this.status,
    this.subtitle,
    this.fileName,
    this.fileUrl,
    this.previewUrl,
    this.downloadUrl,
    this.updatedAtLabel,
    this.serviceReference,
    this.remarks,
  });

  final String id;
  final String title;
  final String? subtitle;
  final String? fileName;
  final String? fileUrl;
  final String? previewUrl;
  final String? downloadUrl;
  final String? updatedAtLabel;
  final String? serviceReference;
  final String? remarks;
  final DocumentStatus status;

  bool get requiresAction =>
      status == DocumentStatus.missing || status == DocumentStatus.rejected;

  bool get hasFile {
    final candidates = [fileUrl, previewUrl, downloadUrl, fileName];
    return candidates.any((value) => value != null && value.trim().isNotEmpty);
  }

  String get displayFileName {
    final cleanFileName = fileName?.trim();
    if (cleanFileName != null && cleanFileName.isNotEmpty) return cleanFileName;

    final cleanTitle = title.trim();
    return cleanTitle.isEmpty ? '-' : cleanTitle;
  }
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
