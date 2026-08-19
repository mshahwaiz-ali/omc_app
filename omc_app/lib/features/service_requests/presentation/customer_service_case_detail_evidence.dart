part of 'customer_service_case_detail_screen.dart';

class _DocumentsCard extends StatelessWidget {
  const _DocumentsCard({required this.detail, required this.canViewDocuments});

  final CustomerServiceCaseDetail detail;
  final bool canViewDocuments;

  @override
  Widget build(BuildContext context) {
    final documents = detail.requiredDocuments;
    final needsUpload = detail.documentsNeedingUpload > 0;

    return PremiumCard(
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Semantics(
            header: true,
            child: Text(
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
              needsUpload
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
              _DocumentRow(document: document),
              const SizedBox(height: 8),
            ],
            if (canViewDocuments && needsUpload) ...[
              const SizedBox(height: 5),
              OutlinedButton.icon(
                onPressed: () => context.go('/documents'),
                icon: const Icon(Icons.upload_file_outlined),
                label: const Text('Open documents'),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _DocumentRow extends StatelessWidget {
  const _DocumentRow({required this.document});

  final CustomerServiceCaseDocument document;

  @override
  Widget build(BuildContext context) {
    final (label, icon, foreground, background) = switch (
      document.normalizedStatus
    ) {
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

    return Semantics(
      label: '${document.title}, $label${document.remarks.isEmpty ? '' : ', ${document.remarks}'}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: foreground.withValues(alpha: 0.13)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 19, color: foreground),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    document.title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
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
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.detail, required this.canViewPayments});

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
      showAction = canViewPayments;
    } else if (detail.paymentUnderReview) {
      title = 'Payment under review';
      message =
          'OMC is reviewing your submitted payment proof. Do not submit another payment or receipt unless OMC asks for a correction.';
      icon = Icons.hourglass_top_rounded;
      showAction = canViewPayments;
    } else if (detail.paymentId.isNotEmpty || detail.payableAmount > 0) {
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
          const Semantics(
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
