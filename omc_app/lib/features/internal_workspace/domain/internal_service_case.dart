class InternalServiceCaseFilters {
  const InternalServiceCaseFilters({
    this.search = '',
    this.status,
    this.documentStatus,
  });

  final String search;
  final String? status;
  final String? documentStatus;

  InternalServiceCaseFilters copyWith({
    String? search,
    String? status,
    String? documentStatus,
    bool clearStatus = false,
    bool clearDocumentStatus = false,
  }) {
    return InternalServiceCaseFilters(
      search: search ?? this.search,
      status: clearStatus ? null : status ?? this.status,
      documentStatus: clearDocumentStatus
          ? null
          : documentStatus ?? this.documentStatus,
    );
  }
}

class InternalServiceCaseQueue {
  const InternalServiceCaseQueue({
    required this.cases,
    required this.summary,
    required this.canReviewDocuments,
    required this.canUpdateStatus,
  });

  factory InternalServiceCaseQueue.fromResponse(Map<String, dynamic> data) {
    final message = data['message'];
    final source = message is Map<String, dynamic> ? message : data;
    final rawCases =
        source['cases'] ?? source['service_cases'] ?? source['data'];
    final rawSummary = source['summary'];
    final rawCapabilities = source['capabilities'];

    final capabilities = rawCapabilities is Map<String, dynamic>
        ? rawCapabilities
        : const <String, dynamic>{};

    return InternalServiceCaseQueue(
      cases: rawCases is List
          ? rawCases
                .whereType<Map<String, dynamic>>()
                .map(InternalServiceCase.fromJson)
                .toList(growable: false)
          : const [],
      summary: rawSummary is Map<String, dynamic>
          ? _readIntMap(rawSummary)
          : const {},
      canReviewDocuments: _readBool(capabilities['can_review_documents']),
      canUpdateStatus: _readBool(capabilities['can_update_service_status']),
    );
  }

  final List<InternalServiceCase> cases;
  final Map<String, int> summary;
  final bool canReviewDocuments;
  final bool canUpdateStatus;
}

class InternalServiceCase {
  const InternalServiceCase({
    required this.id,
    required this.customerName,
    required this.customerProfile,
    required this.serviceTitle,
    required this.status,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
    required this.documentSummaryLabel,
    required this.documentSummary,
    required this.canReviewDocuments,
    required this.canUpdateStatus,
  });

  factory InternalServiceCase.fromJson(Map<String, dynamic> json) {
    final summary = json['document_summary'];

    return InternalServiceCase(
      id: _readString(json['id'] ?? json['name'] ?? json['case_id']),
      customerName: _readString(json['customer_name']),
      customerProfile: _readString(json['customer_profile']),
      serviceTitle: _readString(
        json['service_title'] ?? json['service'] ?? json['title'],
      ),
      status: _readString(json['status']),
      priority: _readString(json['priority']),
      createdAt: _readString(json['created_at']),
      updatedAt: _readString(json['updated_at']),
      documentSummaryLabel: _readString(json['document_summary_label']),
      documentSummary: summary is Map<String, dynamic>
          ? _readIntMap(summary)
          : const {},
      canReviewDocuments: _readBool(json['can_review_documents']),
      canUpdateStatus: _readBool(json['can_update_status']),
    );
  }

  final String id;
  final String customerName;
  final String customerProfile;
  final String serviceTitle;
  final String status;
  final String priority;
  final String createdAt;
  final String updatedAt;
  final String documentSummaryLabel;
  final Map<String, int> documentSummary;
  final bool canReviewDocuments;
  final bool canUpdateStatus;

  String get displayCustomer {
    if (customerName.trim().isNotEmpty && customerName != '-') {
      return customerName;
    }
    if (customerProfile.trim().isNotEmpty && customerProfile != '-') {
      return customerProfile;
    }
    return 'Customer not linked';
  }

  String get displayService {
    if (serviceTitle.trim().isNotEmpty && serviceTitle != '-') {
      return serviceTitle;
    }
    return 'Service Request';
  }

  int get pendingDocuments => documentSummary['pending'] ?? 0;
  int get uploadedDocuments => documentSummary['uploaded'] ?? 0;
  int get approvedDocuments => documentSummary['approved'] ?? 0;
  int get rejectedDocuments => documentSummary['rejected'] ?? 0;
}

Map<String, int> _readIntMap(Map<String, dynamic> value) {
  return value.map((key, item) => MapEntry(key, _readInt(item)));
}

String _readString(dynamic value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? '-' : text;
}

int _readInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString().trim() ?? '') ?? 0;
}

bool _readBool(dynamic value) {
  if (value is bool) return value;
  final text = value?.toString().trim().toLowerCase();
  return text == 'true' || text == '1' || text == 'yes';
}
