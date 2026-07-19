import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/app_back_header.dart';
import '../../../core/widgets/premium_card.dart';
import '../../auth/application/auth_controller.dart';
import '../../documents/application/document_attachment_controller.dart';
import '../../documents/data/document_attachment.dart';
import '../../support/application/support_launcher.dart';
import '../data/service_case.dart';
import '../data/service_case_repository.dart';
import '../data/service_request_repository.dart';

class ServiceCaseDetailScreen extends ConsumerStatefulWidget {
  const ServiceCaseDetailScreen({super.key, required this.caseId});

  final String caseId;

  @override
  ConsumerState<ServiceCaseDetailScreen> createState() =>
      _ServiceCaseDetailScreenState();
}

class _ServiceCaseDetailScreenState
    extends ConsumerState<ServiceCaseDetailScreen> {
  bool _isUploadingDocument = false;
  bool _isUpdatingDocumentStatus = false;
  bool _isCancellingRequest = false;

  @override
  Widget build(BuildContext context) {
    final caseAsync = ref.watch(serviceCaseDetailProvider(widget.caseId));
    final capabilities = ref.watch(authControllerProvider).capabilities;
    final canReviewDocuments = capabilities.canReviewDocuments;
    final canUploadDocuments = capabilities.canUploadDocuments;
    final canCancelOwnRequest =
        capabilities.isApproved && capabilities.canTrackRequests;

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
                      const SizedBox(height: 14),
                      _ProgressCard(serviceCase: serviceCase),
                      if (serviceCase.customerActionRequired) ...[
                        const SizedBox(height: 14),
                        _ActionRequiredCard(serviceCase: serviceCase),
                      ],
                      const SizedBox(height: 14),
                      _QuickStatusGrid(serviceCase: serviceCase),
                      const SizedBox(height: 14),
                      _RequiredDocumentsCard(
                        serviceCase: serviceCase,
                        isUpdatingDocumentStatus: _isUpdatingDocumentStatus,
                        onUpdateDocumentStatus:
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
                      const SizedBox(height: 14),
                      _CaseActionsCard(
                        serviceCase: serviceCase,
                        isUploading: _isUploadingDocument,
                        onUploadMissingDocument: canUploadDocuments
                            ? () => _showUploadDocumentSheet(serviceCase)
                            : null,
                        isCancelling: _isCancellingRequest,
                        onCancelRequest:
                            canCancelOwnRequest && serviceCase.canCancel
                            ? () => _confirmCancelServiceRequest(serviceCase)
                            : null,
                      ),
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

    if (!ref.read(authControllerProvider).capabilities.canUploadDocuments) {
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
  bool _isPicking = false;
  bool _isUploading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedDocument = widget.documents.first;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
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

    setState(() {
      _isUploading = true;
      _errorMessage = null;
    });

    try {
      await widget.onUpload(_selectedDocument, attachment);

      if (!mounted) return;

      Navigator.of(context).pop();
    } catch (error) {
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

class _CaseHero extends StatelessWidget {
  const _CaseHero({required this.serviceCase});

  final ServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    final statusStyle = _caseStatusVisual(serviceCase.status);
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
                      label: serviceCase.status,
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

class _QuickStatusGrid extends StatelessWidget {
  const _QuickStatusGrid({required this.serviceCase});

  final ServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    final required = serviceCase.requiredDocumentTotal;
    final approved = serviceCase.approvedDocumentTotal;
    final rejected = serviceCase.rejectedDocumentTotal;
    final submitted =
        serviceCase.submittedDocumentsCount ??
        serviceCase.submittedDocuments.length;
    final missing =
        serviceCase.missingDocumentsCount ??
        serviceCase.missingDocuments.length;

    final paymentTotal = serviceCase.activePaymentTotal;
    final paymentPaid = serviceCase.approvedPaymentTotal;
    final paymentDue = (paymentTotal - paymentPaid).clamp(0, paymentTotal);

    final documents = _SummaryTile(
      icon: Icons.description_outlined,
      iconColor: const Color(0xFF16864B),
      iconBackground: const Color(0xFFEAF7EF),
      title: 'Documents',
      value: required > 0 ? '$approved / $required' : submitted.toString(),
      subtitle: required > 0 ? 'Approved' : 'Submitted',
      footer: rejected > 0
          ? '$rejected rejected'
          : missing > 0
          ? '$missing missing'
          : serviceCase.documentSummaryLabel,
    );

    final payments = _SummaryTile(
      icon: Icons.account_balance_wallet_outlined,
      iconColor: const Color(0xFF7B3FD3),
      iconBackground: const Color(0xFFF3ECFF),
      title: 'Payments',
      value: paymentTotal > 0 ? '$paymentPaid / $paymentTotal' : '—',
      subtitle: paymentTotal > 0 ? 'Paid' : 'Not opened',
      footer: paymentDue > 0
          ? '$paymentDue payment${paymentDue == 1 ? '' : 's'} due'
          : serviceCase.paymentSummaryLabel,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: documents),
              const SizedBox(width: 12),
              Expanded(child: payments),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: documents),
            const SizedBox(width: 14),
            Expanded(child: payments),
          ],
        );
      },
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.footer,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String value;
  final String subtitle;
  final String footer;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: iconColor, size: 23),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 22,
                    height: 1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  footer,
                  style: TextStyle(
                    color: iconColor,
                    fontSize: 11.5,
                    height: 1.3,
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
    final progress = serviceCase.progress.clamp(0, 1).toDouble();
    final status = serviceCase.status.trim().toLowerCase();
    final completed = status.contains('complete') || status.contains('closed');

    final required = serviceCase.requiredDocumentTotal;
    final approved = serviceCase.approvedDocumentTotal;
    final missing =
        serviceCase.missingDocumentsCount ??
        serviceCase.missingDocuments.length;

    final documentsDone = required > 0
        ? approved >= required && missing == 0
        : progress >= 0.35;

    final reviewDone =
        progress >= 0.55 ||
        status.contains('payment') ||
        status.contains('progress') ||
        completed;

    final processingDone = progress >= 0.80 || completed;

    return [
      const ServiceCaseTimelineStep(
        title: 'Information',
        subtitle: 'Completed',
        isDone: true,
      ),
      ServiceCaseTimelineStep(
        title: 'Documents',
        subtitle: documentsDone ? 'Completed' : 'Pending',
        isDone: documentsDone,
      ),
      ServiceCaseTimelineStep(
        title: 'Review',
        subtitle: reviewDone ? 'Completed' : 'In progress',
        isDone: reviewDone,
      ),
      ServiceCaseTimelineStep(
        title: 'Processing',
        subtitle: processingDone ? 'Completed' : 'Pending',
        isDone: processingDone,
      ),
      ServiceCaseTimelineStep(
        title: 'Completion',
        subtitle: completed ? 'Completed' : 'Pending',
        isDone: completed,
      ),
    ];
  }

  int _activeTimelineIndex(List<ServiceCaseTimelineStep> steps) {
    for (var index = 0; index < steps.length; index++) {
      if (!steps[index].isDone) return index;
    }
    return steps.isEmpty ? -1 : steps.length - 1;
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

class _ActionRequiredCard extends StatelessWidget {
  const _ActionRequiredCard({required this.serviceCase});

  final ServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    final missing =
        serviceCase.missingDocumentsCount ??
        serviceCase.missingDocuments.length;

    final title = missing > 0
        ? 'Upload the requested documents'
        : serviceCase.nextStep?.trim().isNotEmpty == true
        ? serviceCase.nextStep!.trim()
        : 'Your attention is required';

    final message = missing > 0
        ? '$missing document(s) are still required before OMC can continue.'
        : serviceCase.actionRequiredLabel;

    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFF1FAF4),
              Colors.white.withValues(alpha: 0.96),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFF17984D).withValues(alpha: 0.10),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: const Color(0xFFE2F5E9),
                borderRadius: BorderRadius.circular(17),
              ),
              child: const Icon(
                Icons.upload_file_outlined,
                color: Color(0xFF168E49),
                size: 27,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Next step',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      height: 1.25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11.8,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _CaseInfoCard extends StatelessWidget {
  const _CaseInfoCard({required this.serviceCase});

  final ServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Request details',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Reference information and the latest case notes.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11.8,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _InfoRow(label: 'Reference', value: serviceCase.displayReference),
          _InfoRow(label: 'Status', value: serviceCase.status),
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
    required this.isUploading,
    required this.onUploadMissingDocument,
    required this.isCancelling,
    required this.onCancelRequest,
  });

  final ServiceCase serviceCase;
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

    final allDocumentsApproved =
        documents.isNotEmpty &&
        !hasMissingDocuments &&
        !hasRejectedDocuments &&
        documents.every((document) {
          final status = document.status.trim().toLowerCase();

          return status.contains('approve') || status.contains('verified');
        });

    final action = _resolveAction(
      hasMissingDocuments: hasMissingDocuments,
      hasRejectedDocuments: hasRejectedDocuments,
      hasPendingReview: hasPendingReview,
      allDocumentsApproved: allDocumentsApproved,
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
            ),
          ],
          const SizedBox(height: 16),
          Container(height: 1, color: Colors.black.withValues(alpha: 0.055)),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 390;

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
    required bool allDocumentsApproved,
  }) {
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

    if (allDocumentsApproved) {
      return const _ResolvedCaseAction(
        icon: Icons.verified_outlined,
        color: Color(0xFF168D49),
        background: Color(0xFFE9F7EE),
        title: 'Documents approved',
        message:
            'Your documents have been approved. Continue to payments when a payment request is available.',
        primaryType: _CasePrimaryAction.payment,
      );
    }

    if (hasPendingReview) {
      return const _ResolvedCaseAction(
        icon: Icons.hourglass_top_rounded,
        color: Color(0xFF1769AA),
        background: Color(0xFFEAF3FB),
        title: 'Documents are under review',
        message:
            'No action is needed right now. OMC will notify you when the review is complete.',
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
  });

  final _CasePrimaryAction action;
  final bool isUploading;
  final VoidCallback? onUpload;

  @override
  Widget build(BuildContext context) {
    final isPayment = action == _CasePrimaryAction.payment;

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
            ? () => context.go('/payments')
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
    final color = destructive ? AppTheme.primary : AppTheme.textPrimary;

    return SizedBox(
      height: 43,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: color,
          side: BorderSide(
            color: destructive
                ? AppTheme.primary.withValues(alpha: 0.28)
                : Colors.black.withValues(alpha: 0.09),
          ),
          backgroundColor: destructive
              ? AppTheme.primary.withValues(alpha: 0.025)
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
