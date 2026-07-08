import 'package:flutter/material.dart';

class ServiceCase {
  const ServiceCase({
    required this.id,
    required this.title,
    required this.category,
    required this.status,
    required this.createdAtLabel,
    required this.updatedAtLabel,
    required this._progress,
    this.reference,
    this.nextStep,
    this.remarks,
    this.requiredDocuments = const [],
    this.submittedDocuments = const [],
    this.missingDocuments = const [],
    this.documentDetails = const [],
    this.paymentDetails = const [],
    this.timeline = const [],
    this._progressPercent,
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
  final double _progress;
  final String? reference;
  final String? nextStep;
  final String? remarks;
  final List<String> requiredDocuments;
  final List<String> submittedDocuments;
  final List<String> missingDocuments;
  final List<ServiceCaseDocument> documentDetails;
  final List<ServiceCasePayment> paymentDetails;
  final List<ServiceCaseTimelineStep> timeline;
  final int? _progressPercent;
  final String? currentStage;
  final bool customerActionRequired;
  final int? requiredDocumentsCount;
  final int? submittedDocumentsCount;
  final int? missingDocumentsCount;
  final bool canUpdateStatus;
  final bool canReviewDocuments;
  final bool canViewInternalNotes;

  /// Backend values remain accepted, but the customer-facing percentage should
  /// be based on current records, not on timeline step count.
  double get progress {
    final calculated = _calculatedProgressPercent / 100;
    final backendProgress = _progress.clamp(0, 1).toDouble();

    if (isClosed && _normalizedStatus.contains('complete')) return 1;
    if (_normalizedStatus.contains('cancel')) return 0;

    return calculated > backendProgress ? calculated : backendProgress;
  }

  int? get progressPercent {
    final calculated = _calculatedProgressPercent;
    if (_progressPercent == null) return calculated;

    if (isClosed && _normalizedStatus.contains('complete')) return 100;
    if (_normalizedStatus.contains('cancel')) return 0;

    return calculated > _progressPercent ? calculated : _progressPercent;
  }

  int get requiredDocumentTotal {
    if (requiredDocumentsCount != null) return requiredDocumentsCount!;
    if (documentDetails.isNotEmpty) return documentDetails.length;
    return requiredDocuments.length;
  }

  int get approvedDocumentTotal {
    if (documentDetails.isEmpty) return 0;
    return documentDetails.where((document) => document.isApproved).length;
  }

  int get rejectedDocumentTotal {
    if (documentDetails.isEmpty) return 0;
    return documentDetails.where((document) => document.isRejected).length;
  }

  int get activePaymentTotal {
    return paymentDetails.where((payment) => !payment.isCancelled).length;
  }

  int get approvedPaymentTotal {
    return paymentDetails.where((payment) => payment.isPaid).length;
  }

  int get rejectedPaymentTotal {
    return paymentDetails.where((payment) => payment.isRejected).length;
  }

  String get documentSummaryLabel {
    final total = requiredDocumentTotal;
    if (total <= 0) return 'No documents required';
    return '$approvedDocumentTotal/$total approved';
  }

  String get paymentSummaryLabel {
    final total = activePaymentTotal;
    if (total <= 0) return 'No payment opened';
    return '$approvedPaymentTotal/$total paid';
  }

  String get actionRequiredLabel {
    if (rejectedDocumentTotal > 0) {
      return '$rejectedDocumentTotal rejected document(s)';
    }

    final missing = missingDocumentsCount ?? missingDocuments.length;
    if (missing > 0) return '$missing document(s) required';

    if (rejectedPaymentTotal > 0) {
      return '$rejectedPaymentTotal rejected receipt(s)';
    }

    if (_normalizedStatus.contains('payment') ||
        paymentDetails.any((payment) => payment.needsCustomerAction)) {
      return 'Payment action required';
    }

    return nextStep ?? 'No customer action required';
  }

  int get _calculatedProgressPercent {
    final completedBonus = _normalizedStatus.contains('complete') ? 10 : 0;
    final value =
        10 +
        (_documentRatio * 35) +
        (_paymentRatio * 25) +
        (_internalStageRatio * 20) +
        completedBonus;

    return value.round().clamp(0, 100).toInt();
  }

  double get _documentRatio {
    final total = requiredDocumentTotal;
    if (total <= 0) {
      return _statusAfterDocuments ? 1 : 0;
    }

    return (approvedDocumentTotal / total).clamp(0, 1).toDouble();
  }

  double get _paymentRatio {
    final total = activePaymentTotal;
    if (total > 0) {
      return (approvedPaymentTotal / total).clamp(0, 1).toDouble();
    }

    if (_normalizedStatus.contains('payment under review') ||
        _normalizedStatus.contains('waiting for payment') ||
        _normalizedStatus.contains('receipt submitted')) {
      return 0;
    }

    if (_normalizedStatus.contains('paid') ||
        _normalizedStatus.contains('payment approved') ||
        _normalizedStatus.contains('in progress') ||
        _normalizedStatus.contains('complete') ||
        _normalizedStatus.contains('closed')) {
      return 1;
    }

    return 0;
  }

  double get _internalStageRatio {
    if (_normalizedStatus.contains('complete') ||
        _normalizedStatus.contains('closed')) {
      return 1;
    }
    if (_normalizedStatus.contains('in progress')) return 0.75;
    if (_normalizedStatus.contains('payment under review')) return 0.35;
    if (_normalizedStatus.contains('documents under review')) return 0.20;
    return 0;
  }

  bool get _statusAfterDocuments {
    return _normalizedStatus.contains('waiting for payment') ||
        _normalizedStatus.contains('payment') ||
        _normalizedStatus.contains('in progress') ||
        _normalizedStatus.contains('complete') ||
        _normalizedStatus.contains('closed');
  }

  String get _normalizedStatus => status.trim().toLowerCase();

  String get displayReference {
    final cleanReference = reference?.trim();
    if (cleanReference != null && cleanReference.isNotEmpty) {
      return cleanReference;
    }

    final cleanId = id.trim();
    return cleanId.isEmpty ? '-' : cleanId;
  }

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

  bool get isApproved {
    final normalized = status.trim().toLowerCase();
    return normalized.contains('approved') || normalized.contains('verified');
  }

  bool get isRejected {
    final normalized = status.trim().toLowerCase();
    return normalized.contains('rejected');
  }

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

class ServiceCasePayment {
  const ServiceCasePayment({
    required this.id,
    required this.title,
    required this.status,
    required this.amount,
    required this.currency,
    this.dueDateLabel,
    this.paidOnLabel,
    this.paymentReference,
    this.receiptUrl,
    this.remarks,
  });

  final String id;
  final String title;
  final String status;
  final double amount;
  final String currency;
  final String? dueDateLabel;
  final String? paidOnLabel;
  final String? paymentReference;
  final String? receiptUrl;
  final String? remarks;

  bool get isPaid {
    final normalized = status.trim().toLowerCase();
    return normalized == 'paid' ||
        normalized == 'approved' ||
        normalized == 'payment approved';
  }

  bool get isRejected => status.trim().toLowerCase() == 'rejected';

  bool get isCancelled => status.trim().toLowerCase() == 'cancelled';

  bool get needsCustomerAction {
    final normalized = status.trim().toLowerCase();
    return normalized == 'open' ||
        normalized == 'pending' ||
        normalized == 'rejected' ||
        normalized == 'waiting for payment';
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
