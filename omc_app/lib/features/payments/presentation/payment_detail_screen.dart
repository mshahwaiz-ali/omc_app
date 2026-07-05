import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/config/api_config.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/premium_empty_state.dart';
import '../../crm/presentation/widgets/crm_detail_widgets.dart';
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
        CrmDetailHeaderCard(
          icon: Icons.account_balance_wallet_outlined,
          title: payment.title,
          subtitle: payment.amountLabel,
          statusLabel: payment.status.label,
        ),
        const SizedBox(height: 16),
        CrmDetailInfoCard(
          title: 'Payment',
          rows: [
            CrmInfoRow(label: 'Reference', value: payment.reference ?? '-'),
            CrmInfoRow(
              label: 'Invoice Link',
              value: payment.invoiceUrl == null ? '-' : 'Available',
            ),
            CrmInfoRow(
              label: 'Receipt Link',
              value: payment.receiptUrl == null ? '-' : 'Available',
            ),
            CrmInfoRow(
              label: 'Payment Link',
              value: payment.paymentUrl == null ? '-' : 'Available',
            ),
            CrmInfoRow(
              label: 'Service',
              value: payment.serviceReference ?? '-',
            ),
            CrmInfoRow(label: 'Due date', value: payment.dueDateLabel ?? '-'),
            CrmInfoRow(label: 'Paid date', value: payment.paidDateLabel ?? '-'),
            CrmInfoRow(label: 'Remarks', value: payment.remarks ?? '-'),
          ],
        ),
        const SizedBox(height: 16),
        const CrmActivityTimelineCard(
          title: 'Payment timeline',
          emptyMessage:
              'No payment timeline yet. Invoice creation, due reminders, receipt uploads, and reconciliation events will appear here when activity data is available.',
        ),
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
