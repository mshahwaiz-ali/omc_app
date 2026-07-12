import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../../../core/widgets/premium_card.dart';
import '../../data/payment_item.dart';

class PaymentActionCard extends StatelessWidget {
  const PaymentActionCard({
    required this.payment,
    required this.onInvoice,
    required this.onReceipt,
    required this.onUploadReceipt,
    required this.onPayNow,
    this.isUploadingReceipt = false,
    super.key,
  });

  final PaymentItem payment;
  final VoidCallback onInvoice;
  final VoidCallback onReceipt;
  final VoidCallback? onUploadReceipt;
  final VoidCallback onPayNow;
  final bool isUploadingReceipt;

  @override
  Widget build(BuildContext context) {
    final canContactSupport =
        payment.requiresAction && payment.paymentUrl != null;
    final canOpenReceipt = payment.receiptUrl != null;
    final canUploadReceipt =
        payment.status != PaymentStatus.paid &&
        payment.status != PaymentStatus.cancelled &&
        onUploadReceipt != null;

    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              _ActionHeaderIcon(),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Payment actions',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Contact OMC, upload payment proof, and track review status.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
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
          const SizedBox(height: 18),
          if (canContactSupport) ...[
            _ActionTile(
              icon: Icons.chat_rounded,
              title: 'Contact OMC on WhatsApp',
              subtitle:
                  'Get account details and confirm this payment with OMC.',
              enabled: true,
              onTap: onPayNow,
            ),
            const SizedBox(height: 10),
          ],
          if (canUploadReceipt || isUploadingReceipt) ...[
            _ActionTile(
              icon: isUploadingReceipt
                  ? Icons.hourglass_top_rounded
                  : Icons.upload_file_rounded,
              title: isUploadingReceipt
                  ? 'Uploading receipt'
                  : 'Upload receipt',
              subtitle: isUploadingReceipt
                  ? 'Please wait while the receipt is uploaded.'
                  : payment.status == PaymentStatus.rejected
                  ? 'Upload corrected proof for finance review.'
                  : 'Attach payment proof for verification.',
              enabled: !isUploadingReceipt && canUploadReceipt,
              onTap: canUploadReceipt ? onUploadReceipt : null,
            ),
            const SizedBox(height: 10),
          ],
          _ActionTile(
            icon: Icons.verified_outlined,
            title: 'Download receipt',
            subtitle: canOpenReceipt
                ? 'Download the paid receipt.'
                : 'Receipt will be available after reconciliation.',
            enabled: canOpenReceipt,
            onTap: onReceipt,
          ),
        ],
      ),
    );
  }
}

class _ActionHeaderIcon extends StatelessWidget {
  const _ActionHeaderIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: AppTheme.primaryRed.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.08)),
      ),
      child: const Icon(
        Icons.bolt_rounded,
        color: AppTheme.primaryRed,
        size: 22,
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final color = enabled ? AppTheme.primaryRed : AppTheme.textSecondary;

    return Material(
      color: enabled
          ? AppTheme.primaryRed.withValues(alpha: 0.045)
          : Colors.black.withValues(alpha: 0.025),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: enabled ? 0.10 : 0.06),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: color.withValues(alpha: enabled ? 0.10 : 0.06),
                  ),
                ),
                child: Icon(icon, color: color, size: 21),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: enabled
                            ? AppTheme.textPrimary
                            : AppTheme.textSecondary,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
              const SizedBox(width: 10),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: enabled
                      ? Colors.white.withValues(alpha: 0.72)
                      : Colors.black.withValues(alpha: 0.025),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: enabled ? AppTheme.primaryRed : AppTheme.textSecondary,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
