import 'package:flutter/material.dart';

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
    this.requiredDocuments = const [],
    this.submittedDocuments = const [],
    this.missingDocuments = const [],
    this.documentDetails = const [],
    this.timeline = const [],
    this.progressPercent,
    this.currentStage,
    this.customerActionRequired = false,
    this.requiredDocumentsCount,
    this.submittedDocumentsCount,
    this.missingDocumentsCount,
    this.canUpdateStatus = false,
    this.canReviewDocuments = false,
    this.canViewInternalNotes = false,
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
  final List<String> requiredDocuments;
  final List<String> submittedDocuments;
  final List<String> missingDocuments;
  final List<ServiceCaseDocument> documentDetails;
  final List<ServiceCaseTimelineStep> timeline;
  final int? progressPercent;
  final String? currentStage;
  final bool customerActionRequired;
  final int? requiredDocumentsCount;
  final int? submittedDocumentsCount;
  final int? missingDocumentsCount;
  final bool canUpdateStatus;
  final bool canReviewDocuments;
  final bool canViewInternalNotes;

  bool get isClosed {
    final normalized = status.trim().toLowerCase();
    return normalized.contains('complete') ||
        normalized.contains('cancel') ||
        normalized.contains('closed') ||
        normalized.contains('reject');
  }
}

class ServiceCaseDocument {
  const ServiceCaseDocument({
    required this.id,
    required this.title,
    required this.type,
    required this.status,
    this.fileUrl,
    this.remarks,
  });

  final String id;
  final String title;
  final String type;
  final String status;
  final String? fileUrl;
  final String? remarks;

  bool get hasRealId => id.trim().isNotEmpty && id.trim() != '-';

  bool get isSubmitted {
    final normalized = status.trim().toLowerCase();
    return fileUrl != null ||
        normalized.contains('submitted') ||
        normalized.contains('uploaded') ||
        normalized.contains('approved') ||
        normalized.contains('received') ||
        normalized.contains('verified') ||
        normalized.contains('under review');
  }

  bool get isMissing {
    final normalized = status.trim().toLowerCase();
    return fileUrl == null &&
        (normalized.contains('missing') ||
            normalized.contains('required') ||
            normalized.contains('pending') ||
            normalized.contains('rejected'));
  }
}

class ServiceCaseTimelineStep {
  const ServiceCaseTimelineStep({
    required this.title,
    required this.subtitle,
    required this.isDone,
  });

  final String title;
  final String subtitle;
  final bool isDone;
}

class ServiceCaseStatusStyle {
  const ServiceCaseStatusStyle({required this.icon, required this.label});

  final IconData icon;
  final String label;
}
