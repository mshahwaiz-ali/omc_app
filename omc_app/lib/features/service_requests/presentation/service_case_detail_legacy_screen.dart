import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../app/mutation_invalidation.dart';
import '../../../core/forms/dirty_form_controller.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/app_back_header.dart';
import '../../../core/widgets/premium_card.dart';
import '../../auth/application/auth_controller.dart';
import '../../admin_control/data/admin_control_repository.dart';
import '../../documents/application/document_attachment_controller.dart';
import '../../documents/data/document_attachment.dart';
import '../../support/application/support_launcher.dart';
import '../data/service_case.dart';
import '../data/service_case_repository.dart';
import '../data/service_request_repository.dart';

class ServiceCaseDetailScreen extends ConsumerStatefulWidget {
  const ServiceCaseDetailScreen({
    super.key,
    required this.caseId,
    this.assisted = false,
    this.customerName,
  });

  final String caseId;
  final bool assisted;
  final String? customerName;

  @override
  ConsumerState<ServiceCaseDetailScreen> createState() =>
      _ServiceCaseDetailScreenState();
}

class _ServiceCaseDetailScreenState
    extends ConsumerState<ServiceCaseDetailScreen> {
  bool _isUploadingDocument = false;
  bool _isUpdatingDocumentStatus = false;
  bool _isCancellingRequest = false;
  bool _isAdminMutating = false;
  Future<AdminCaseOptions>? _adminOptions;

  @override
  Widget build(BuildContext context) {
    final caseAsync = ref.watch(serviceCaseDetailProvider(widget.caseId));
    final capabilities = ref.watch(authControllerProvider).capabilities;
    final canReviewDocuments = capabilities.canReviewDocuments;
    final canUploadDocuments =
        capabilities.canUploadDocuments ||
        (widget.assisted && capabilities.canUploadCustomerDocuments);
    final canCancelOwnRequest =
        capabilities.isApproved && capabilities.canTrackRequests;
    final canAdministerCase =
        capabilities.canReassignServiceCases ||
        capabilities.canRetrySync ||
        capabilities.canManageBusinessSettings;
    if (canAdministerCase) {
      _adminOptions ??= ref
          .read(adminControlRepositoryProvider)
          .fetchCaseOptions(widget.caseId);
    }

    return Scaffold(
      body: Column(
        children: [
          AppBackHeader(
            title: 'Service Request',
            subtitle: 'Progress, documents, payments and activity',
            actionIcon: Icons.support_agent_rounded,
            actionTooltip: 'Contact support',
            onAction: () => SupportLauncher.openWhatsApp(context),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: caseAsync.when(
                loading: () => const _LoadingView(),
                error: (error, stackTrace) {
                  final failure = AppFailureClassifier.classify(
                    error,
                    fallbackTitle: 'Tracking detail unavailable',
                    fallbackMessage:
                        'This service request could not be loaded right now.',
                  );
                  return _ErrorView(
                    title: failure.title,
                    message: failure.message,
                    onRetry: failure.canRetry
                        ? () => ref.invalidate(
                            serviceCaseDetailProvider(widget.caseId),
                          )
                        : null,
                    onSupport: () => SupportLauncher.openWhatsApp(context),
                  );
                },
                data: (serviceCase) {
                  if (serviceCase == null) {
                    return _ErrorView(
                      title: 'Case not found',
                      message:
                          'This tracking reference may no longer be available.',
                      onRetry: () => ref.invalidate(
                        serviceCaseDetailProvider(widget.caseId),
                      ),
                      onSupport: () => SupportLauncher.openWhatsApp(context),
                    );
                  }

                  return ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 30),
                    children: [
                      _CaseHero(serviceCase: serviceCase),
                      const SizedBox(height: 12),
                      _RequestAttributionNotice(
                        serviceCase: serviceCase,
                        isInternal:
                            capabilities.canAccessInternalWorkspace ||
                            capabilities.isInternal,
                      ),
                      const SizedBox(height: 14),
                      _ProgressCard(serviceCase: serviceCase),
                      if (canAdministerCase) ...[
                        const SizedBox(height: 14),
                        FutureBuilder<AdminCaseOptions>(
                          future: _adminOptions,
                          builder: (context, snapshot) => _AdminOperationsCard(
                            data: snapshot.data?.data,
                            loading:
                                snapshot.connectionState ==
                                ConnectionState.waiting,
                            busy: _isAdminMutating,
                            canReassign: capabilities.canReassignServiceCases,
                            canRetry: capabilities.canRetrySync,
                            canReviewDiscount:
                                capabilities.canManageBusinessSettings,
                            onReassign: snapshot.hasData
                                ? () => _reassignCase(snapshot.data!.data)
                                : null,
                            onRetry: _retrySync,
                            onReviewDiscount: snapshot.hasData
                                ? (approve) => _reviewDiscount(
                                    snapshot.data!.data,
                                    approve,
                                  )
                                : null,
                          ),
                        ),
                      ],
                      const SizedBox(height: 14),
                      _CaseActionsCard(
                        serviceCase: serviceCase,
                        assisted: widget.assisted,
                        customerName: widget.customerName,
                        canViewDocuments: widget.assisted
                            ? capabilities.canViewCustomerDocuments
                            : capabilities.canViewDocuments,
                        isUploading: _isUploadingDocument,
                        onUploadMissingDocument:
                            !serviceCase.isHistoricalRequest &&
                                canUploadDocuments
                            ? () => _showUploadDocumentSheet(serviceCase)
                            : null,
                        isCancelling: _isCancellingRequest,
                        onCancelRequest:
                            !serviceCase.isHistoricalRequest &&
                                canCancelOwnRequest &&
                                serviceCase.canCancel
                            ? () => _confirmCancelServiceRequest(serviceCase)
                            : null,
                      ),
                      const SizedBox(height: 14),
                      _RequiredDocumentsCard(
                        serviceCase: serviceCase,
                        isUpdatingDocumentStatus: _isUpdatingDocumentStatus,
                        onUpdateDocumentStatus:
                            !serviceCase.isHistoricalRequest &&
                                canReviewDocuments &&
                                serviceCase.canReviewDocuments &&
                                !_isUpdatingDocumentStatus
                            ? (document, status) =>
                                  _updateServiceDocumentStatus(
                                    serviceCase,
                                    document,
                                    status,
                                  )
                            : null,
                      ),
                      const SizedBox(height: 14),
                      _CaseInfoCard(serviceCase: serviceCase),
                      if (_RecentActivityCard.hasActivity(serviceCase)) ...[
                        const SizedBox(height: 14),
                        _RecentActivityCard(serviceCase: serviceCase),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _reassignCase(Map<String, dynamic> options) async {
    final candidates = (options['assignment_candidates'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
    if (candidates.isEmpty) {
      _showSnack('No enabled, assignable operational staff are available.');
      return;
    }
    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('Reassign service request'),
        children: [
          for (final candidate in candidates)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(
                dialogContext,
                candidate['user_id']?.toString(),
              ),
              child: Text('${candidate['full_name']}\n${candidate['user_id']}'),
            ),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    await _runAdminMutation(
      () => ref
          .read(adminControlRepositoryProvider)
          .reassignCase(widget.caseId, selected),
      'Service request reassigned.',
    );
  }

  Future<void> _retrySync() async {
    await _runAdminMutation(
      () => ref.read(adminControlRepositoryProvider).retrySync(widget.caseId),
      'ERP synchronization retry completed.',
    );
  }

  Future<void> _reviewDiscount(
    Map<String, dynamic> options,
    bool approve,
  ) async {
    if (options['discount_status'] != 'Pending Approval') {
      _showSnack('This request has no discount awaiting approval.');
      return;
    }
    String? reason;
    if (!approve) {
      reason = await showDialog<String>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const _DiscountRejectionDialog(),
      );
      if (reason == null || !mounted) return;
    }
    await _runAdminMutation(
      () => ref
          .read(adminControlRepositoryProvider)
          .reviewDiscount(widget.caseId, approve: approve, reason: reason),
      approve ? 'Discount approved.' : 'Discount rejected.',
    );
  }

  Future<void> _runAdminMutation(
    Future<void> Function() mutation,
    String successMessage,
  ) async {
    if (_isAdminMutating) return;
    setState(() => _isAdminMutating = true);
    try {
      await mutation();
      if (!mounted) return;
      invalidateAdministrativeCaseMutation(ref, caseId: widget.caseId);
      setState(() {
        _adminOptions = ref
            .read(adminControlRepositoryProvider)
            .fetchCaseOptions(widget.caseId);
      });
      _showSnack(successMessage);
    } catch (error) {
      if (mounted) {
        _showSnack(
          _safeMutationMessage(error, 'Administrative action failed.'),
        );
      }
    } finally {
      if (mounted) setState(() => _isAdminMutating = false);
    }
  }

  Future<void> _confirmCancelServiceRequest(ServiceCase serviceCase) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel request?'),
        content: const Text(
          'This will cancel this service request. You can start a new request later if needed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep request'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Cancel request'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _cancelServiceRequest(serviceCase);
    }
  }

  Future<void> _cancelServiceRequest(ServiceCase serviceCase) async {
    if (_isCancellingRequest) return;

    if (serviceCase.isHistoricalRequest) {
      _showSnack('Historical service records are read-only.');
      return;
    }

    final capabilities = ref.read(authControllerProvider).capabilities;
    if (!capabilities.isApproved || !capabilities.canTrackRequests) {
      _showSnack('Your account cannot cancel this service request.');
      return;
    }

    final caseId = _uploadDocnameFor(serviceCase);
    if (caseId == null) {
      _showSnack(
        'Cancel cannot continue because this case is missing its service reference.',
      );
      return;
    }

    setState(() => _isCancellingRequest = true);

    try {
      final repository = ref.read(serviceCaseRepositoryProvider);
      await repository.cancelServiceRequest(caseId: caseId);

      if (!mounted) return;
      ref.invalidate(serviceCaseDetailProvider(widget.caseId));
      ref.invalidate(serviceCasesProvider);
      _showSnack('Service request cancelled successfully.');
    } catch (error) {
      if (!mounted) return;
      _showSnack(
        _safeMutationMessage(
          error,
          'Service request could not be cancelled right now.',
        ),
      );
    } finally {
      if (mounted) setState(() => _isCancellingRequest = false);
    }
  }

  Future<void> _updateServiceDocumentStatus(
    ServiceCase serviceCase,
    ServiceCaseDocument document,
    String status,
  ) async {
    if (_isUpdatingDocumentStatus) return;

    if (serviceCase.isHistoricalRequest) {
      _showSnack('Historical service records are read-only.');
      return;
    }

    if (!ref.read(authControllerProvider).capabilities.canReviewDocuments) {
      _showSnack(
        'Your role can view document information but cannot review files.',
      );
      return;
    }

    if (!document.hasRealId) {
      _showSnack('Document status cannot be updated without document ID.');
      return;
    }

    setState(() => _isUpdatingDocumentStatus = true);

    try {
      final repository = ref.read(serviceCaseRepositoryProvider);
      await repository.updateServiceDocumentStatus(
        documentId: document.id,
        status: status,
      );

      if (!mounted) return;
      ref.invalidate(serviceCaseDetailProvider(widget.caseId));
      ref.invalidate(serviceCasesProvider);
      _showSnack('${document.title} marked as $status.');
    } catch (error) {
      if (!mounted) return;
      _showSnack(
        _safeMutationMessage(
          error,
          'Document status could not be updated right now.',
        ),
      );
    } finally {
      if (mounted) setState(() => _isUpdatingDocumentStatus = false);
    }
  }

  Future<void> _showUploadDocumentSheet(ServiceCase serviceCase) async {
    if (_isUploadingDocument) return;

    if (serviceCase.isHistoricalRequest) {
      _showSnack('Historical service records are read-only.');
      return;
    }

    final capabilities = ref.read(authControllerProvider).capabilities;
    final canUploadDocuments =
        capabilities.canUploadDocuments ||
        (widget.assisted && capabilities.canUploadCustomerDocuments);

    if (!canUploadDocuments) {
      _showSnack('Your account cannot upload documents for this request.');
      return;
    }

    final options = _uploadDocumentOptions(serviceCase);
    if (options.isEmpty) {
      _showSnack('No required documents are available for upload.');
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _DocumentUploadSheet(
        documents: options,
        onPickDocument: () =>
            ref.read(documentAttachmentControllerProvider).pickDocuments(),
        onUpload: (document, attachment) =>
            _uploadSelectedDocument(serviceCase, document, attachment),
      ),
    );
  }

  Future<void> _uploadSelectedDocument(
    ServiceCase serviceCase,
    ServiceCaseDocument document,
    DocumentAttachment attachment,
  ) async {
    if (_isUploadingDocument) return;

    if (serviceCase.isHistoricalRequest) {
      _showSnack('Historical service records are read-only.');
      return;
    }

    final uploadDocname = _uploadDocnameFor(serviceCase);
    if (uploadDocname == null) {
      _showSnack(
        'Upload cannot continue because this case is missing its service reference.',
      );
      return;
    }

    setState(() => _isUploadingDocument = true);

    try {
      final repository = ref.read(serviceRequestRepositoryProvider);
      final uploadedFiles = await repository.uploadRequestAttachments(
        requestId: uploadDocname,
        attachments: [attachment],
        documentTitle: document.title,
        documentType: document.type,
      );

      if (!mounted) return;
      ref.invalidate(serviceCaseDetailProvider(widget.caseId));
      ref.invalidate(serviceCasesProvider);

      _showSnack(
        uploadedFiles.isNotEmpty
            ? '${document.title} uploaded successfully.'
            : 'Document upload completed, but no saved file was returned.',
      );
    } catch (error) {
      if (!mounted) return;
      _showSnack(
        _safeMutationMessage(
          error,
          'Missing document could not be uploaded right now. Please try again.',
        ),
      );
      rethrow;
    } finally {
      if (mounted) setState(() => _isUploadingDocument = false);
    }
  }

  List<ServiceCaseDocument> _uploadDocumentOptions(ServiceCase serviceCase) {
    final details = serviceCase.documentDetails;
    if (details.isNotEmpty) {
      final openDocuments = details
          .where((document) => !document.isSubmitted)
          .toList(growable: false);
      return openDocuments.isNotEmpty ? openDocuments : details;
    }

    final names = serviceCase.requiredDocuments.isNotEmpty
        ? serviceCase.requiredDocuments
        : serviceCase.missingDocuments;

    return names
        .where((name) => name.trim().isNotEmpty)
        .map(
          (name) => ServiceCaseDocument(
            id: '-',
            title: name.trim(),
            type: '',
            status: serviceCase.submittedDocuments.contains(name)
                ? 'Uploaded'
                : 'Required',
          ),
        )
        .toList(growable: false);
  }

  String? _uploadDocnameFor(ServiceCase serviceCase) {
    final reference = serviceCase.reference?.trim();
    if (reference != null && reference.isNotEmpty) return reference;

    final id = serviceCase.id.trim();
    if (id.isNotEmpty && id != '-') return id;

    return null;
  }

  String _safeMutationMessage(Object error, String fallbackMessage) {
    return AppFailureClassifier.classify(
      error,
      fallbackMessage: fallbackMessage,
    ).message;
  }

  void _showSnack(String message) {
    if (!mounted || message.trim().isEmpty) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message.trim())));
  }
}

class _DiscountRejectionDialog extends StatefulWidget {
  const _DiscountRejectionDialog();

  @override
  State<_DiscountRejectionDialog> createState() =>
      _DiscountRejectionDialogState();
}

class _DiscountRejectionDialogState extends State<_DiscountRejectionDialog> {
  final _controller = TextEditingController();
  final _dirtyFormController = DirtyFormController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    _dirtyFormController.dispose();
    super.dispose();
  }

  void _onChanged() {
    _dirtyFormController.markDirty();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final reason = _controller.text.trim();
    return UnsavedChangesGuard(
      controller: _dirtyFormController,
      child: AlertDialog(
        title: const Text('Reject discount request?'),
        content: TextField(
          controller: _controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Review remarks',
            hintText: 'Explain why this discount cannot be approved.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: reason.isEmpty
                ? null
                : () {
                    _dirtyFormController.submissionSucceeded();
                    Navigator.pop(context, reason);
                  },
            child: const Text('Reject discount'),
          ),
        ],
      ),
    );
  }
}

class _RequestAttributionNotice extends StatelessWidget {
  const _RequestAttributionNotice({
    required this.serviceCase,
    required this.isInternal,
  });

  final ServiceCase serviceCase;
  final bool isInternal;

  @override
  Widget build(BuildContext context) {
    final customerName = serviceCase.displayCustomerName;
    final internalCreatorValue = serviceCase.submittedByInternalName?.trim();
    final internalCreator =
        internalCreatorValue == null || internalCreatorValue.isEmpty
        ? null
        : internalCreatorValue;

    final creatorNameValue = serviceCase.submittedByName?.trim();
    final creatorName = creatorNameValue == null || creatorNameValue.isEmpty
        ? null
        : creatorNameValue;
    final mode = serviceCase.internalCustomerModeLabel;

    late final String title;
    String? subtitle;

    if (isInternal) {
      if (serviceCase.createdOnBehalf) {
        final creator = internalCreator ?? creatorName ?? 'OMC staff';
        title = 'Created by $creator for $customerName';
        subtitle = mode;
      } else {
        title = 'Created by ${creatorName ?? customerName}';
        subtitle = 'Customer submitted';
      }
    } else if (serviceCase.createdOnBehalf) {
      final creator = internalCreator ?? creatorName ?? 'OMC team';
      title = 'Created by $creator from OMC on your behalf';
    } else {
      title = 'Submitted by you';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F7F4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD8E9DF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.account_circle_outlined,
            size: 20,
            color: Color(0xFF168D49),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12.5,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (subtitle?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentUploadSheet extends StatefulWidget {
  const _DocumentUploadSheet({
    required this.documents,
    required this.onPickDocument,
    required this.onUpload,
  });

  final List<ServiceCaseDocument> documents;
  final Future<DocumentPickResult> Function() onPickDocument;
  final Future<void> Function(
    ServiceCaseDocument document,
    DocumentAttachment attachment,
  )
  onUpload;

  @override
  State<_DocumentUploadSheet> createState() => _DocumentUploadSheetState();
}

class _DocumentUploadSheetState extends State<_DocumentUploadSheet> {
  late ServiceCaseDocument _selectedDocument;
  DocumentAttachment? _selectedAttachment;
  final _dirtyFormController = DirtyFormController();
  bool _isPicking = false;
  bool _isUploading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedDocument = widget.documents.first;
  }

  @override
  void dispose() {
    _dirtyFormController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return PopScope<Object?>(
      canPop: !_isPicking && !_isUploading,
      child: UnsavedChangesGuard(
        controller: _dirtyFormController,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.88,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD8DDE3),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFFE9F7EE),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: const Icon(
                            Icons.upload_file_outlined,
                            color: Color(0xFF168D49),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 13),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Upload required document',
                                style: TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 19,
                                  height: 1.2,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Choose the required document type and attach the correct file.',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12.5,
                                  height: 1.4,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Document type',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<ServiceCaseDocument>(
                      initialValue: _selectedDocument,
                      isExpanded: true,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppTheme.textSecondary,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: AppTheme.background,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 15,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.black.withValues(alpha: 0.06),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.black.withValues(alpha: 0.06),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFF168D49),
                            width: 1.3,
                          ),
                        ),
                      ),
                      items: widget.documents
                          .map(
                            (document) => DropdownMenuItem(
                              value: document,
                              child: Text(
                                document.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: _isUploading
                          ? null
                          : (document) {
                              if (document == null) return;

                              setState(() {
                                _selectedDocument = document;
                                _errorMessage = null;
                              });
                            },
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      'Attachment',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _SelectedFileTile(
                      attachment: _selectedAttachment,
                      isPicking: _isPicking,
                      onChoose: _isUploading ? null : _chooseFile,
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.055),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.10),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.error_outline_rounded,
                              color: AppTheme.primary,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: AppTheme.primary,
                                  fontSize: 11.5,
                                  height: 1.35,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 50,
                      child: FilledButton.icon(
                        onPressed: _isUploading ? null : _upload,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF159447),
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(
                            0xFF159447,
                          ).withValues(alpha: 0.45),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        icon: _isUploading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.cloud_upload_outlined, size: 20),
                        label: Text(
                          _isUploading ? 'Uploading...' : 'Upload document',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: _isUploading
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _chooseFile() async {
    setState(() {
      _isPicking = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.onPickDocument();

      if (!mounted) return;

      if (result.hasRejectedFiles) {
        setState(() => _errorMessage = result.rejectedMessages.join('\n'));
      }

      if (result.hasAcceptedFiles) {
        _dirtyFormController.markDirty();
        setState(() {
          _selectedAttachment = result.accepted.first;
          _errorMessage = null;
        });
      }
    } catch (_) {
      if (!mounted) return;

      setState(() => _errorMessage = 'File picker could not open right now.');
    } finally {
      if (mounted) {
        setState(() => _isPicking = false);
      }
    }
  }

  Future<void> _upload() async {
    final attachment = _selectedAttachment;

    if (attachment == null) {
      setState(() => _errorMessage = 'Choose a file before uploading.');
      return;
    }

    if (!attachment.hasUploadData) {
      setState(
        () => _errorMessage =
            'Selected file data is unavailable. Choose the file again.',
      );
      return;
    }

    _dirtyFormController.beginSubmitting();
    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      await widget.onUpload(_selectedDocument, attachment);

      if (!mounted) return;

      _dirtyFormController.submissionSucceeded();
      Navigator.of(context).pop();
    } catch (error) {
      _dirtyFormController.submissionFailed();
      if (!mounted) return;

      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isUploading = false);
      }
    }
  }
}

class _SelectedFileTile extends StatelessWidget {
  const _SelectedFileTile({
    required this.attachment,
    required this.isPicking,
    required this.onChoose,
  });

  final DocumentAttachment? attachment;
  final bool isPicking;
  final VoidCallback? onChoose;

  @override
  Widget build(BuildContext context) {
    final fileName = attachment?.name.trim();
    final hasFile = fileName != null && fileName.isNotEmpty;

    return InkWell(
      onTap: isPicking ? null : onChoose,
      borderRadius: BorderRadius.circular(17),
      child: Ink(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: hasFile ? const Color(0xFFF2FAF5) : AppTheme.background,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: hasFile
                ? const Color(0xFF168D49).withValues(alpha: 0.20)
                : Colors.black.withValues(alpha: 0.065),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: hasFile ? const Color(0xFFE1F4E8) : Colors.white,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: Colors.black.withValues(alpha: 0.045),
                ),
              ),
              child: Icon(
                hasFile
                    ? Icons.description_outlined
                    : Icons.attach_file_rounded,
                color: hasFile
                    ? const Color(0xFF168D49)
                    : AppTheme.textSecondary,
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasFile ? fileName : 'Choose a file',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasFile ? 'Ready to upload' : 'PDF, JPG or PNG document',
                    style: TextStyle(
                      color: hasFile
                          ? const Color(0xFF168D49)
                          : AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (isPicking)
              const SizedBox(
                width: 19,
                height: 19,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF168D49),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: hasFile
                        ? const Color(0xFF168D49).withValues(alpha: 0.18)
                        : Colors.black.withValues(alpha: 0.08),
                  ),
                ),
                child: Text(
                  hasFile ? 'Change' : 'Browse',
                  style: TextStyle(
                    color: hasFile
                        ? const Color(0xFF168D49)
                        : AppTheme.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.title,
    required this.message,
    this.onRetry,
    required this.onSupport,
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final VoidCallback onSupport;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: PremiumCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: AppTheme.primary,
                size: 42,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              if (onRetry != null)
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Retry'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onSupport,
                        icon: const Icon(Icons.support_agent_rounded),
                        label: const Text('Support'),
                      ),
                    ),
                  ],
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: onSupport,
                    icon: const Icon(Icons.support_agent_rounded),
                    label: const Text('Contact support'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminOperationsCard extends StatelessWidget {
  const _AdminOperationsCard({
    required this.data,
    required this.loading,
    required this.busy,
    required this.canReassign,
    required this.canRetry,
    required this.canReviewDiscount,
    required this.onReassign,
    required this.onRetry,
    required this.onReviewDiscount,
  });

  final Map<String, dynamic>? data;
  final bool loading;
  final bool busy;
  final bool canReassign;
  final bool canRetry;
  final bool canReviewDiscount;
  final VoidCallback? onReassign;
  final VoidCallback onRetry;
  final ValueChanged<bool>? onReviewDiscount;

  @override
  Widget build(BuildContext context) {
    final discountPending = data?['discount_status'] == 'Pending Approval';
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Operational controls',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          if (loading)
            const LinearProgressIndicator()
          else ...[
            Text('Assigned to: ${data?['assigned_staff'] ?? 'Unassigned'}'),
            Text('ERP sync: ${data?['erp_sync_status'] ?? 'Not started'}'),
            if (discountPending)
              Text(
                'Discount: PKR ${data?['original_price']} → PKR ${data?['proposed_final_price']}',
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (canReassign)
                  OutlinedButton.icon(
                    onPressed: busy ? null : onReassign,
                    icon: const Icon(Icons.person_search_rounded),
                    label: const Text('Reassign'),
                  ),
                if (canRetry)
                  OutlinedButton.icon(
                    onPressed: busy ? null : onRetry,
                    icon: const Icon(Icons.sync_rounded),
                    label: const Text('Retry ERP sync'),
                  ),
                if (canReviewDiscount && discountPending) ...[
                  FilledButton(
                    onPressed: busy || onReviewDiscount == null
                        ? null
                        : () => onReviewDiscount!(true),
                    child: const Text('Approve discount'),
                  ),
                  TextButton(
                    onPressed: busy || onReviewDiscount == null
                        ? null
                        : () => onReviewDiscount!(false),
                    child: const Text('Reject discount'),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CaseHero extends StatelessWidget {
  const _CaseHero({required this.serviceCase});

  final ServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    final statusStyle = _caseStatusVisual(serviceCase.statusLabel);
    final category = serviceCase.category.trim();
    final remarks = serviceCase.remarks?.trim() ?? '';

    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 560;

            final serviceIcon = Container(
              width: compact ? 68 : 78,
              height: compact ? 68 : 78,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primary.withValues(alpha: 0.14),
                    AppTheme.primary.withValues(alpha: 0.055),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(compact ? 21 : 24),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.10),
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: compact ? 34 : 39,
                    color: AppTheme.primary,
                  ),
                  Positioned(
                    right: compact ? 8 : 9,
                    bottom: compact ? 8 : 9,
                    child: Container(
                      width: 19,
                      height: 19,
                      decoration: const BoxDecoration(
                        color: AppTheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 13,
                      ),
                    ),
                  ),
                ],
              ),
            );

            final content = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        serviceCase.title,
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: compact ? 21 : 24,
                          height: 1.13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.35,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _CaseStatusBadge(
                      label: serviceCase.statusLabel,
                      color: statusStyle.color,
                      background: statusStyle.background,
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  category.isEmpty ? 'OMC Professional Service' : category,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  remarks.isEmpty
                      ? 'Track the complete progress of your service request.'
                      : remarks,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12.5,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    _HeroMeta(
                      icon: Icons.confirmation_number_outlined,
                      label: 'Request ID',
                      value: serviceCase.displayReference,
                    ),
                    _HeroMeta(
                      icon: Icons.calendar_today_outlined,
                      label: 'Requested',
                      value: serviceCase.createdAtLabel,
                    ),
                    _HeroMeta(
                      icon: Icons.update_rounded,
                      label: 'Last update',
                      value: serviceCase.updatedAtLabel,
                    ),
                  ],
                ),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [serviceIcon, const SizedBox(height: 16), content],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                serviceIcon,
                const SizedBox(width: 18),
                Expanded(child: content),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _HeroMeta extends StatelessWidget {
  const _HeroMeta({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 118, maxWidth: 220),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 31,
            height: 31,
            decoration: BoxDecoration(
              color: AppTheme.background,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
            ),
            child: Icon(icon, size: 16, color: AppTheme.textSecondary),
          ),
          const SizedBox(width: 9),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value.trim().isEmpty ? '-' : value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CaseStatusBadge extends StatelessWidget {
  const _CaseStatusBadge({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

({Color color, Color background}) _caseStatusVisual(String status) {
  final value = status.trim().toLowerCase();

  if (value.contains('complete') ||
      value.contains('approved') ||
      value.contains('closed')) {
    return (
      color: const Color(0xFF16864B),
      background: const Color(0xFFEAF7EF),
    );
  }

  if (value.contains('progress') ||
      value.contains('review') ||
      value.contains('processing')) {
    return (
      color: const Color(0xFF138A4B),
      background: const Color(0xFFE8F6ED),
    );
  }

  if (value.contains('waiting') || value.contains('pending')) {
    return (
      color: const Color(0xFFA85C00),
      background: const Color(0xFFFFF4E4),
    );
  }

  if (value.contains('cancel') || value.contains('reject')) {
    return (
      color: const Color(0xFFC62828),
      background: const Color(0xFFFFEBEE),
    );
  }

  return (color: AppTheme.textSecondary, background: AppTheme.background);
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.serviceCase});

  final ServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    final progress = serviceCase.progress.clamp(0, 1).toDouble();
    final progressPercent =
        serviceCase.progressPercent ?? (progress * 100).round();
    final steps = _milestoneSteps(serviceCase);
    final activeIndex = _activeTimelineIndex(steps);

    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 640;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (compact) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Expanded(
                      child: Text(
                        'Overall progress',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Text(
                      '$progressPercent%',
                      style: const TextStyle(
                        color: Color(0xFF129447),
                        fontSize: 25,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
              ] else
                Row(
                  children: [
                    SizedBox(
                      width: 172,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Overall progress',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$progressPercent%',
                            style: const TextStyle(
                              color: Color(0xFF129447),
                              fontSize: 34,
                              height: 1,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${steps.where((step) => step.isDone).length} of '
                            '${steps.length} steps completed',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 82,
                      margin: const EdgeInsets.only(right: 20),
                      color: Colors.black.withValues(alpha: 0.06),
                    ),
                    Expanded(
                      child: _HorizontalProgressContent(
                        progress: progress,
                        steps: steps,
                        activeIndex: activeIndex,
                      ),
                    ),
                  ],
                ),
              if (compact) ...[
                _HorizontalProgressContent(
                  progress: progress,
                  steps: steps,
                  activeIndex: activeIndex,
                ),
                const SizedBox(height: 10),
                Text(
                  '${steps.where((step) => step.isDone).length} of '
                  '${steps.length} steps completed',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  List<ServiceCaseTimelineStep> _milestoneSteps(ServiceCase serviceCase) {
    final milestones = serviceCase.milestones.map((value) {
      return value.trim().toLowerCase();
    }).toSet();

    final currentStage = serviceCase.currentStage?.trim().toLowerCase() ?? '';
    final completed = serviceCase.isCompletedRequest;

    bool has(String milestone) => milestones.contains(milestone);

    final informationDone = has('request_created');

    final documentsDone =
        has('documents_uploaded') || serviceCase.documentsComplete;
    final documentsActive =
        !documentsDone &&
        (currentStage == 'documents' ||
            has('documents_requested') ||
            has('documents_submitted'));

    final reviewDone =
        documentsDone &&
        (has('payment_opened') ||
            has('payment_paid') ||
            has('work_started') ||
            currentStage == 'processing' ||
            completed);

    final reviewActive =
        documentsDone &&
        !reviewDone &&
        (currentStage == 'payment' || has('receipt_submitted'));

    final processingDone = has('service_completed') || completed;
    final processingActive =
        !processingDone &&
        (currentStage == 'processing' || has('work_started'));

    return [
      ServiceCaseTimelineStep(
        title: 'Information',
        subtitle: informationDone ? 'Completed' : 'Pending',
        isDone: informationDone,
        isActive: !informationDone,
      ),
      ServiceCaseTimelineStep(
        title: 'Documents',
        subtitle: documentsDone
            ? 'Completed'
            : documentsActive
            ? 'In progress'
            : 'Pending',
        isDone: documentsDone,
        isActive: documentsActive,
      ),
      ServiceCaseTimelineStep(
        title: 'Payment',
        subtitle: reviewDone
            ? 'Completed'
            : reviewActive
            ? 'In progress'
            : 'Pending',
        isDone: reviewDone,
        isActive: reviewActive,
      ),
      ServiceCaseTimelineStep(
        title: 'Processing',
        subtitle: processingDone
            ? 'Completed'
            : processingActive
            ? 'In progress'
            : 'Pending',
        isDone: processingDone,
        isActive: processingActive,
      ),
      ServiceCaseTimelineStep(
        title: 'Completion',
        subtitle: completed ? 'Completed' : 'Pending',
        isDone: completed,
        isActive: false,
      ),
    ];
  }

  int _activeTimelineIndex(List<ServiceCaseTimelineStep> steps) {
    final activeIndex = steps.indexWhere((step) => step.isActive);
    if (activeIndex >= 0) return activeIndex;

    final firstIncomplete = steps.indexWhere((step) => !step.isDone);
    if (firstIncomplete >= 0) return firstIncomplete;

    return steps.isEmpty ? 0 : steps.length - 1;
  }
}

class _HorizontalProgressContent extends StatelessWidget {
  const _HorizontalProgressContent({
    required this.progress,
    required this.steps,
    required this.activeIndex,
  });

  final double progress;
  final List<ServiceCaseTimelineStep> steps;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: const Color(0xFFE9EEF1),
            valueColor: const AlwaysStoppedAnimation(Color(0xFF18A153)),
          ),
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < steps.length; index++)
              Expanded(
                child: _HorizontalProgressStep(
                  step: steps[index],
                  number: index + 1,
                  isActive: index == activeIndex,
                  showConnector: index != steps.length - 1,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _HorizontalProgressStep extends StatelessWidget {
  const _HorizontalProgressStep({
    required this.step,
    required this.number,
    required this.isActive,
    required this.showConnector,
  });

  final ServiceCaseTimelineStep step;
  final int number;
  final bool isActive;
  final bool showConnector;

  @override
  Widget build(BuildContext context) {
    const success = Color(0xFF16994C);
    const pending = Color(0xFFCBD3DC);

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            if (showConnector)
              Positioned(
                left: 26,
                right: -26,
                child: Container(
                  height: 1.5,
                  color: step.isDone
                      ? success.withValues(alpha: 0.45)
                      : pending,
                ),
              ),
            Container(
              width: 29,
              height: 29,
              decoration: BoxDecoration(
                color: step.isDone
                    ? const Color(0xFFE9F8EF)
                    : isActive
                    ? success
                    : Colors.white,
                shape: BoxShape.circle,
                border: Border.all(
                  color: step.isDone || isActive ? success : pending,
                  width: 1.5,
                ),
                boxShadow: isActive
                    ? [
                        BoxShadow(
                          color: success.withValues(alpha: 0.18),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: step.isDone
                    ? const Icon(Icons.check_rounded, color: success, size: 17)
                    : Text(
                        '$number',
                        style: TextStyle(
                          color: isActive
                              ? Colors.white
                              : AppTheme.textSecondary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          step.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 10.5,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          step.subtitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isActive ? success : AppTheme.textSecondary,
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({required this.serviceCase});

  final ServiceCase serviceCase;

  static bool hasActivity(ServiceCase serviceCase) {
    return _activitySteps(serviceCase).isNotEmpty;
  }

  static List<ServiceCaseTimelineStep> _activitySteps(ServiceCase serviceCase) {
    final fixedTitles = {
      'request received',
      'documents review',
      'payment review',
      'omc processing',
      'completed',
      'expected completion',
    };

    return serviceCase.timeline
        .where((step) {
          final title = step.title.trim();
          if (title.isEmpty) return false;
          return !fixedTitles.contains(title.toLowerCase());
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final activity = _activitySteps(serviceCase);
    if (activity.isEmpty) return const SizedBox.shrink();

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recent activity',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Latest customer and OMC updates for this request.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          for (var index = 0; index < activity.length; index++)
            _ActivityRow(
              step: activity[index],
              isLast: index == activity.length - 1,
            ),
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.step, required this.isLast});

  final ServiceCaseTimelineStep step;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.10),
              ),
            ),
            child: Icon(
              _activityIcon(step.title),
              color: AppTheme.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    step.subtitle,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12.2,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _activityIcon(String title) {
    final normalized = title.trim().toLowerCase();

    if (normalized.contains('document')) return Icons.description_outlined;
    if (normalized.contains('payment') || normalized.contains('receipt')) {
      return Icons.receipt_long_outlined;
    }
    if (normalized.contains('message') || normalized.contains('comment')) {
      return Icons.support_agent_rounded;
    }
    if (normalized.contains('created') || normalized.contains('received')) {
      return Icons.flag_outlined;
    }
    if (normalized.contains('cancel')) return Icons.cancel_outlined;
    if (normalized.contains('complete')) return Icons.check_circle_outline;

    return Icons.update_rounded;
  }
}

class _CaseInfoCard extends StatelessWidget {
  const _CaseInfoCard({required this.serviceCase});

  final ServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    final summaryParts = <String>[
      serviceCase.statusLabel,
      if (serviceCase.currentStage?.trim().isNotEmpty == true)
        serviceCase.currentStage!.trim(),
      'Updated ${serviceCase.updatedAtLabel}',
    ];

    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFF2F4F7),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: AppTheme.textSecondary,
              size: 21,
            ),
          ),
          title: const Text(
            'Case information',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          subtitle: Text(
            summaryParts.join(' · '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          children: [
            _InfoRow(label: 'Reference', value: serviceCase.displayReference),
            _InfoRow(label: 'Status', value: serviceCase.statusLabel),
            if (serviceCase.requestState?.trim().isNotEmpty == true)
              _InfoRow(
                label: 'Request state',
                value: serviceCase.lifecycleState,
              ),
            if (serviceCase.operationalStatus?.trim().isNotEmpty == true)
              _InfoRow(
                label: 'Operational status',
                value: serviceCase.effectiveOperationalStatus,
              ),
            _InfoRow(label: 'Created', value: serviceCase.createdAtLabel),
            _InfoRow(label: 'Updated', value: serviceCase.updatedAtLabel),
            if (serviceCase.currentStage?.trim().isNotEmpty == true)
              _InfoRow(label: 'Stage', value: serviceCase.currentStage!.trim()),
            if (serviceCase.nextStep?.trim().isNotEmpty == true)
              _InfoRow(label: 'Next step', value: serviceCase.nextStep!.trim()),
            if (serviceCase.remarks?.trim().isNotEmpty == true)
              _InfoRow(label: 'Remarks', value: serviceCase.remarks!.trim()),
          ],
        ),
      ),
    );
  }
}

class _RequiredDocumentsCard extends StatelessWidget {
  const _RequiredDocumentsCard({
    required this.serviceCase,
    required this.isUpdatingDocumentStatus,
    required this.onUpdateDocumentStatus,
  });

  final ServiceCase serviceCase;
  final bool isUpdatingDocumentStatus;
  final void Function(ServiceCaseDocument document, String status)?
  onUpdateDocumentStatus;

  @override
  Widget build(BuildContext context) {
    final documentDetails = _sortedDocumentDetails(serviceCase.documentDetails);
    final documents = _documentsForCase(serviceCase);

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Required documents',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Track submitted, missing and required documents for this case.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          if (documentDetails.isNotEmpty)
            for (final document in documentDetails)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DocumentRequirementRow(
                  label: document.title,
                  isSubmitted: document.isSubmitted,
                  isMissing: document.isMissing,
                  status: document.status,
                  fileUrl: document.fileUrl,
                  remarks: document.remarks,
                  canReview:
                      document.hasRealId && onUpdateDocumentStatus != null,
                  isUpdating: isUpdatingDocumentStatus,
                  onApprove: () =>
                      onUpdateDocumentStatus?.call(document, 'Approved'),
                  onReject: () =>
                      onUpdateDocumentStatus?.call(document, 'Rejected'),
                ),
              )
          else
            for (final document in documents)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _DocumentRequirementRow(
                  label: document,
                  isSubmitted: serviceCase.submittedDocuments.contains(
                    document,
                  ),
                  isMissing: serviceCase.missingDocuments.contains(document),
                ),
              ),
        ],
      ),
    );
  }

  List<ServiceCaseDocument> _sortedDocumentDetails(
    List<ServiceCaseDocument> documents,
  ) {
    final sorted = [...documents];
    sorted.sort((a, b) {
      final aRank = a.isSubmitted ? 1 : 0;
      final bRank = b.isSubmitted ? 1 : 0;
      if (aRank != bRank) return aRank.compareTo(bRank);
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });
    return sorted;
  }

  List<String> _documentsForCase(ServiceCase serviceCase) {
    if (serviceCase.requiredDocuments.isNotEmpty) {
      return serviceCase.requiredDocuments;
    }

    return const [
      'CNIC front and back',
      'Relevant business or service documents',
      'Any supporting proof requested by OMC',
    ];
  }
}

class _DocumentRequirementRow extends StatelessWidget {
  const _DocumentRequirementRow({
    required this.label,
    required this.isSubmitted,
    required this.isMissing,
    this.status,
    this.fileUrl,
    this.remarks,
    this.canReview = false,
    this.isUpdating = false,
    this.onApprove,
    this.onReject,
  });

  final String label;
  final bool isSubmitted;
  final bool isMissing;
  final String? status;
  final String? fileUrl;
  final String? remarks;
  final bool canReview;
  final bool isUpdating;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final normalizedStatus = status?.trim();
    final statusLabel = normalizedStatus != null && normalizedStatus.isNotEmpty
        ? normalizedStatus
        : isSubmitted
        ? 'Submitted'
        : isMissing
        ? 'Missing'
        : 'Required';
    final hasFile = fileUrl != null && fileUrl!.trim().isNotEmpty;
    final cleanRemarks = remarks?.trim();
    final hasRemarks = cleanRemarks != null && cleanRemarks.isNotEmpty;

    final statusKey = statusLabel.trim().toLowerCase();

    final icon = switch (statusKey) {
      'approved' => Icons.check_circle_rounded,
      'uploaded' => Icons.cloud_done_rounded,
      'rejected' => Icons.cancel_rounded,
      'pending' => Icons.hourglass_empty_rounded,
      'missing' => Icons.error_outline_rounded,
      'required' => Icons.description_outlined,
      _ =>
        isSubmitted
            ? Icons.check_circle_rounded
            : isMissing
            ? Icons.error_outline_rounded
            : Icons.description_outlined,
    };

    final statusColor = switch (statusKey) {
      'approved' => const Color(0xFF18864B),
      'uploaded' => const Color(0xFFB25E00),
      'rejected' => const Color(0xFFC62828),
      'pending' => AppTheme.textSecondary,
      'missing' => const Color(0xFFB25E00),
      'required' => AppTheme.textSecondary,
      _ =>
        isSubmitted
            ? const Color(0xFF18864B)
            : isMissing
            ? const Color(0xFFB25E00)
            : AppTheme.textSecondary,
    };

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: statusColor.withValues(alpha: 0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: statusColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (hasFile) ...[
                  const SizedBox(height: 5),
                  const Text(
                    'File attached',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (hasRemarks) ...[
                  const SizedBox(height: 5),
                  Text(
                    cleanRemarks,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (canReview) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: isUpdating ? null : onReject,
                      child: const Text('Reject'),
                    ),
                    FilledButton(
                      onPressed: isUpdating ? null : onApprove,
                      child: const Text('Approve'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CaseActionsCard extends StatelessWidget {
  const _CaseActionsCard({
    required this.serviceCase,
    required this.assisted,
    required this.customerName,
    required this.canViewDocuments,
    required this.isUploading,
    required this.onUploadMissingDocument,
    required this.isCancelling,
    required this.onCancelRequest,
  });

  final ServiceCase serviceCase;
  final bool assisted;
  final String? customerName;
  final bool canViewDocuments;
  final bool isUploading;
  final VoidCallback? onUploadMissingDocument;
  final bool isCancelling;
  final VoidCallback? onCancelRequest;

  @override
  Widget build(BuildContext context) {
    final documents = serviceCase.documentDetails;

    final missingDocumentsCount =
        serviceCase.missingDocumentsCount ??
        serviceCase.missingDocuments.length;

    final hasMissingDocuments =
        missingDocumentsCount > 0 ||
        serviceCase.missingDocuments.isNotEmpty ||
        documents.any(
          (document) => document.isMissing || !document.isSubmitted,
        );

    final hasRejectedDocuments = documents.any(
      (document) => document.status.trim().toLowerCase().contains('reject'),
    );

    final hasPendingReview = documents.any((document) {
      final status = document.status.trim().toLowerCase();

      return document.isSubmitted &&
          !status.contains('approve') &&
          !status.contains('verified') &&
          !status.contains('reject');
    });

    final hasAvailablePayment =
        serviceCase.hasPayment && serviceCase.activePaymentTotal > 0;

    final action = _resolveAction(
      hasMissingDocuments: hasMissingDocuments,
      hasRejectedDocuments: hasRejectedDocuments,
      hasPendingReview: hasPendingReview,
      paymentEligible: serviceCase.paymentEligible,
      hasAvailablePayment: hasAvailablePayment,
      paymentBlockReason: serviceCase.paymentBlockReason,
    );

    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: action.background,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(action.icon, color: action.color, size: 24),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Available actions',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      action.title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        height: 1.25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      action.message,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        height: 1.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (action.primaryType != _CasePrimaryAction.none) ...[
            const SizedBox(height: 17),
            _PrimaryCaseActionButton(
              action: action.primaryType,
              isUploading: isUploading,
              onUpload: onUploadMissingDocument,
              paymentId: serviceCase.paymentId,
              assisted: assisted,
              customerName: customerName,
            ),
          ],
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.black.withValues(alpha: 0.055)),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 390;

              final documentsButton = canViewDocuments
                  ? _SecondaryCaseAction(
                      icon: Icons.folder_open_outlined,
                      label: 'View documents',
                      onPressed: () {
                        if (assisted) {
                          final path =
                              '/documents'
                              '?assisted=1'
                              '&service_request=${Uri.encodeQueryComponent(serviceCase.id)}'
                              '&customer_name=${Uri.encodeQueryComponent(customerName ?? '')}';
                          context.go(path);
                          return;
                        }

                        context.go('/documents');
                      },
                    )
                  : null;

              final supportButton = _SecondaryCaseAction(
                icon: Icons.support_agent_outlined,
                label: 'Contact support',
                onPressed: () => SupportLauncher.openWhatsApp(context),
              );

              final cancelButton = onCancelRequest == null
                  ? null
                  : _SecondaryCaseAction(
                      icon: Icons.close_rounded,
                      label: isCancelling ? 'Cancelling...' : 'Cancel request',
                      destructive: true,
                      showProgress: isCancelling,
                      onPressed: isCancelling ? null : onCancelRequest,
                    );

              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (documentsButton != null) ...[
                      documentsButton,
                      const SizedBox(height: 10),
                    ],
                    supportButton,
                    if (cancelButton != null) ...[
                      const SizedBox(height: 10),
                      cancelButton,
                    ],
                  ],
                );
              }

              return Row(
                children: [
                  if (documentsButton != null) ...[
                    Expanded(child: documentsButton),
                    const SizedBox(width: 10),
                  ],
                  Expanded(child: supportButton),
                  if (cancelButton != null) ...[
                    const SizedBox(width: 10),
                    Expanded(child: cancelButton),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  _ResolvedCaseAction _resolveAction({
    required bool hasMissingDocuments,
    required bool hasRejectedDocuments,
    required bool hasPendingReview,
    required bool paymentEligible,
    required bool hasAvailablePayment,
    required String? paymentBlockReason,
  }) {
    if (serviceCase.isHistoricalRequest) {
      return const _ResolvedCaseAction(
        icon: Icons.history_rounded,
        color: AppTheme.textSecondary,
        background: AppTheme.background,
        title: 'Historical service record',
        message:
            'This is a read-only record of a service handled before the current OMC workflow.',
        primaryType: _CasePrimaryAction.none,
      );
    }

    if (hasMissingDocuments) {
      return const _ResolvedCaseAction(
        icon: Icons.upload_file_outlined,
        color: Color(0xFF168D49),
        background: Color(0xFFE9F7EE),
        title: 'Upload the missing documents',
        message:
            'Attach the requested files so OMC can continue reviewing your service request.',
        primaryType: _CasePrimaryAction.upload,
      );
    }

    if (hasRejectedDocuments) {
      return const _ResolvedCaseAction(
        icon: Icons.error_outline_rounded,
        color: Color(0xFFC56A00),
        background: Color(0xFFFFF3E2),
        title: 'Some documents need correction',
        message:
            'Review the rejected items and upload corrected copies to continue.',
        primaryType: _CasePrimaryAction.correctedUpload,
      );
    }

    if (paymentEligible && hasAvailablePayment) {
      return const _ResolvedCaseAction(
        icon: Icons.account_balance_wallet_outlined,
        color: Color(0xFF168D49),
        background: Color(0xFFE9F7EE),
        title: 'Payment is ready',
        message:
            'All required documents are uploaded. Open payment details to continue.',
        primaryType: _CasePrimaryAction.payment,
      );
    }

    if (paymentEligible) {
      return const _ResolvedCaseAction(
        icon: Icons.account_balance_wallet_outlined,
        color: AppTheme.primary,
        background: AppTheme.primarySoft,
        title: 'Ready for payment',
        message:
            'All required documents are uploaded. Your payment record is being prepared.',
        primaryType: _CasePrimaryAction.none,
      );
    }

    if (hasPendingReview) {
      final blockedMessage = paymentBlockReason?.trim();

      return _ResolvedCaseAction(
        icon: Icons.hourglass_top_rounded,
        color: AppTheme.textSecondary,
        background: AppTheme.background,
        title: 'Documents uploaded',
        message: blockedMessage != null && blockedMessage.isNotEmpty
            ? blockedMessage
            : 'Your documents are uploaded. Payment will become available when the remaining payment requirements are satisfied.',
        primaryType: _CasePrimaryAction.none,
      );
    }

    return const _ResolvedCaseAction(
      icon: Icons.check_circle_outline_rounded,
      color: Color(0xFF168D49),
      background: Color(0xFFE9F7EE),
      title: 'Everything is up to date',
      message:
          'There are no pending document actions for this service request.',
      primaryType: _CasePrimaryAction.none,
    );
  }
}

enum _CasePrimaryAction { none, upload, correctedUpload, payment }

class _ResolvedCaseAction {
  const _ResolvedCaseAction({
    required this.icon,
    required this.color,
    required this.background,
    required this.title,
    required this.message,
    required this.primaryType,
  });

  final IconData icon;
  final Color color;
  final Color background;
  final String title;
  final String message;
  final _CasePrimaryAction primaryType;
}

class _PrimaryCaseActionButton extends StatelessWidget {
  const _PrimaryCaseActionButton({
    required this.action,
    required this.isUploading,
    required this.onUpload,
    required this.paymentId,
    required this.assisted,
    required this.customerName,
  });

  final _CasePrimaryAction action;
  final bool isUploading;
  final VoidCallback? onUpload;
  final String? paymentId;
  final bool assisted;
  final String? customerName;

  @override
  Widget build(BuildContext context) {
    final isPayment = action == _CasePrimaryAction.payment;
    final cleanPaymentId = paymentId?.trim();
    final canOpenPayment =
        isPayment && cleanPaymentId != null && cleanPaymentId.isNotEmpty;

    final label = switch (action) {
      _CasePrimaryAction.upload => 'Upload documents',
      _CasePrimaryAction.correctedUpload => 'Upload corrected documents',
      _CasePrimaryAction.payment => 'View payments',
      _CasePrimaryAction.none => '',
    };

    return SizedBox(
      height: 48,
      child: FilledButton.icon(
        onPressed: isUploading
            ? null
            : isPayment
            ? canOpenPayment
                  ? () {
                      final path = assisted
                          ? '/payments/${Uri.encodeComponent(cleanPaymentId)}'
                                '?assisted=1'
                                '&customer_name=${Uri.encodeQueryComponent(customerName ?? '')}'
                          : '/payments/${Uri.encodeComponent(cleanPaymentId)}';
                      context.push(path);
                    }
                  : null
            : onUpload,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF159447),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(
            0xFF159447,
          ).withValues(alpha: 0.45),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          elevation: 0,
        ),
        icon: isUploading
            ? const SizedBox(
                width: 17,
                height: 17,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(
                isPayment
                    ? Icons.account_balance_wallet_outlined
                    : Icons.upload_file_outlined,
                size: 20,
              ),
        label: Text(
          isUploading ? 'Uploading...' : label,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

class _SecondaryCaseAction extends StatelessWidget {
  const _SecondaryCaseAction({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.destructive = false,
    this.showProgress = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool destructive;
  final bool showProgress;

  @override
  Widget build(BuildContext context) {
    const destructiveColor = Color(0xFFC62828);
    final color = destructive ? destructiveColor : AppTheme.textPrimary;

    return SizedBox(
      height: 43,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(
            color: destructive
                ? destructiveColor.withValues(alpha: 0.42)
                : Colors.black.withValues(alpha: 0.09),
          ),
          backgroundColor: destructive
              ? const Color(0xFFFFF1F1)
              : AppTheme.background,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        icon: showProgress
            ? SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            : Icon(icon, size: 18),
        label: Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
