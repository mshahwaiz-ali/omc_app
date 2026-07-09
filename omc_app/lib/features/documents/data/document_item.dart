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
    this.serviceTitle,
    this.serviceStatus,
    this.source,
    this.remarks,
    this.isArchived = false,
    this.archivedOnLabel,
    this.archiveReason,
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
  final String? serviceTitle;
  final String? serviceStatus;
  final String? source;
  final String? remarks;
  final bool isArchived;
  final String? archivedOnLabel;
  final String? archiveReason;
  final DocumentStatus status;

  bool get requiresAction =>
      !isArchived &&
      (status == DocumentStatus.missing || status == DocumentStatus.rejected);

  bool get isApproved => !isArchived && status == DocumentStatus.approved;

  bool get isUnderReview =>
      !isArchived &&
      (status == DocumentStatus.uploaded ||
          status == DocumentStatus.pendingReview);

  bool get isActive => !isArchived;

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

  String get statusLabel {
    if (isArchived) {
      final reason = archiveReason?.trim();
      if (reason != null && reason.isNotEmpty) return 'Archived · $reason';
      return 'Archived';
    }

    return status.label;
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
