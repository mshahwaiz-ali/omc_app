import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
import '../../../app/providers/effective_capabilities_provider.dart';
import '../../../app/mutation_invalidation.dart';
import '../../../app/theme.dart';
import '../../../core/forms/dirty_form_controller.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/app_back_header.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_labeled_field.dart';
import '../../../core/widgets/app_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/omc_premium.dart';
import '../../../core/widgets/premium_card.dart';
import '../../admin_control/data/admin_control_repository.dart';
import '../../documents/application/document_attachment_controller.dart';
import '../../documents/data/document_attachment.dart';
import '../../support/application/support_launcher.dart';
import '../data/service_case.dart';
import '../data/service_case_repository.dart';
import '../data/service_request_repository.dart';

class OperationalServiceCaseDetailScreen extends ConsumerStatefulWidget {
  const OperationalServiceCaseDetailScreen({
    super.key,
    required this.caseId,
    this.assisted = false,
    this.customerName,
  });

  final String caseId;
  final bool assisted;
  final String? customerName;

  @override
  ConsumerState<OperationalServiceCaseDetailScreen> createState() =>
      _OperationalServiceCaseDetailScreenState();
}

class _OperationalServiceCaseDetailScreenState
    extends ConsumerState<OperationalServiceCaseDetailScreen> {
  bool _isUploadingDocument = false;
  bool _isUpdatingDocumentStatus = false;
  bool _isCancellingRequest = false;
  bool _isAdminMutating = false;
  Future<AdminCaseOptions>? _adminOptions;

  @override
  Widget build(BuildContext context) {
    final caseAsync = ref.watch(serviceCaseDetailProvider(widget.caseId));
    final capabilities = ref.watch(effectiveCapabilitiesProvider);
    final canReviewDocuments = capabilities.canReviewDocuments;
    final canUploadDocuments =
        capabilities.canUploadDocuments ||
        (widget.assisted && capabilities.canUploadCustomerDocuments);
    final canCancelOwnRequest =
        capabilities.isApproved && capabilities.canTrackRequests;
    final canViewDocuments = widget.assisted
        ? capabilities.canViewCustomerDocuments
        : capabilities.canViewDocuments;
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
      backgroundColor: AppTheme.background,
      appBar: AppBackHeader(
        title: 'Service request',
        subtitle: widget.assisted
            ? 'Assisted customer operation'
            : 'Operational request detail',
        actionIcon: Icons.support_agent_rounded,
        actionTooltip: 'Contact support',
        onAction: () => SupportLauncher.openWhatsApp(context),
      ),
      body: SafeArea(
        top: false,
        child: caseAsync.when(
          loading: () => const LoadingView(message: 'Loading service request'),
          error: (error, _) => OmcPageListView(
            topPadding: AppSpacing.lg,
            bottomPadding: AppSpacing.xxl,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              AppErrorState.fromError(
                error: error,
                fallbackTitle: 'Tracking detail unavailable',
                fallbackMessage:
                    'This service request could not be loaded right now.',
                onRetry: () =>
                    ref.invalidate(serviceCaseDetailProvider(widget.caseId)),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => SupportLauncher.openWhatsApp(context),
                icon: const Icon(Icons.support_agent_rounded),
                label: const Text('Contact support'),
              ),
            ],
          ),
          data: (serviceCase) {
            if (serviceCase == null) {
              return OmcPageListView(
                topPadding: AppSpacing.lg,
                bottomPadding: AppSpacing.xxl,
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  AppEmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Case not found',
                    message:
                        'This tracking reference may no longer be available.',
                    actionLabel: 'Retry',
                    onAction: () => ref.invalidate(
                      serviceCaseDetailProvider(widget.caseId),
                    ),
                  ),
                ],
              );
            }

            final uploadAction =
                !serviceCase.isHistoricalRequest && canUploadDocuments
                ? () => _showUploadDocumentSheet(serviceCase)
                : null;
            final cancelAction =
                !serviceCase.isHistoricalRequest &&
                    canCancelOwnRequest &&
                    serviceCase.canCancel
                ? () => _confirmCancelServiceRequest(serviceCase)
                : null;
            final reviewAction =
                !serviceCase.isHistoricalRequest &&
                    canReviewDocuments &&
                    serviceCase.canReviewDocuments &&
                    !_isUpdatingDocumentStatus
                ? (ServiceCaseDocument document, String status) =>
                      _updateServiceDocumentStatus(
                        serviceCase,
                        document,
                        status,
                      )
                : null;

            return RefreshIndicator.adaptive(
              onRefresh: () async {
                ref.invalidate(serviceCaseDetailProvider(widget.caseId));
                ref.invalidate(serviceCasesProvider);
                try {
                  await ref.read(
                    serviceCaseDetailProvider(widget.caseId).future,
                  );
                } catch (_) {
                  // Provider remains in its authoritative error state.
                }
              },
              child: OmcPageListView(
                topPadding: AppSpacing.sm,
                bottomPadding: AppSpacing.xxl,
                children: [
                  _AssistedIdentityCard(
                    serviceCase: serviceCase,
                    assisted: widget.assisted,
                    suppliedCustomerName: widget.customerName,
                    isInternal:
                        capabilities.canAccessInternalWorkspace ||
                        capabilities.isInternal,
                  ),
                  const SizedBox(height: 12),
                  _ServiceAuthorityCard(serviceCase: serviceCase),
                  const SizedBox(height: 12),
                  _NextOperationCard(
                    serviceCase: serviceCase,
                    assisted: widget.assisted,
                    customerName:
                        widget.customerName ?? serviceCase.displayCustomerName,
                    isUploading: _isUploadingDocument,
                    onUpload: uploadAction,
                  ),
                  const SizedBox(height: 22),
                  const _SectionHeader(
                    title: 'Evidence',
                    subtitle:
                        'Backend document, payment and activity evidence for this request.',
                  ),
                  const SizedBox(height: 10),
                  _DocumentEvidenceCard(
                    serviceCase: serviceCase,
                    canViewDocuments: canViewDocuments,
                    assisted: widget.assisted,
                    customerName:
                        widget.customerName ?? serviceCase.displayCustomerName,
                    isUpdating: _isUpdatingDocumentStatus,
                    onReview: reviewAction,
                  ),
                  const SizedBox(height: 10),
                  _PaymentEvidenceCard(
                    serviceCase: serviceCase,
                    assisted: widget.assisted,
                    customerName:
                        widget.customerName ?? serviceCase.displayCustomerName,
                  ),
                  if (serviceCase.timeline.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _ActivityEvidenceCard(serviceCase: serviceCase),
                  ],
                  const SizedBox(height: 22),
                  _OperationalDetailsCard(serviceCase: serviceCase),
                  const SizedBox(height: 14),
                  _RequestActionsCard(
                    canViewDocuments: canViewDocuments,
                    assisted: widget.assisted,
                    customerName:
                        widget.customerName ?? serviceCase.displayCustomerName,
                    serviceCase: serviceCase,
                    isCancelling: _isCancellingRequest,
                    onCancel: cancelAction,
                  ),
                  if (canAdministerCase) ...[
                    const SizedBox(height: 22),
                    const _SectionHeader(
                      title: 'Authorized admin controls',
                      subtitle:
                          'Administrative actions are separated from customer evidence and remain capability gated.',
                    ),
                    const SizedBox(height: 10),
                    FutureBuilder<AdminCaseOptions>(
                      future: _adminOptions,
                      builder: (context, snapshot) => _AdminOperationsCard(
                        options: snapshot.data,
                        loading:
                            snapshot.connectionState == ConnectionState.waiting,
                        error: snapshot.hasError,
                        busy: _isAdminMutating,
                        canReassign: capabilities.canReassignServiceCases,
                        canRetry: capabilities.canRetrySync,
                        canReviewDiscount:
                            capabilities.canManageBusinessSettings,
                        onReassign: snapshot.hasData
                            ? () => _reassignCase(snapshot.data!)
                            : null,
                        onRetry: _retrySync,
                        onReviewDiscount: snapshot.hasData
                            ? (approve) =>
                                  _reviewDiscount(snapshot.data!, approve)
                            : null,
                        onReload: () {
                          setState(() {
                            _adminOptions = ref
                                .read(adminControlRepositoryProvider)
                                .fetchCaseOptions(widget.caseId);
                          });
                        },
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _reassignCase(AdminCaseOptions options) async {
    final candidates = options.candidates;
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
              onPressed: () => Navigator.pop(dialogContext, candidate.userId),
              child: Text(
                candidate.fullName.trim().isEmpty
                    ? candidate.userId
                    : '${candidate.fullName}\n${candidate.userId}',
              ),
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

  Future<void> _reviewDiscount(AdminCaseOptions options, bool approve) async {
    if (options.text('discount_status') != 'Pending Approval') {
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
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel request?'),
        content: const Text(
          'This will cancel this service request. You can start a new request later if needed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep request'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
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

    final capabilities = ref.read(effectiveCapabilitiesProvider);
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
      await ref
          .read(serviceCaseRepositoryProvider)
          .cancelServiceRequest(caseId: caseId);
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

    if (!ref.read(effectiveCapabilitiesProvider).canReviewDocuments) {
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
      await ref
          .read(serviceCaseRepositoryProvider)
          .updateServiceDocumentStatus(documentId: document.id, status: status);
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

    final capabilities = ref.read(effectiveCapabilitiesProvider);
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
      useSafeArea: true,
      isDismissible: false,
      enableDrag: false,
      showDragHandle: false,
      builder: (_) => _OperationalDocumentUploadSheet(
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
      final uploadedFiles = await ref
          .read(serviceRequestRepositoryProvider)
          .uploadRequestAttachments(
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

class _AssistedIdentityCard extends StatelessWidget {
  const _AssistedIdentityCard({
    required this.serviceCase,
    required this.assisted,
    required this.suppliedCustomerName,
    required this.isInternal,
  });

  final ServiceCase serviceCase;
  final bool assisted;
  final String? suppliedCustomerName;
  final bool isInternal;

  @override
  Widget build(BuildContext context) {
    final customer = suppliedCustomerName?.trim().isNotEmpty == true
        ? suppliedCustomerName!.trim()
        : serviceCase.displayCustomerName;
    final creator =
        serviceCase.submittedByInternalName?.trim().isNotEmpty == true
        ? serviceCase.submittedByInternalName!.trim()
        : serviceCase.submittedByName?.trim().isNotEmpty == true
        ? serviceCase.submittedByName!.trim()
        : null;
    final assistedRequest = assisted || serviceCase.isAssistedRequest;

    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OmcIconBadge(
            icon: assistedRequest
                ? Icons.handshake_outlined
                : Icons.person_outline_rounded,
            color: AppTheme.info,
            size: 44,
            iconSize: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  assistedRequest ? 'Assisted customer' : 'Request identity',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  customer,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 21,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (creator != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    serviceCase.createdOnBehalf
                        ? 'Created by $creator on the customer’s behalf'
                        : 'Submitted by $creator',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                ],
                if (isInternal) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      if (serviceCase.internalCustomerModeLabel != null)
                        _MetaPill(
                          label: serviceCase.internalCustomerModeLabel!,
                        ),
                      if (serviceCase.internalSubmissionLabel != null)
                        _MetaPill(label: serviceCase.internalSubmissionLabel!),
                    ],
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

class _ServiceAuthorityCard extends StatelessWidget {
  const _ServiceAuthorityCard({required this.serviceCase});

  final ServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    final status = serviceCase.statusLabel.trim().isEmpty
        ? 'Status unavailable'
        : serviceCase.statusLabel.trim();
    final lifecycle = serviceCase.lifecycleState.trim();
    final operational = serviceCase.effectiveOperationalStatus.trim();
    final holdReason = serviceCase.hold.reason.trim();

    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              OmcStatusBadge(
                label: status,
                color: OmcPremium.statusColor(status),
              ),
              if (serviceCase.isHistoricalRequest)
                const _MetaPill(label: 'Historical · read only'),
              if (serviceCase.isFinancialHold)
                const _MetaPill(label: 'Financial hold'),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            serviceCase.title.trim().isEmpty
                ? 'OMC service request'
                : serviceCase.title.trim(),
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 21,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (serviceCase.category.trim().isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              serviceCase.category.trim(),
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 14),
          _AuthorityRow(
            label: 'Lifecycle',
            value: lifecycle.isEmpty ? '-' : lifecycle,
          ),
          _AuthorityRow(
            label: 'Operational status',
            value: operational.isEmpty ? '-' : operational,
          ),
          if (serviceCase.currentStage?.trim().isNotEmpty == true)
            _AuthorityRow(
              label: 'Current stage',
              value: serviceCase.currentStage!.trim(),
            ),
          if (serviceCase.nextStep?.trim().isNotEmpty == true)
            _AuthorityRow(
              label: 'Backend next step',
              value: serviceCase.nextStep!.trim(),
            ),
          if (holdReason.isNotEmpty)
            _AuthorityRow(label: 'Hold reason', value: holdReason),
        ],
      ),
    );
  }
}

class _NextOperationCard extends StatelessWidget {
  const _NextOperationCard({
    required this.serviceCase,
    required this.assisted,
    required this.customerName,
    required this.isUploading,
    required this.onUpload,
  });

  final ServiceCase serviceCase;
  final bool assisted;
  final String customerName;
  final bool isUploading;
  final VoidCallback? onUpload;

  @override
  Widget build(BuildContext context) {
    final resolved = _resolveOperation(serviceCase);
    final paymentId = serviceCase.paymentId?.trim();
    final canOpenPayment =
        resolved.action == _OperationalAction.payment &&
        paymentId != null &&
        paymentId.isNotEmpty;

    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OmcIconBadge(
                icon: resolved.icon,
                color: resolved.color,
                size: 44,
                iconSize: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Next operation',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      resolved.title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 17,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      resolved.message,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 15,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (resolved.action == _OperationalAction.upload &&
              onUpload != null) ...[
            const SizedBox(height: 16),
            AppButton(
              label: resolved.uploadCorrected
                  ? 'Upload corrected documents'
                  : 'Upload documents',
              icon: Icons.upload_file_outlined,
              isLoading: isUploading,
              onPressed: isUploading ? null : onUpload,
            ),
          ],
          if (canOpenPayment) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                final path = assisted
                    ? '/payments/${Uri.encodeComponent(paymentId)}'
                          '?assisted=1'
                          '&customer_name=${Uri.encodeQueryComponent(customerName)}'
                    : '/payments/${Uri.encodeComponent(paymentId)}';
                context.push(path);
              },
              icon: const Icon(Icons.account_balance_wallet_outlined),
              label: const Text('Open payment details'),
            ),
          ],
        ],
      ),
    );
  }

  _ResolvedOperation _resolveOperation(ServiceCase serviceCase) {
    final backendNext = serviceCase.nextAction?.trim();
    final backendStep = serviceCase.nextStep?.trim();
    final authoritativeTitle = backendNext?.isNotEmpty == true
        ? backendNext!
        : backendStep?.isNotEmpty == true
        ? backendStep!
        : null;
    final documents = serviceCase.documentDetails;
    final hasRejectedDocuments = documents.any(
      (document) => document.isRejected,
    );
    final missingCount =
        serviceCase.missingDocumentsCount ??
        serviceCase.missingDocuments.length;
    final hasMissingDocuments =
        missingCount > 0 || documents.any((document) => document.isMissing);
    final paymentRejected =
        serviceCase.receipt.isRejected || serviceCase.rejectedPaymentTotal > 0;
    final paymentId = serviceCase.paymentId?.trim();

    if (serviceCase.isHistoricalRequest) {
      return _ResolvedOperation(
        title: authoritativeTitle ?? 'Historical service record',
        message:
            'This request is read only. Operational evidence is shown for reference.',
        icon: Icons.history_rounded,
        color: AppTheme.processing,
      );
    }

    if (hasRejectedDocuments) {
      return _ResolvedOperation(
        title: authoritativeTitle ?? 'Correct rejected documents',
        message:
            'Rejected document instructions are shown in Evidence. Upload corrected files before continuing.',
        icon: Icons.error_outline_rounded,
        color: AppTheme.warning,
        action: _OperationalAction.upload,
        uploadCorrected: true,
      );
    }

    if (hasMissingDocuments) {
      return _ResolvedOperation(
        title: authoritativeTitle ?? 'Upload required documents',
        message:
            'The backend document evidence shows required files are still missing.',
        icon: Icons.upload_file_outlined,
        color: AppTheme.warning,
        action: _OperationalAction.upload,
      );
    }

    if (paymentRejected) {
      return _ResolvedOperation(
        title: authoritativeTitle ?? 'Payment receipt needs correction',
        message: paymentId != null && paymentId.isNotEmpty
            ? 'Open payment details to review the rejected receipt and required correction.'
            : 'A payment receipt needs correction, but no payment record is currently available to open.',
        icon: Icons.receipt_long_outlined,
        color: AppTheme.warning,
        action: paymentId != null && paymentId.isNotEmpty
            ? _OperationalAction.payment
            : _OperationalAction.none,
      );
    }

    if (serviceCase.paymentEligible) {
      if (paymentId != null && paymentId.isNotEmpty) {
        return _ResolvedOperation(
          title: authoritativeTitle ?? 'Payment record is ready',
          message:
              'Payment preparation is complete enough to open the backend payment record. Payment verification still happens in the payment workflow.',
          icon: Icons.account_balance_wallet_outlined,
          color: AppTheme.info,
          action: _OperationalAction.payment,
        );
      }
      return _ResolvedOperation(
        title: authoritativeTitle ?? 'Payment is being prepared',
        message:
            'The backend marks this request payment-eligible, but no payment record is available yet. This is preparation, not pay-now.',
        icon: Icons.hourglass_top_rounded,
        color: AppTheme.processing,
      );
    }

    final blockReason = serviceCase.paymentBlockReason?.trim();
    return _ResolvedOperation(
      title: authoritativeTitle ?? 'No immediate customer operation',
      message: blockReason?.isNotEmpty == true
          ? blockReason!
          : 'Follow the backend lifecycle and evidence below. No additional action is currently exposed here.',
      icon: Icons.info_outline_rounded,
      color: AppTheme.info,
    );
  }
}

enum _OperationalAction { none, upload, payment }

class _ResolvedOperation {
  const _ResolvedOperation({
    required this.title,
    required this.message,
    required this.icon,
    required this.color,
    this.action = _OperationalAction.none,
    this.uploadCorrected = false,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final _OperationalAction action;
  final bool uploadCorrected;
}

class _DocumentEvidenceCard extends StatelessWidget {
  const _DocumentEvidenceCard({
    required this.serviceCase,
    required this.canViewDocuments,
    required this.assisted,
    required this.customerName,
    required this.isUpdating,
    required this.onReview,
  });

  final ServiceCase serviceCase;
  final bool canViewDocuments;
  final bool assisted;
  final String customerName;
  final bool isUpdating;
  final void Function(ServiceCaseDocument document, String status)? onReview;

  @override
  Widget build(BuildContext context) {
    final details = serviceCase.documentDetails;
    final names = serviceCase.requiredDocuments.isNotEmpty
        ? serviceCase.requiredDocuments
        : serviceCase.missingDocuments;

    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _EvidenceHeader(
            icon: Icons.folder_copy_outlined,
            title: 'Documents',
            summary: serviceCase.documentSummaryLabel,
          ),
          const SizedBox(height: 12),
          if (details.isEmpty && names.isEmpty)
            const Text(
              'No document evidence is currently attached to this request.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 15,
                height: 1.4,
              ),
            )
          else if (details.isNotEmpty)
            for (var index = 0; index < details.length; index++) ...[
              _DocumentEvidenceRow(
                document: details[index],
                isUpdating: isUpdating,
                onReview: onReview,
              ),
              if (index != details.length - 1) const Divider(height: 18),
            ]
          else
            for (var index = 0; index < names.length; index++) ...[
              _DocumentNameRow(
                name: names[index],
                submitted: serviceCase.submittedDocuments.contains(
                  names[index],
                ),
                missing: serviceCase.missingDocuments.contains(names[index]),
              ),
              if (index != names.length - 1) const Divider(height: 18),
            ],
          if (canViewDocuments) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () {
                if (assisted) {
                  context.go(
                    '/documents'
                    '?assisted=1'
                    '&service_request=${Uri.encodeQueryComponent(serviceCase.id)}'
                    '&customer_name=${Uri.encodeQueryComponent(customerName)}',
                  );
                  return;
                }
                context.go('/documents');
              },
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Open documents workspace'),
            ),
          ],
        ],
      ),
    );
  }
}

class _DocumentEvidenceRow extends StatelessWidget {
  const _DocumentEvidenceRow({
    required this.document,
    required this.isUpdating,
    required this.onReview,
  });

  final ServiceCaseDocument document;
  final bool isUpdating;
  final void Function(ServiceCaseDocument document, String status)? onReview;

  @override
  Widget build(BuildContext context) {
    final remarks = document.remarks?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.title.trim().isEmpty
                        ? 'Required document'
                        : document.title.trim(),
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (document.type.trim().isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      document.type.trim(),
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            OmcStatusBadge(
              label: document.status.trim().isEmpty
                  ? (document.isSubmitted ? 'Submitted' : 'Required')
                  : document.status.trim(),
              color: OmcPremium.statusColor(document.status),
            ),
          ],
        ),
        if (remarks?.isNotEmpty == true) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: document.isRejected
                  ? AppTheme.warningSoft
                  : AppTheme.processingSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              remarks!,
              style: TextStyle(
                color: document.isRejected
                    ? AppTheme.warning
                    : AppTheme.textSecondary,
                fontSize: 14,
                height: 1.4,
                fontWeight: document.isRejected
                    ? FontWeight.w500
                    : FontWeight.w400,
              ),
            ),
          ),
        ],
        if (document.fileUrl?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 7),
          const Text(
            'File attached',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
          ),
        ],
        if (document.hasRealId && onReview != null) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton(
                onPressed: isUpdating
                    ? null
                    : () => onReview!(document, 'Rejected'),
                child: const Text('Reject'),
              ),
              FilledButton(
                onPressed: isUpdating
                    ? null
                    : () => onReview!(document, 'Approved'),
                child: const Text('Approve'),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _DocumentNameRow extends StatelessWidget {
  const _DocumentNameRow({
    required this.name,
    required this.submitted,
    required this.missing,
  });

  final String name;
  final bool submitted;
  final bool missing;

  @override
  Widget build(BuildContext context) {
    final status = submitted
        ? 'Submitted'
        : missing
        ? 'Missing'
        : 'Required';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            name,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 10),
        OmcStatusBadge(label: status, color: OmcPremium.statusColor(status)),
      ],
    );
  }
}

class _PaymentEvidenceCard extends StatelessWidget {
  const _PaymentEvidenceCard({
    required this.serviceCase,
    required this.assisted,
    required this.customerName,
  });

  final ServiceCase serviceCase;
  final bool assisted;
  final String customerName;

  @override
  Widget build(BuildContext context) {
    final payments = serviceCase.paymentDetails;
    final paymentId = serviceCase.paymentId?.trim();

    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _EvidenceHeader(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Payment',
            summary: serviceCase.paymentSummaryLabel,
          ),
          const SizedBox(height: 12),
          _AuthorityRow(
            label: 'Receipt status',
            value: serviceCase.receipt.status,
          ),
          if (serviceCase.receipt.paymentStatus.trim().isNotEmpty)
            _AuthorityRow(
              label: 'Payment status',
              value: serviceCase.receipt.paymentStatus.trim(),
            ),
          _AuthorityRow(
            label: 'Payment eligible',
            value: serviceCase.paymentEligible ? 'Yes' : 'No',
          ),
          if (serviceCase.paymentBlockReason?.trim().isNotEmpty == true)
            _AuthorityRow(
              label: 'Payment block reason',
              value: serviceCase.paymentBlockReason!.trim(),
            ),
          if (payments.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (var index = 0; index < payments.length; index++) ...[
              _PaymentRow(payment: payments[index]),
              if (index != payments.length - 1) const Divider(height: 18),
            ],
          ],
          if (paymentId != null && paymentId.isNotEmpty) ...[
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: () {
                final route = assisted
                    ? '/payments/${Uri.encodeComponent(paymentId)}'
                          '?assisted=1'
                          '&customer_name=${Uri.encodeQueryComponent(customerName)}'
                    : '/payments/${Uri.encodeComponent(paymentId)}';
                context.push(route);
              },
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Open payment record'),
            ),
          ],
        ],
      ),
    );
  }
}

class _PaymentRow extends StatelessWidget {
  const _PaymentRow({required this.payment});

  final ServiceCasePayment payment;

  @override
  Widget build(BuildContext context) {
    final metadata = <String>[
      if (payment.dueDateLabel?.trim().isNotEmpty == true)
        'Due ${payment.dueDateLabel!.trim()}',
      if (payment.paidOnLabel?.trim().isNotEmpty == true)
        'Paid ${payment.paidOnLabel!.trim()}',
      if (payment.paymentReference?.trim().isNotEmpty == true)
        payment.paymentReference!.trim(),
    ];
    final amount = payment.amount % 1 == 0
        ? payment.amount.toInt().toString()
        : payment.amount.toStringAsFixed(2);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  payment.title.trim().isEmpty
                      ? 'Payment record'
                      : payment.title.trim(),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OmcStatusBadge(
                label: payment.status,
                color: OmcPremium.statusColor(payment.status),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '${payment.currency.trim().isEmpty ? 'PKR' : payment.currency.trim()} $amount',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 20,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (metadata.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              metadata.join(' · '),
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ],
          if (payment.remarks?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(
              payment.remarks!.trim(),
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActivityEvidenceCard extends StatelessWidget {
  const _ActivityEvidenceCard({required this.serviceCase});

  final ServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _EvidenceHeader(
            icon: Icons.history_rounded,
            title: 'Activity',
            summary: 'Backend request timeline',
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < serviceCase.timeline.length; index++) ...[
            _ActivityRow(step: serviceCase.timeline[index]),
            if (index != serviceCase.timeline.length - 1)
              const Divider(height: 18),
          ],
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.step});

  final ServiceCaseTimelineStep step;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          step.isDone
              ? Icons.check_circle_outline_rounded
              : step.isActive
              ? Icons.radio_button_checked_rounded
              : Icons.circle_outlined,
          size: 20,
          color: step.isDone
              ? AppTheme.success
              : step.isActive
              ? AppTheme.info
              : AppTheme.textSecondary,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                step.title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (step.subtitle.trim().isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  step.subtitle,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _OperationalDetailsCard extends StatelessWidget {
  const _OperationalDetailsCard({required this.serviceCase});

  final ServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    final settlement = serviceCase.settlement;
    final activation = serviceCase.activation;

    return PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 8),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        title: const Text(
          'Operational details',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${serviceCase.displayReference} · Updated ${serviceCase.updatedAtLabel}',
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
            height: 1.35,
          ),
        ),
        children: [
          _AuthorityRow(
            label: 'Reference',
            value: serviceCase.displayReference,
          ),
          _AuthorityRow(label: 'Created', value: serviceCase.createdAtLabel),
          _AuthorityRow(label: 'Updated', value: serviceCase.updatedAtLabel),
          _AuthorityRow(label: 'Lifecycle', value: serviceCase.lifecycleState),
          _AuthorityRow(
            label: 'Operational status',
            value: serviceCase.effectiveOperationalStatus,
          ),
          if (serviceCase.displayStatus?.trim().isNotEmpty == true)
            _AuthorityRow(
              label: 'Display status',
              value: serviceCase.displayStatus!.trim(),
            ),
          if (serviceCase.currentStage?.trim().isNotEmpty == true)
            _AuthorityRow(
              label: 'Current stage',
              value: serviceCase.currentStage!.trim(),
            ),
          if (serviceCase.nextAction?.trim().isNotEmpty == true)
            _AuthorityRow(
              label: 'Backend next action',
              value: serviceCase.nextAction!.trim(),
            ),
          if (serviceCase.nextStep?.trim().isNotEmpty == true)
            _AuthorityRow(
              label: 'Backend next step',
              value: serviceCase.nextStep!.trim(),
            ),
          if (serviceCase.remarks?.trim().isNotEmpty == true)
            _AuthorityRow(label: 'Remarks', value: serviceCase.remarks!.trim()),
          const Divider(height: 22),
          _AuthorityRow(label: 'Settlement', value: settlement.status),
          _AuthorityRow(
            label: 'Allocated amount',
            value: _money(settlement.allocatedAmount, settlement.currency),
          ),
          _AuthorityRow(
            label: 'Payable amount',
            value: _money(settlement.payableAmount, settlement.currency),
          ),
          _AuthorityRow(
            label: 'Outstanding amount',
            value: _money(settlement.outstandingAmount, settlement.currency),
          ),
          if (settlement.reviewKind.trim().isNotEmpty)
            _AuthorityRow(
              label: 'Settlement review',
              value: settlement.reviewKind.trim(),
            ),
          const Divider(height: 22),
          if (activation.state.trim().isNotEmpty)
            _AuthorityRow(label: 'Activation', value: activation.state),
          _AuthorityRow(label: 'Bridge state', value: activation.bridgeState),
          _AuthorityRow(
            label: 'Activation attempts',
            value: '${activation.attemptCount}',
          ),
          _AuthorityRow(
            label: 'Evidence complete',
            value: activation.evidenceComplete ? 'Yes' : 'No',
          ),
          if (activation.readyAt.trim().isNotEmpty)
            _AuthorityRow(label: 'Ready at', value: activation.readyAt),
          if (activation.activatedAt.trim().isNotEmpty)
            _AuthorityRow(label: 'Activated at', value: activation.activatedAt),
          if (serviceCase.completionBlockers.isNotEmpty) ...[
            const Divider(height: 22),
            const Text(
              'Completion blockers',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            for (final blocker in serviceCase.completionBlockers)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '• $blocker',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 15,
                    height: 1.4,
                  ),
                ),
              ),
          ],
          if (serviceCase.milestones.isNotEmpty) ...[
            const Divider(height: 22),
            const Text(
              'Backend milestones',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final milestone in serviceCase.milestones)
                  _MetaPill(label: milestone),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _money(double amount, String currency) {
    final value = amount % 1 == 0
        ? amount.toInt().toString()
        : amount.toStringAsFixed(2);
    return '${currency.trim().isEmpty ? 'PKR' : currency.trim()} $value';
  }
}

class _RequestActionsCard extends StatelessWidget {
  const _RequestActionsCard({
    required this.canViewDocuments,
    required this.assisted,
    required this.customerName,
    required this.serviceCase,
    required this.isCancelling,
    required this.onCancel,
  });

  final bool canViewDocuments;
  final bool assisted;
  final String customerName;
  final ServiceCase serviceCase;
  final bool isCancelling;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (canViewDocuments)
            OutlinedButton.icon(
              onPressed: () {
                if (assisted) {
                  context.go(
                    '/documents'
                    '?assisted=1'
                    '&service_request=${Uri.encodeQueryComponent(serviceCase.id)}'
                    '&customer_name=${Uri.encodeQueryComponent(customerName)}',
                  );
                  return;
                }
                context.go('/documents');
              },
              icon: const Icon(Icons.folder_open_outlined),
              label: const Text('Documents'),
            ),
          OutlinedButton.icon(
            onPressed: () => SupportLauncher.openWhatsApp(context),
            icon: const Icon(Icons.support_agent_outlined),
            label: const Text('Support'),
          ),
          if (onCancel != null)
            OutlinedButton.icon(
              onPressed: isCancelling ? null : onCancel,
              icon: isCancelling
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.close_rounded),
              label: Text(isCancelling ? 'Cancelling' : 'Cancel request'),
              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.danger),
            ),
        ],
      ),
    );
  }
}

class _AdminOperationsCard extends StatelessWidget {
  const _AdminOperationsCard({
    required this.options,
    required this.loading,
    required this.error,
    required this.busy,
    required this.canReassign,
    required this.canRetry,
    required this.canReviewDiscount,
    required this.onReassign,
    required this.onRetry,
    required this.onReviewDiscount,
    required this.onReload,
  });

  final AdminCaseOptions? options;
  final bool loading;
  final bool error;
  final bool busy;
  final bool canReassign;
  final bool canRetry;
  final bool canReviewDiscount;
  final VoidCallback? onReassign;
  final VoidCallback onRetry;
  final ValueChanged<bool>? onReviewDiscount;
  final VoidCallback onReload;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const PremiumCard(
        padding: EdgeInsets.all(18),
        child: LinearProgressIndicator(),
      );
    }
    if (error || options == null) {
      return PremiumCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Administrative options could not be loaded.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onReload,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry admin options'),
            ),
          ],
        ),
      );
    }

    final discountPending =
        options!.text('discount_status') == 'Pending Approval';
    final assignedStaff = options!.text('assigned_staff');
    final syncStatus = options!.text('erp_sync_status');
    final originalPrice = options!.text('original_price');
    final proposedPrice = options!.text('proposed_final_price');

    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AuthorityRow(
            label: 'Assigned to',
            value: assignedStaff.isEmpty ? 'Unassigned' : assignedStaff,
          ),
          _AuthorityRow(
            label: 'ERP sync',
            value: syncStatus.isEmpty ? 'Not started' : syncStatus,
          ),
          if (discountPending)
            _AuthorityRow(
              label: 'Discount review',
              value: 'PKR $originalPrice → PKR $proposedPrice',
            ),
          const SizedBox(height: 12),
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
      ),
    );
  }
}

class _OperationalDocumentUploadSheet extends StatefulWidget {
  const _OperationalDocumentUploadSheet({
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
  State<_OperationalDocumentUploadSheet> createState() =>
      _OperationalDocumentUploadSheetState();
}

class _OperationalDocumentUploadSheetState
    extends State<_OperationalDocumentUploadSheet> {
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
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return PopScope<Object?>(
      canPop: !_isPicking && !_isUploading,
      child: UnsavedChangesGuard(
        controller: _dirtyFormController,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Upload required document',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 21,
                      height: 1.25,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Choose the backend document requirement and attach one supported file.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 15,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  AppLabeledField(
                    label: 'Document type',
                    isRequired: true,
                    child: DropdownButtonFormField<ServiceCaseDocument>(
                      initialValue: _selectedDocument,
                      isExpanded: true,
                      decoration: const InputDecoration(),
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
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _isUploading || _isPicking ? null : _chooseFile,
                    icon: _isPicking
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.attach_file_rounded),
                    label: Text(
                      _selectedAttachment?.name.trim().isNotEmpty == true
                          ? _selectedAttachment!.name.trim()
                          : 'Choose file',
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'PDF, JPG, JPEG, PNG, DOC or DOCX · maximum 10 MB',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      height: 1.4,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(
                        color: AppTheme.danger,
                        fontSize: 14,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  AppButton(
                    label: 'Upload document',
                    icon: Icons.cloud_upload_outlined,
                    isLoading: _isUploading,
                    onPressed: _isUploading ? null : _upload,
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _isUploading
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ],
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
      if (mounted) {
        setState(() => _errorMessage = 'File picker could not open right now.');
      }
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
      if (mounted) setState(() => _errorMessage = error.toString());
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
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
        content: AppLabeledField(
          label: 'Review remarks',
          isRequired: true,
          child: TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Explain why this discount cannot be approved.',
            ),
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

class _EvidenceHeader extends StatelessWidget {
  const _EvidenceHeader({
    required this.icon,
    required this.title,
    required this.summary,
  });

  final IconData icon;
  final String title;
  final String summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        OmcIconBadge(
          icon: icon,
          color: AppTheme.textSecondary,
          size: 40,
          iconSize: 20,
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
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                summary,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 21,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

class _AuthorityRow extends StatelessWidget {
  const _AuthorityRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.processingSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: AppTheme.processing),
      ),
    );
  }
}
