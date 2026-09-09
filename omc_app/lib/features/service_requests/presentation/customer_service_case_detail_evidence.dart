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
    final theme = Theme.of(context);

    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Required documents',
              style: theme.textTheme.titleLarge?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 7),
          if (documents.isEmpty)
            Text(
              'No documents are currently required for this service request.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
                height: 1.4,
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
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            for (var index = 0; index < documents.length; index++) ...[
              _DocumentRow(
                document: documents[index],
                readOnly: isReadOnly,
                canUpload:
                    widget.canUploadDocuments &&
                    !isReadOnly &&
                    documents[index].needsUpload,
                isUploading: _uploading.contains(
                  documents[index].uploadIdentity,
                ),
                onUpload: () => _uploadRequiredDocument(documents[index]),
              ),
              if (index != documents.length - 1)
                const SizedBox(height: 10),
            ],
            if (widget.canViewDocuments && hasUploadedDocuments) ...[
              const SizedBox(height: 16),
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
              const Color(0xFFA15C00),
              const Color(0xFFFFF4E4),
            ),
            _ => (
              'Required',
              Icons.description_outlined,
              AppTheme.textSecondary,
              AppTheme.background,
            ),
          };

    final theme = Theme.of(context);
    return Container(
      key: OmcWidgetKeys.caseRequiredDocument(document.uploadIdentity),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: foreground.withValues(alpha: 0.16)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 330 ||
              MediaQuery.textScalerOf(context).scale(1) >= 1.4;
          final identity = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: foreground.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 20, color: foreground),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      label: '${document.title}, $label',
                      excludeSemantics: true,
                      child: Text(
                        document.title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                    if (document.remarks.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        document.remarks,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: document.isRejected
                              ? theme.colorScheme.error
                              : AppTheme.textSecondary,
                          height: 1.4,
                          fontWeight: document.isRejected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );

          final controls = _DocumentRowControls(
            label: label,
            foreground: foreground,
            canUpload: canUpload,
            isUploading: isUploading,
            document: document,
            onUpload: onUpload,
            expanded: stacked,
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [identity, const SizedBox(height: 12), controls],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: identity),
              const SizedBox(width: 12),
              controls,
            ],
          );
        },
      ),
    );
  }
}

class _DocumentRowControls extends StatelessWidget {
  const _DocumentRowControls({
    required this.label,
    required this.foreground,
    required this.canUpload,
    required this.isUploading,
    required this.document,
    required this.onUpload,
    required this.expanded,
  });

  final String label;
  final Color foreground;
  final bool canUpload;
  final bool isUploading;
  final CustomerServiceCaseDocument document;
  final VoidCallback onUpload;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    if (!canUpload) return status;

    final button = OutlinedButton.icon(
      key: OmcWidgetKeys.caseRequiredDocumentUpload(document.uploadIdentity),
      onPressed: isUploading ? null : onUpload,
      icon: isUploading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.upload_file_outlined),
      label: Text(document.isRejected ? 'Replace' : 'Upload'),
    );

    if (expanded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [Align(alignment: Alignment.centerLeft, child: status),
          const SizedBox(height: 10),
          button,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [status, const SizedBox(height: 8), button],
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
    } else if (detail.paymentId.isEmpty && detail.documentsNeedingUpload > 0) {
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

    final theme = Theme.of(context);
    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Payment',
              style: theme.textTheme.titleLarge?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: AppTheme.textSecondary, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (showAction) ...[
            const SizedBox(height: 16),
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
    final theme = Theme.of(context);
    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Recent activity',
              style: theme.textTheme.titleLarge?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (var index = 0; index < activities.length; index++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.update_rounded,
                    size: 18,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activities[index].title,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (activities[index].subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          activities[index].subtitle,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppTheme.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                      if (activities[index].dateLabel.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          activities[index].dateLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (index != activities.length - 1)
              const Divider(height: 26, color: AppTheme.border),
          ],
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
    final theme = Theme.of(context);
    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Request controls',
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Cancellation is available only while this request is still eligible to be cancelled.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: theme.colorScheme.error,
              side: BorderSide(
                color: theme.colorScheme.error.withValues(alpha: 0.35),
              ),
            ),
            onPressed: busy ? null : onCancel,
            icon: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.close_rounded),
            label: Text(busy ? 'Cancelling…' : 'Cancel request'),
          ),
        ],
      ),
    );
  }
}
