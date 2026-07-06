import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/api_config.dart';
import '../../../core/network/api_error.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_empty_state.dart';
import '../../documents/application/document_attachment_controller.dart';
import '../data/payment_item.dart';
import '../data/payments_repository.dart';
import 'widgets/payment_action_card.dart';

class PaymentDetailScreen extends ConsumerWidget {
  const PaymentDetailScreen({required this.paymentId, super.key});

  final String paymentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentAsync = ref.watch(paymentDetailProvider(paymentId));

    return Scaffold(
      appBar: AppBar(title: const Text('Payment Details')),
      body: paymentAsync.when(
        data: (payment) {
          if (payment == null) {
            return PremiumEmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Payment details unavailable',
              message:
                  'Payment $paymentId could not be loaded right now. Invoice, receipt, and payment actions will appear when data is available.',
            );
          }

          return _PaymentDetailBody(payment: payment);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => PremiumEmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Payment unavailable',
          message: _cleanError(error),
        ),
      ),
    );
  }
}

String _cleanError(Object error) {
  if (error is ApiError && error.message.trim().isNotEmpty) {
    return error.message.trim();
  }

  final message = error.toString().replaceFirst('ApiError:', '').trim();
  if (message.isEmpty) {
    return 'Payment details could not be loaded right now. Please try again.';
  }
  return message;
}

class _PaymentHeroCard extends StatelessWidget {
  const _PaymentHeroCard({required this.payment});

  final PaymentItem payment;

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
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(17),
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              payment.status.label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              payment.title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 25,
                height: 1.12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              payment.amountLabel,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentQuickStats extends StatelessWidget {
  const _PaymentQuickStats({required this.payment});

  final PaymentItem payment;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PaymentStatTile(
            icon: _paymentStatusIcon(payment.status),
            label: 'Status',
            value: payment.status.label,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PaymentStatTile(
            icon: Icons.receipt_long_outlined,
            label: 'Invoice',
            value: payment.invoiceUrl == null ? 'No' : 'Yes',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _PaymentStatTile(
            icon: Icons.payment_rounded,
            label: 'Pay link',
            value: payment.paymentUrl == null ? 'No' : 'Yes',
          ),
        ),
      ],
    );
  }
}

class _PaymentStatTile extends StatelessWidget {
  const _PaymentStatTile({
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
            value.trim().isEmpty ? '-' : value.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
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

class _PaymentInfoCard extends StatelessWidget {
  const _PaymentInfoCard({required this.payment});

  final PaymentItem payment;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment information',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          _PaymentInfoRow(label: 'Reference', value: payment.reference ?? '-'),
          _PaymentInfoRow(
            label: 'Invoice',
            value: payment.invoiceUrl == null ? '-' : 'Available',
          ),
          _PaymentInfoRow(
            label: 'Receipt',
            value: payment.receiptUrl == null ? '-' : 'Available',
          ),
          _PaymentInfoRow(
            label: 'Payment link',
            value: payment.paymentUrl == null ? '-' : 'Available',
          ),
          _PaymentInfoRow(
            label: 'Service',
            value: payment.serviceReference ?? '-',
          ),
          _PaymentInfoRow(
            label: 'Due date',
            value: payment.dueDateLabel ?? '-',
          ),
          _PaymentInfoRow(
            label: 'Paid date',
            value: payment.paidDateLabel ?? '-',
          ),
          _PaymentInfoRow(label: 'Remarks', value: payment.remarks ?? '-'),
        ],
      ),
    );
  }
}

class _PaymentInfoRow extends StatelessWidget {
  const _PaymentInfoRow({required this.label, required this.value});

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
            width: 92,
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

class _PaymentTimelinePlaceholder extends StatelessWidget {
  const _PaymentTimelinePlaceholder();

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.timeline_rounded,
              color: AppTheme.primaryRed,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Payment timeline',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Invoice creation, due reminders, receipt uploads and reconciliation events will appear here when activity data is available.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
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

IconData _paymentStatusIcon(PaymentStatus status) {
  switch (status) {
    case PaymentStatus.paid:
      return Icons.verified_rounded;
    case PaymentStatus.overdue:
      return Icons.warning_amber_rounded;
    case PaymentStatus.cancelled:
      return Icons.cancel_outlined;
    case PaymentStatus.pending:
      return Icons.account_balance_wallet_outlined;
  }
}

class _PaymentDetailBody extends ConsumerStatefulWidget {
  const _PaymentDetailBody({required this.payment});

  final PaymentItem payment;

  @override
  ConsumerState<_PaymentDetailBody> createState() => _PaymentDetailBodyState();
}

class _PaymentDetailBodyState extends ConsumerState<_PaymentDetailBody> {
  bool _isUploadingReceipt = false;

  PaymentItem get payment => widget.payment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _PaymentHeroCard(payment: payment),
        const SizedBox(height: 16),
        _PaymentQuickStats(payment: payment),
        const SizedBox(height: 16),
        _PaymentInfoCard(payment: payment),
        const SizedBox(height: 16),
        const _PaymentTimelinePlaceholder(),
        const SizedBox(height: 16),
        PaymentActionCard(
          payment: payment,
          isUploadingReceipt: _isUploadingReceipt,
          onInvoice: () => _openPaymentUrl(
            context,
            payment.invoiceUrl,
            fallbackMessage:
                'Payment invoice link is not available for this record.',
          ),
          onReceipt: () => _openPaymentUrl(
            context,
            payment.receiptUrl,
            fallbackMessage:
                'Payment receipt link is not available for this record.',
          ),
          onUploadReceipt: _isUploadingReceipt
              ? null
              : () => _pickAndUploadReceipt(context),
          onPayNow: () => _openPaymentUrl(
            context,
            payment.paymentUrl,
            fallbackMessage:
                'Payment gateway link is not available for this record.',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Payment ID: ${payment.id}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Future<void> _pickAndUploadReceipt(BuildContext context) async {
    final controller = ref.read(documentAttachmentControllerProvider);
    final result = await controller.pickDocuments();

    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    for (final message in result.rejectedMessages) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }

    if (!result.hasAcceptedFiles) {
      return;
    }

    final repository = ref.read(paymentsRepositoryProvider);

    setState(() => _isUploadingReceipt = true);

    try {
      final uploadedFiles = await repository.uploadPaymentReceipts(
        paymentId: payment.id,
        attachments: result.accepted,
      );

      if (!context.mounted) return;

      final uploadedCount = uploadedFiles.length;
      final skippedCount = result.accepted.length - uploadedCount;
      final message = skippedCount > 0
          ? 'Uploaded $uploadedCount receipt(s). $skippedCount file(s) were skipped because their local path was unavailable.'
          : 'Uploaded $uploadedCount receipt(s).';

      messenger.showSnackBar(SnackBar(content: Text(message)));

      ref.invalidate(paymentDetailProvider(payment.id));
      ref.invalidate(paymentsProvider);
    } on ApiError catch (error) {
      if (!context.mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(error.message)));
    } catch (_) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Receipt upload could not be completed right now. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isUploadingReceipt = false);
      }
    }
  }

  Future<void> _openPaymentUrl(
    BuildContext context,
    String? url, {
    required String fallbackMessage,
  }) async {
    final cleanUrl = url?.trim();
    if (cleanUrl == null || cleanUrl.isEmpty) {
      _showSnack(context, fallbackMessage);
      return;
    }

    final uri = _paymentUri(cleanUrl);
    if (uri == null) {
      _showSnack(context, 'Invalid payment link received.');
      return;
    }

    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted) return;

    if (!opened) {
      _showSnack(context, 'Payment link could not be opened right now.');
    }
  }

  Uri? _paymentUri(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    if (uri.hasScheme) {
      return uri;
    }

    if (!url.startsWith('/')) {
      return null;
    }

    final baseUri = Uri.tryParse(ApiConfig.baseUrl);
    if (baseUri == null || !baseUri.hasScheme) {
      return null;
    }

    return baseUri.resolve(url);
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
