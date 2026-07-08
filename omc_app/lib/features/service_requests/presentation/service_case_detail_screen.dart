import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/app_back_header.dart';
import '../../../core/widgets/premium_card.dart';
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
  bool _isUpdatingStatus = false;
  bool _isUpdatingDocumentStatus = false;

  @override
  Widget build(BuildContext context) {
    final caseAsync = ref.watch(serviceCaseDetailProvider(widget.caseId));

    return Scaffold(
      body: Column(
        children: [
          AppBackHeader(
            title: 'Service Details',
            subtitle: 'Track request progress and documents',
            actionIcon: Icons.support_agent_rounded,
            actionTooltip: 'Support',
            onAction: () => SupportLauncher.openWhatsApp(context),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: caseAsync.when(
                loading: () => const _LoadingView(),
                error: (error, stackTrace) => _ErrorView(
                  title: 'Tracking detail unavailable',
                  message: _cleanErrorMessage(error),
                  onRetry: () =>
                      ref.invalidate(serviceCaseDetailProvider(widget.caseId)),
                  onSupport: () => SupportLauncher.openWhatsApp(context),
                ),
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
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                    children: [
                      _CaseHero(serviceCase: serviceCase),
                      const SizedBox(height: 16),
                      _QuickStatusGrid(serviceCase: serviceCase),
                      const SizedBox(height: 16),
                      _ProgressCard(serviceCase: serviceCase),
                      if (serviceCase.customerActionRequired) ...[
                        const SizedBox(height: 16),
                        _ActionRequiredCard(serviceCase: serviceCase),
                      ],
                      const SizedBox(height: 16),
                      _CaseInfoCard(serviceCase: serviceCase),
                      const SizedBox(height: 16),
                      if (serviceCase.canUpdateStatus) ...[
                        _CaseAdminStatusCard(
                          serviceCase: serviceCase,
                          isUpdating: _isUpdatingStatus,
                          onStatusSelected: _isUpdatingStatus
                              ? null
                              : (status) => _updateServiceCaseStatus(
                                    serviceCase,
                                    status,
                                  ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _RequiredDocumentsCard(
                        serviceCase: serviceCase,
                        isUpdatingDocumentStatus: _isUpdatingDocumentStatus,
                        onUpdateDocumentStatus:
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
                      const SizedBox(height: 16),
                      _CaseActionsCard(
                        serviceCase: serviceCase,
                        isUploading: _isUploadingDocument,
                        onUploadMissingDocument: () =>
                            _showUploadDocumentSheet(serviceCase),
                      ),
                      const SizedBox(height: 16),
                      _SupportCard(serviceCase: serviceCase),
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

  Future<void> _updateServiceCaseStatus(
    ServiceCase serviceCase,
    String status,
  ) async {
    if (_isUpdatingStatus) return;

    final caseId = _uploadDocnameFor(serviceCase);
    if (caseId == null) {
      _showSnack(
        'Status update cannot continue because this case is missing its service reference.',
      );
      return;
    }

    setState(() => _isUpdatingStatus = true);

    try {
      final repository = ref.read(serviceCaseRepositoryProvider);
      await repository.updateServiceCaseStatus(caseId: caseId, status: status);

      if (!mounted) return;
      ref.invalidate(serviceCaseDetailProvider(widget.caseId));
      ref.invalidate(serviceCasesProvider);
      _showSnack('Service case marked as $status.');
    } on ApiError catch (error) {
      if (!mounted) return;
      _showSnack(error.message);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Service case status could not be updated right now.');
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  Future<void> _updateServiceDocumentStatus(
    ServiceCase serviceCase,
    ServiceCaseDocument document,
    String status,
  ) async {
    if (_isUpdatingDocumentStatus) return;

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
    } on ApiError catch (error) {
      if (!mounted) return;
      _showSnack(error.message);
    } catch (_) {
      if (!mounted) return;
      _showSnack('Document status could not be updated right now.');
    } finally {
      if (mounted) setState(() => _isUpdatingDocumentStatus = false);
    }
  }

  Future<void> _showUploadDocumentSheet(ServiceCase serviceCase) async {
    if (_isUploadingDocument) return;

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
    } on ApiError catch (error) {
      if (!mounted) return;
      _showSnack(error.message);
      rethrow;
    } catch (_) {
      if (!mounted) return;
      _showSnack(
        'Missing document could not be uploaded right now. Please try again.',
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

  void _showSnack(String message) {
    if (!mounted || message.trim().isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message.trim())),
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
  ) onUpload;

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
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 22),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Upload required document',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Select the required document type first, then choose the file to attach. The file name will not be used as the document title.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ServiceCaseDocument>(
                initialValue: _selectedDocument,
                decoration: const InputDecoration(labelText: 'Required document'),
                items: widget.documents
                    .map(
                      (document) => DropdownMenuItem(
                        value: document,
                        child: Text(document.title),
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
              const SizedBox(height: 12),
              _SelectedFileTile(
                attachment: _selectedAttachment,
                isPicking: _isPicking,
                onChoose: _isUploading ? null : _chooseFile,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: AppTheme.primaryRed,
                    fontSize: 12,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _isUploading ? null : _upload,
                icon: _isUploading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.cloud_upload_rounded),
                label: Text(_isUploading ? 'Uploading...' : 'Upload'),
              ),
            ],
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
        setState(() => _selectedAttachment = result.accepted.first);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'File picker could not open right now.');
    } finally {
      if (mounted) setState(() => _isPicking = false);
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
      debugPrint('Document upload failed: $error');
      if (!mounted) return;
      setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isUploading = false);
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

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Icon(
            fileName == null || fileName.isEmpty
                ? Icons.attach_file_rounded
                : Icons.insert_drive_file_rounded,
            color: AppTheme.primaryRed,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              fileName == null || fileName.isEmpty
                  ? 'No file selected'
                  : fileName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: isPicking ? null : onChoose,
            icon: isPicking
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.folder_open_rounded, size: 18),
            label: Text(isPicking ? 'Opening...' : 'Choose'),
          ),
        ],
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
    required this.onRetry,
    required this.onSupport,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;
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
                color: AppTheme.primaryRed,
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _cleanErrorMessage(Object error) {
  if (error is ApiError && error.message.trim().isNotEmpty) {
    return error.message.trim();
  }

  final rawMessage = error.toString().replaceFirst('ApiError:', '').trim();
  if (rawMessage.isEmpty) {
    return 'Service tracking detail is unavailable right now.';
  }

  return rawMessage;
}

class _CaseHero extends StatelessWidget {
  const _CaseHero({required this.serviceCase});

  final ServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppTheme.primaryRed, AppTheme.darkRed],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.assignment_turned_in_outlined,
              color: Colors.white,
              size: 34,
            ),
            const SizedBox(height: 14),
            Text(
              serviceCase.category,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              serviceCase.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                height: 1.12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _HeroPill(label: serviceCase.status),
                _HeroPill(label: serviceCase.displayReference),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickStatusGrid extends StatelessWidget {
  const _QuickStatusGrid({required this.serviceCase});

  final ServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    final progress = serviceCase.progress.clamp(0, 1).toDouble();
    final progressPercent = serviceCase.progressPercent ?? (progress * 100).round();
    final missingDocumentsCount =
        serviceCase.missingDocumentsCount ?? serviceCase.missingDocuments.length;

    return Row(
      children: [
        Expanded(
          child: _QuickStatusTile(
            icon: Icons.stacked_line_chart_rounded,
            label: 'Progress',
            value: '$progressPercent%',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickStatusTile(
            icon: Icons.file_present_rounded,
            label: 'Missing docs',
            value: missingDocumentsCount.toString(),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _QuickStatusTile(
            icon: Icons.update_rounded,
            label: 'Updated',
            value: serviceCase.updatedAtLabel,
          ),
        ),
      ],
    );
  }
}

class _QuickStatusTile extends StatelessWidget {
  const _QuickStatusTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryRed, size: 22),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
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
        (serviceCase.progressPercent ?? (progress * 100).round()).toString();
    final steps = _timelineSteps(serviceCase);

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Progress timeline',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '$progressPercent%',
                style: const TextStyle(
                  color: AppTheme.primaryRed,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: AppTheme.primaryRed.withValues(alpha: 0.08),
            ),
          ),
          const SizedBox(height: 18),
          for (final step in steps) _TimelineStep(step: step),
        ],
      ),
    );
  }

  List<ServiceCaseTimelineStep> _timelineSteps(ServiceCase serviceCase) {
    if (serviceCase.timeline.isNotEmpty) return serviceCase.timeline;

    final progress = serviceCase.progress.clamp(0, 1).toDouble();
    return [
      ServiceCaseTimelineStep(
        title: 'Request received',
        subtitle: serviceCase.createdAtLabel,
        isDone: progress >= 0.05,
      ),
      ServiceCaseTimelineStep(
        title: 'Documents review',
        subtitle: progress >= 0.35 ? 'In progress' : 'Pending',
        isDone: progress >= 0.35,
      ),
      ServiceCaseTimelineStep(
        title: 'OMC processing',
        subtitle: progress >= 0.65 ? 'In progress' : 'Pending',
        isDone: progress >= 0.65,
      ),
      ServiceCaseTimelineStep(
        title: 'Completed',
        subtitle: progress >= 1 ? serviceCase.updatedAtLabel : 'Pending',
        isDone: progress >= 1,
      ),
    ];
  }
}

class _TimelineStep extends StatelessWidget {
  const _TimelineStep({required this.step});

  final ServiceCaseTimelineStep step;

  @override
  Widget build(BuildContext context) {
    final color = step.isDone ? AppTheme.primaryRed : AppTheme.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: step.isDone
                  ? AppTheme.primaryRed
                  : AppTheme.primaryRed.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              step.isDone ? Icons.check_rounded : Icons.circle_outlined,
              size: 16,
              color: step.isDone ? Colors.white : AppTheme.primaryRed,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  step.subtitle,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
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

class _ActionRequiredCard extends StatelessWidget {
  const _ActionRequiredCard({required this.serviceCase});

  final ServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    final missingDocumentsCount =
        serviceCase.missingDocumentsCount ?? serviceCase.missingDocuments.length;

    return PremiumCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFB25E00).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.priority_high_rounded,
              color: Color(0xFFB25E00),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Action required',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  missingDocumentsCount > 0
                      ? '$missingDocumentsCount document(s) are needed to continue this service request.'
                      : serviceCase.nextStep ??
                          'OMC needs an update from you to continue this request.',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
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

class _CaseInfoCard extends StatelessWidget {
  const _CaseInfoCard({required this.serviceCase});

  final ServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Case information',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          _InfoRow(label: 'Status', value: serviceCase.status),
          _InfoRow(label: 'Created', value: serviceCase.createdAtLabel),
          _InfoRow(label: 'Updated', value: serviceCase.updatedAtLabel),
          if (serviceCase.nextStep != null)
            _InfoRow(label: 'Next step', value: serviceCase.nextStep!),
          if (serviceCase.remarks != null)
            _InfoRow(label: 'Remarks', value: serviceCase.remarks!),
        ],
      ),
    );
  }
}

class _CaseAdminStatusCard extends StatelessWidget {
  const _CaseAdminStatusCard({
    required this.serviceCase,
    required this.isUpdating,
    required this.onStatusSelected,
  });

  final ServiceCase serviceCase;
  final bool isUpdating;
  final ValueChanged<String>? onStatusSelected;

  @override
  Widget build(BuildContext context) {
    final status = serviceCase.status.trim().toLowerCase();
    final isClosed = status == 'completed' || status == 'cancelled';

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Admin case controls',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isClosed
                ? 'This case is closed. Reopen it before continuing work.'
                : 'Update backend service progress after reviewing case activity.',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _CaseStatusActionButton(
                label: 'Waiting',
                status: 'Waiting for Customer',
                icon: Icons.hourglass_bottom_rounded,
                enabled: !isUpdating && !isClosed && onStatusSelected != null,
                onStatusSelected: onStatusSelected,
              ),
              _CaseStatusActionButton(
                label: 'In Progress',
                status: 'In Progress',
                icon: Icons.timelapse_rounded,
                enabled: !isUpdating && !isClosed && onStatusSelected != null,
                onStatusSelected: onStatusSelected,
              ),
              _CaseStatusActionButton(
                label: 'Complete',
                status: 'Completed',
                icon: Icons.verified_rounded,
                enabled: !isUpdating && !isClosed && onStatusSelected != null,
                onStatusSelected: onStatusSelected,
              ),
              _CaseStatusActionButton(
                label: 'Reopen',
                status: 'Open',
                icon: Icons.refresh_rounded,
                enabled: !isUpdating && onStatusSelected != null,
                onStatusSelected: onStatusSelected,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CaseStatusActionButton extends StatelessWidget {
  const _CaseStatusActionButton({
    required this.label,
    required this.status,
    required this.icon,
    required this.enabled,
    required this.onStatusSelected,
  });

  final String label;
  final String status;
  final IconData icon;
  final bool enabled;
  final ValueChanged<String>? onStatusSelected;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: enabled ? () => onStatusSelected?.call(status) : null,
      icon: Icon(icon),
      label: Text(label),
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
                  isSubmitted: serviceCase.submittedDocuments.contains(document),
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
      _ => isSubmitted
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
      _ => isSubmitted
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
  });

  final ServiceCase serviceCase;
  final bool isUploading;
  final VoidCallback onUploadMissingDocument;

  @override
  Widget build(BuildContext context) {
    final missingDocumentsCount =
        serviceCase.missingDocumentsCount ?? serviceCase.missingDocuments.length;
    final documents = serviceCase.documentDetails;
    final hasMissingDocuments = missingDocumentsCount > 0 ||
        serviceCase.missingDocuments.isNotEmpty ||
        documents.any((document) => document.isMissing || !document.isSubmitted);
    final hasRejectedDocuments = documents.any((document) {
      final status = document.status.trim().toLowerCase();
      return status.contains('reject');
    });
    final hasPendingReview = documents.any((document) {
      final status = document.status.trim().toLowerCase();
      return document.isSubmitted &&
          !status.contains('approve') &&
          !status.contains('verified') &&
          !status.contains('reject');
    });
    final allDocumentsApproved = documents.isNotEmpty &&
        !hasMissingDocuments &&
        !hasRejectedDocuments &&
        documents.every((document) {
          final status = document.status.trim().toLowerCase();
          return status.contains('approve') || status.contains('verified');
        });

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Actions',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          if (hasMissingDocuments) ...[
            _ActionNotice(
              icon: Icons.cloud_upload_outlined,
              title: 'Missing documents required',
              message:
                  'Upload the requested document by selecting its required document type first.',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: isUploading ? null : onUploadMissingDocument,
              icon: isUploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.upload_file_rounded),
              label: Text(isUploading ? 'Uploading...' : 'Upload documents'),
            ),
            const SizedBox(height: 10),
          ] else if (hasRejectedDocuments) ...[
            _ActionNotice(
              icon: Icons.error_outline_rounded,
              title: 'Documents need correction',
              message:
                  'One or more documents were rejected. Please upload corrected documents or contact OMC support.',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: isUploading ? null : onUploadMissingDocument,
              icon: isUploading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.upload_file_rounded),
              label: Text(isUploading ? 'Uploading...' : 'Upload corrected documents'),
            ),
            const SizedBox(height: 10),
          ] else if (allDocumentsApproved) ...[
            const _ActionNotice(
              icon: Icons.verified_rounded,
              title: 'All documents approved',
              message:
                  'Your documents are approved. Please proceed to payment to continue your service request.',
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => context.go('/payments'),
              icon: const Icon(Icons.payments_rounded),
              label: const Text('Proceed to payment'),
            ),
            const SizedBox(height: 10),
          ] else if (hasPendingReview) ...[
            const _ActionNotice(
              icon: Icons.hourglass_top_rounded,
              title: 'Documents submitted',
              message:
                  'Your documents are submitted and waiting for OMC review. You will see the next step once review is complete.',
            ),
            const SizedBox(height: 12),
          ] else ...[
            const _ActionNotice(
              icon: Icons.check_circle_outline_rounded,
              title: 'Documents submitted',
              message:
                  'All currently required documents for this case appear submitted. OMC will share the next step shortly.',
            ),
            const SizedBox(height: 12),
          ],
          OutlinedButton.icon(
            onPressed: () => SupportLauncher.openWhatsApp(context),
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            label: const Text('Ask OMC support'),
          ),
        ],
      ),
    );
  }
}

class _ActionNotice extends StatelessWidget {
  const _ActionNotice({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryRed, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
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

class _SupportCard extends StatelessWidget {
  const _SupportCard({required this.serviceCase});

  final ServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Need help?',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Contact OMC support for tracking updates, missing documents or urgent follow-up.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => SupportLauncher.openWhatsApp(context),
            icon: const Icon(Icons.chat_bubble_outline_rounded),
            label: const Text('Ask support'),
          ),
        ],
      ),
    );
  }
}

class _HeroPill extends StatelessWidget {
  const _HeroPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w800,
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
