import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/diagnostics/omc_widget_keys.dart';
import '../../../../core/widgets/premium_card.dart';
import '../../data/payment_item.dart';
import 'request_accounting_panel.dart';

class PaymentActionCard extends StatelessWidget {
  const PaymentActionCard({
    required this.payment,
    required this.onInvoice,
    required this.onReceipt,
    required this.onUploadReceipt,
    required this.onPayNow,
    this.isUploadingReceipt = false,
    this.uploadProgress,
    this.onCancelUpload,
    super.key,
  });

  final PaymentItem payment;
  final VoidCallback onInvoice;
  final VoidCallback onReceipt;
  final VoidCallback? onUploadReceipt;
  final VoidCallback onPayNow;
  final bool isUploadingReceipt;
  final double? uploadProgress;
  final VoidCallback? onCancelUpload;

  @override
  Widget build(BuildContext context) {
    final canOpenPaymentAction =
        payment.requiresAction && payment.paymentUrl != null;
    final paymentActionLabel =
        payment.paymentActionLabel?.trim().isNotEmpty == true
        ? payment.paymentActionLabel!.trim()
        : 'Continue payment';
    final canOpenInvoice = payment.invoiceNumber?.trim().isNotEmpty == true;
    final canOpenPaymentProof = payment.paymentProofUrl != null;
    final canUploadReceipt =
        payment.status != PaymentStatus.paid &&
        payment.status != PaymentStatus.cancelled &&
        onUploadReceipt != null;
    final instructions = payment.paymentInstructions?.trim();
    final bankDetails = payment.bankAccountDetails?.trim();
    final serviceRequest = payment.serviceReference?.trim() ?? '';
    final showRequestAccounting = payment.isOwnPayment && serviceRequest.isNotEmpty;

    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Next payment step',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 17,
                height: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            _nextStepMessage(payment, isUploadingReceipt),
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 15,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (instructions?.isNotEmpty == true ||
              bankDetails?.isNotEmpty == true) ...[
            const SizedBox(height: 16),
            _PaymentInstructions(
              instructions: instructions,
              bankDetails: bankDetails,
            ),
          ],
          if (canOpenPaymentAction) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onPayNow,
              icon: Icon(
                payment.onlineGatewayAvailable
                    ? Icons.lock_outline_rounded
                    : Icons.payment_rounded,
              ),
              label: Text(paymentActionLabel),
            ),
            const SizedBox(height: 6),
            Text(
              payment.onlineGatewayAvailable
                  ? 'Opens the secure payment checkout.'
                  : 'Opens the available payment channel for this payment.',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
          if (canUploadReceipt || isUploadingReceipt) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              key: OmcWidgetKeys.paymentUploadReceipt,
              onPressed: isUploadingReceipt || !canUploadReceipt
                  ? null
                  : onUploadReceipt,
              icon: isUploadingReceipt
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file_rounded),
              label: Text(
                isUploadingReceipt
                    ? 'Uploading payment proof'
                    : payment.status == PaymentStatus.rejected
                    ? 'Upload corrected payment proof'
                    : 'Upload payment proof',
              ),
            ),
            if (isUploadingReceipt) ...[
              const SizedBox(height: 10),
              _UploadProgressPanel(
                progress: uploadProgress,
                onCancel: onCancelUpload,
              ),
            ] else ...[
              const SizedBox(height: 6),
              const Text(
                'Uploading proof submits evidence for OMC review; it does not confirm that payment has been verified.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  height: 1.4,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ],
          const Divider(height: 30),
          Semantics(
            header: true,
            child: Text(
              'Payment evidence',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: AppTheme.textPrimary),
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: canOpenInvoice ? onInvoice : null,
            icon: const Icon(Icons.receipt_long_outlined),
            label: Text(
              canOpenInvoice ? 'View invoice' : 'Invoice not available yet',
            ),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: canOpenPaymentProof ? onReceipt : null,
            icon: const Icon(Icons.verified_outlined),
            label: Text(
              canOpenPaymentProof
                  ? 'View submitted payment proof'
                  : 'Payment proof not submitted yet',
            ),
          ),
          if (showRequestAccounting)
            RequestAccountingPanel(serviceRequest: serviceRequest),
        ],
      ),
    );
  }

  String _nextStepMessage(PaymentItem payment, bool uploading) {
    if (uploading) {
      return 'Your payment proof is uploading. You can cancel the upload before it completes.';
    }
    switch (payment.status) {
      case PaymentStatus.pending:
        return 'Complete the available payment step, then submit payment proof when required.';
      case PaymentStatus.overdue:
        return 'This payment is overdue. Complete the available payment step as soon as possible.';
      case PaymentStatus.rejected:
        return 'OMC rejected the submitted proof. Upload corrected payment proof for another review.';
      case PaymentStatus.receiptSubmitted:
      case PaymentStatus.underReview:
        return 'Payment proof has been submitted and is awaiting OMC verification. No paid status is implied yet.';
      case PaymentStatus.partiallyPaid:
        return 'A verified partial payment has been reconciled. The remaining balance is still due.';
      case PaymentStatus.paid:
        return 'This payment is marked paid. Evidence remains available below for reference.';
      case PaymentStatus.cancelled:
        return 'This payment record is cancelled and no payment action is available.';
    }
  }
}

class _PaymentInstructions extends StatelessWidget {
  const _PaymentInstructions({this.instructions, this.bankDetails});

  final String? instructions;
  final String? bankDetails;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment instructions',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (instructions?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            SelectableText(
              instructions!,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ],
          if (bankDetails?.isNotEmpty == true) ...[
            const SizedBox(height: 10),
            const Text(
              'Bank / channel details',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              bankDetails!,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                height: 1.45,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _UploadProgressPanel extends StatelessWidget {
  const _UploadProgressPanel({required this.progress, required this.onCancel});

  final double? progress;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final normalized = progress?.clamp(0.0, 1.0);
    final percent = normalized == null ? null : (normalized * 100).round();

    return Semantics(
      liveRegion: true,
      label: percent == null
          ? 'Uploading payment proof'
          : 'Uploading payment proof, $percent percent',
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.info.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.info.withValues(alpha: 0.14)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    percent == null
                        ? 'Preparing upload...'
                        : 'Uploading payment proof — $percent%',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: onCancel,
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Cancel'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: normalized),
            const SizedBox(height: 8),
            const Text(
              'Upload progress only. Payment remains unverified until OMC completes its review.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
