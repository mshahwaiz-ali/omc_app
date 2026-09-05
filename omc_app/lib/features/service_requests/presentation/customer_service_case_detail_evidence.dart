part of 'customer_service_case_detail_screen.dart';

class _DocumentsCard extends ConsumerStatefulWidget {
  const _DocumentsCard({
    required this.detail,
    required this.canViewDocuments,
    required this.canUploadDocuments,
  });

  final CustomerServiceCaseDetail detail;
  final bool canViewDocuments;
  final bool canUploadDocuments;

  @override
  ConsumerState<_DocumentsCard> createState() => _DocumentsCardState();
}

class _DocumentsCardState extends ConsumerState<_DocumentsCard> {
  final Set<String> _uploading = <String>{};

  @override
  Widget build(BuildContext context) {
    final detail = widget.detail;
    final documents = detail.requiredDocuments;
    final needsUpload = detail.documentsNeedingUpload > 0;
    final hasUploadedDocuments = documents.any(
      (document) => document.fileUrl.trim().isNotEmpty,
    );
    final isHistorical =
        detail.requestState.trim().toLowerCase() == 'historical';
    final isReadOnly = detail.isTerminal || detail.isCompleted;

    return PremiumCard(
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: const Text(
              'Required documents',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 6),
          if (documents.isEmpty)
            const Text(
              'No documents are currently required for this service request.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            )
          else ...[
            Text(
              isReadOnly && needsUpload
                  ? isHistorical
                        ? '${detail.documentsNeedingUpload} required document${detail.documentsNeedingUpload == 1 ? '' : 's'} ${detail.documentsNeedingUpload == 1 ? 'was' : 'were'} not recorded for this historical service.'
                        : detail.isCompleted
                        ? '${detail.documentsNeedingUpload} required document${detail.documentsNeedingUpload == 1 ? '' : 's'} ${detail.documentsNeedingUpload == 1 ? 'is' : 'are'} not recorded for this completed service.'
                        : 'This request is no longer active. Missing documents are shown for reference only.'
                  : needsUpload
                  ? '${detail.documentsNeedingUpload} required document${detail.documentsNeedingUpload == 1 ? '' : 's'} still need attention.'
                  : 'Your required document checklist is up to date.',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 13),
            for (final document in documents) ...[
              _DocumentRow(
                document: document,
                readOnly: isReadOnly,
                canUpload:
                    widget.canUploadDocuments &&
                    !isReadOnly &&
                    document.needsUpload,
                isUploading: _uploading.contains(document.uploadIdentity),
                onUpload: () => _uploadRequiredDocument(document),
              ),
              const SizedBox(height: 8),
            ],
            if (widget.canViewDocuments && hasUploadedDocuments) ...[
              const SizedBox(height: 5),
              OutlinedButton.icon(
                onPressed: () => context.go('/documents'),
                icon: const Icon(Icons.folder_open_outlined),
                label: const Text('View uploaded documents'),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _uploadRequiredDocument(
    CustomerServiceCaseDocument document,
  ) async {
    final identity = document.uploadIdentity;
    if (_uploading.contains(identity)) return;

    final picker = ref.read(documentAttachmentControllerProvider);
    final pickResult = await picker.pickDocuments(maxFiles: 1);

    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    for (final message in pickResult.rejectedMessages) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }

    if (!pickResult.hasAcceptedFiles) return;

    final attachment = pickResult.accepted.first;

    setState(() => _uploading.add(identity));

    try {
      await ref
          .read(documentsRepositoryProvider)
          .uploadRequiredDocument(
            serviceRequestId: widget.detail.id,
            documentKey: document.documentKey,
            documentTitle: document.title,
            documentType: document.documentType,
            attachment: attachment,
          );

      if (!mounted) return;

      ref.invalidate(customerServiceCaseDetailProvider(widget.detail.id));
      ref.invalidate(serviceCasesProvider);
      ref.invalidate(homeDashboardSummaryProvider);
      ref.invalidate(documentPageProvider);
      ref.invalidate(documentsProvider);

      messenger.showSnackBar(
        SnackBar(content: Text('${document.title} uploaded successfully.')),
      );

      try {
        await ref.read(
          customerServiceCaseDetailProvider(widget.detail.id).future,
        );
      } catch (_) {
        // The case screen already exposes pull-to-refresh/retry.
      }
    } catch (error) {
      if (!mounted) return;

      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Document upload failed',
        fallbackMessage:
            'The document could not be uploaded right now. Please try again.',
      );
      final message = E2eNetworkAudit.enabled && error is ApiError
          ? error.message
          : failure.message;

      messenger.showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() => _uploading.remove(identity));
      }
    }
  }
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({
    required this.document,
    required this.readOnly,
    required this.canUpload,
    required this.isUploading,
    required this.onUpload,
  });

  final CustomerServiceCaseDocument document;
  final bool readOnly;
  final bool canUpload;
  final bool isUploading;
  final VoidCallback onUpload;

  @override
  Widget build(BuildContext context) {
    final isUnrecorded = readOnly && document.needsUpload;

    final (label, icon, foreground, background) = isUnrecorded
        ? (
            'Not recorded',
            Icons.description_outlined,
            AppTheme.textSecondary,
            AppTheme.background,
          )
        : switch (document.normalizedStatus) {
            'approved' || 'verified' => (
              'Approved',
              Icons.check_circle_outline_rounded,
              const Color(0xFF16864B),
              const Color(0xFFEAF7EF),
            ),
            'rejected' => (
              'Needs correction',
              Icons.error_outline_rounded,
              AppTheme.danger,
              AppTheme.dangerSoft,
            ),
            'uploaded' || 'submitted' || 'under review' => (
              'Under review',
              Icons.hourglass_top_rounded,
              const Color(0xFFA85C00),
              const Color(0xFFFFF4E4),
            ),
            _ => (
              'Required',
              Icons.description_outlined,
              AppTheme.textSecondary,
              AppTheme.background,
            ),
          };

    return Container(
      key: OmcWidgetKeys.caseRequiredDocument(document.uploadIdentity),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: foreground.withValues(alpha: 0.13)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: Icon(icon, size: 19, color: foreground)),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  label: '${document.title}, $label',
                  excludeSemantics: true,
                  child: Text(
                    document.title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                if (document.remarks.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    document.remarks,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
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
              ExcludeSemantics(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (canUpload) ...[
                const SizedBox(height: 6),
                SizedBox(
                  height: 34,
                  child: Semantics(
                    button: true,
                    enabled: !isUploading,
                    label: document.isRejected
                        ? 'Replace document'
                        : 'Upload document',
                    child: Material(
                      color: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: AppTheme.border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        key: OmcWidgetKeys.caseRequiredDocumentUpload(
                          document.uploadIdentity,
                        ),
                        onTap: isUploading ? null : onUpload,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: Center(
                            widthFactor: 1,
                            child: isUploading
                                ? const SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Text(
                                    document.isRejected ? 'Replace' : 'Upload',
                                    style: const TextStyle(
                                      color: AppTheme.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({
    super.key,
    required this.detail,
    required this.canViewPayments,
  });

  final CustomerServiceCaseDetail detail;
  final bool canViewPayments;

  @override
  Widget build(BuildContext context) {
    late final String title;
    late final String message;
    late final IconData icon;
    late final bool showAction;

    if (detail.paymentNotRequired) {
      title = 'No payment required';
      message =
          'This service request has no payment due. You do not need to upload a receipt.';
      icon = Icons.check_circle_outline_rounded;
      showAction = false;
    } else if (detail.paymentNeedsCorrection) {
      title = 'Payment proof needs correction';
      message =
          'Open payments and submit corrected payment proof for this service request.';
      icon = Icons.error_outline_rounded;
      showAction = canViewPayments && detail.paymentId.isNotEmpty;
    } else if (detail.paymentUnderReview) {
      title = 'Payment under review';
      message =
          'OMC is reviewing your submitted payment proof. Do not submit another payment or receipt unless OMC asks for a correction.';
      icon = Icons.hourglass_top_rounded;
      showAction = canViewPayments && detail.paymentId.isNotEmpty;
    } else if (
        detail.paymentId.isEmpty && detail.documentsNeedingUpload > 0) {
      title = 'Complete required documents first';
      message =
          'Payment will become available after all required documents are uploaded for this request.';
      icon = Icons.description_outlined;
      showAction = false;
    } else if (detail.paymentId.isEmpty && detail.payableAmount > 0) {
      title = 'Payment is being prepared';
      message =
          '${detail.currency.isEmpty ? 'PKR' : detail.currency} ${detail.payableAmount.toStringAsFixed(2)} is confirmed. Payment instructions are not available yet; they will appear here when the payment record opens.';
      icon = Icons.hourglass_top_rounded;
      showAction = false;
    } else if (detail.paymentId.isNotEmpty) {
      title = detail.paymentStatus.isEmpty
          ? 'Payment status'
          : detail.paymentStatus;
      message = detail.payableAmount > 0
          ? '${detail.currency.isEmpty ? 'PKR' : detail.currency} ${detail.payableAmount.toStringAsFixed(2)} is recorded for this request.'
          : 'Open payments for the latest payment status.';
      icon = Icons.account_balance_wallet_outlined;
      showAction = canViewPayments;
    } else {
      title = 'Payment not available yet';
      message =
          'No payment action is available right now. Payment details will appear here if this request reaches a payment stage.';
      icon = Icons.account_balance_wallet_outlined;
      showAction = false;
    }

    return PremiumCard(
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primarySoft,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: AppTheme.primary, size: 21),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Payment',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message,
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
          if (showAction) ...[
            const SizedBox(height: 13),
            OutlinedButton.icon(
              onPressed: () => _openPayments(context, detail),
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('Open payments'),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecentActivityCard extends StatelessWidget {
  const _RecentActivityCard({required this.activities});

  final List<CustomerServiceCaseActivity> activities;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Recent activity',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 13),
          for (var index = 0; index < activities.length; index++)
            Padding(
              padding: EdgeInsets.only(
                bottom: index == activities.length - 1 ? 0 : 13,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(
                      Icons.update_rounded,
                      size: 18,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activities[index].title,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (activities[index].subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            activities[index].subtitle,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11.5,
                              height: 1.35,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                        if (activities[index].dateLabel.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            activities[index].dateLabel,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
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

class _CancelRequestCard extends StatelessWidget {
  const _CancelRequestCard({required this.busy, required this.onCancel});

  final bool busy;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Request controls',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Cancellation is available only while this request is still eligible to be cancelled.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: busy ? null : onCancel,
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.close_rounded),
            label: Text(busy ? 'Cancelling...' : 'Cancel request'),
          ),
        ],
      ),
    );
  }
}
