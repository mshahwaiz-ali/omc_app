import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/mutation_invalidation.dart';
import '../../../app/theme.dart';
import '../../../core/config/api_config.dart';
import '../../../core/diagnostics/e2e_network_audit.dart';
import '../../../core/diagnostics/omc_widget_keys.dart';
import '../../../core/network/api_error.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/app_back_header.dart';
import '../../../core/widgets/app_state.dart';
import '../../../core/widgets/omc_premium.dart';
import '../../../core/widgets/premium_card.dart';
import '../../auth/application/auth_controller.dart';
import '../../documents/application/document_attachment_controller.dart';
import '../../documents/presentation/document_preview_screen.dart';
import '../data/payment_item.dart';
import '../data/payments_repository.dart';
import 'widgets/payment_action_card.dart';

class PaymentDetailScreen extends ConsumerWidget {
  const PaymentDetailScreen({
    required this.paymentId,
    this.assisted = false,
    this.customerName,
    super.key,
  });

  final String paymentId;
  final bool assisted;
  final String? customerName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentAsync = assisted
        ? ref.watch(assistedPaymentDetailProvider(paymentId))
        : ref.watch(paymentDetailProvider(paymentId));

    return Scaffold(
      key: OmcWidgetKeys.paymentDetailScreen,
      appBar: AppBackHeader(
        title: 'Payment details',
        subtitle: assisted && customerName?.trim().isNotEmpty == true
            ? customerName!.trim()
            : null,
      ),
      body: paymentAsync.when(
        data: (payment) {
          if (payment == null) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: AppEmptyState(
                icon: Icons.account_balance_wallet_outlined,
                title: 'Payment unavailable',
                message:
                    'This payment may have been removed or is no longer available.',
              ),
            );
          }

          return _PaymentDetailBody(
            payment: payment,
            assisted: assisted,
            customerName: customerName,
          );
        },
        loading: () => const _DetailLoadingView(),
        error: (error, _) => Padding(
          padding: const EdgeInsets.all(20),
          child: AppErrorState.fromError(
            error: error,
            fallbackTitle: 'Payment unavailable',
            fallbackMessage:
                'Payment details could not be loaded right now. Please try again.',
            onRetry: () => assisted
                ? ref.invalidate(assistedPaymentDetailProvider(paymentId))
                : ref.invalidate(paymentDetailProvider(paymentId)),
          ),
        ),
      ),
    );
  }
}

class _DetailLoadingView extends StatelessWidget {
  const _DetailLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 132),
      children: [
        PremiumCard(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox.square(
                dimension: 48,
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Loading payment',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Fetching verification state, invoice, proof and payment actions.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaymentHeroCard extends StatelessWidget {
  const _PaymentHeroCard({
    required this.payment,
    required this.assisted,
    required this.customerName,
  });

  final PaymentItem payment;
  final bool assisted;
  final String? customerName;

  @override
  Widget build(BuildContext context) {
    final visual = _paymentVerificationVisual(payment.status);
    final assistedName = customerName?.trim();

    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final stack =
                  constraints.maxWidth < 350 ||
                  MediaQuery.textScalerOf(context).scale(1) >= 1.4;
              final identity = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    payment.title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 21,
                      height: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (assisted && assistedName?.isNotEmpty == true) ...[
                    const SizedBox(height: 5),
                    Text(
                      'Customer: $assistedName',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                        height: 1.4,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              );
              final badge = OmcStatusBadge(
                label: payment.status.label,
                color: visual.color,
                icon: visual.icon,
              );

              if (stack) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [identity, const SizedBox(height: 10), badge],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: identity),
                  const SizedBox(width: 12),
                  badge,
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          const Text(
            'Amount',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            payment.amountLabel,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 28,
              height: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: visual.color.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: visual.color.withValues(alpha: 0.14)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(visual.icon, color: visual.color, size: 21),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        visual.title,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        visual.message,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                          height: 1.45,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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

({Color color, IconData icon, String title, String message})
_paymentVerificationVisual(PaymentStatus status) {
  switch (status) {
    case PaymentStatus.pending:
      return (
        color: AppTheme.warning,
        icon: Icons.account_balance_wallet_outlined,
        title: 'Payment pending',
        message:
            'Payment has not been verified yet. Complete the available payment step and submit proof when required.',
      );
    case PaymentStatus.overdue:
      return (
        color: AppTheme.danger,
        icon: Icons.warning_amber_rounded,
        title: 'Payment overdue',
        message:
            'This payment remains unpaid or unverified past its due date and needs attention.',
      );
    case PaymentStatus.rejected:
      return (
        color: AppTheme.danger,
        icon: Icons.error_outline_rounded,
        title: 'Payment proof needs correction',
        message:
            'The submitted proof was rejected. Upload corrected proof for another finance review.',
      );
    case PaymentStatus.receiptSubmitted:
      return (
        color: AppTheme.info,
        icon: Icons.receipt_long_outlined,
        title: 'Payment proof submitted',
        message:
            'Proof has been received for review. Submission does not mean the payment is verified or paid.',
      );
    case PaymentStatus.underReview:
      return (
        color: AppTheme.info,
        icon: Icons.manage_search_rounded,
        title: 'Payment under review',
        message:
            'OMC is reviewing the submitted proof. The payment is not presented as verified until its status changes to Paid.',
      );
    case PaymentStatus.paid:
      return (
        color: AppTheme.success,
        icon: Icons.verified_rounded,
        title: 'Payment verified',
        message: 'This payment is marked Paid in the backend payment record.',
      );
    case PaymentStatus.cancelled:
      return (
        color: AppTheme.textSecondary,
        icon: Icons.cancel_outlined,
        title: 'Payment cancelled',
        message:
            'This payment record is no longer active and has no payment action.',
      );
  }
}

class _PaymentInfoCard extends StatelessWidget {
  const _PaymentInfoCard({required this.payment});

  final PaymentItem payment;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Payment information',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _PaymentInfoRow(label: 'Reference', value: payment.reference ?? '-'),
          _PaymentInfoRow(
            label: 'Service',
            value: payment.serviceReference ?? '-',
          ),
          _PaymentInfoRow(
            label: 'Payment channel',
            value: payment.paymentChannel?.trim().isNotEmpty == true
                ? payment.paymentChannel!.replaceAll('_', ' ')
                : payment.paymentUrl == null
                ? '-'
                : 'Available',
          ),
          _PaymentInfoRow(
            label: 'Invoice',
            value: payment.invoiceNumber ?? '-',
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
      padding: const EdgeInsets.only(bottom: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stack =
              constraints.maxWidth < 330 ||
              MediaQuery.textScalerOf(context).scale(1) >= 1.4;
          final labelWidget = Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          );
          final valueWidget = Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          );

          if (stack) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [labelWidget, const SizedBox(height: 4), valueWidget],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 104, child: labelWidget),
              const SizedBox(width: 12),
              Expanded(child: valueWidget),
            ],
          );
        },
      ),
    );
  }
}

class _PaymentAdminReviewCard extends StatelessWidget {
  const _PaymentAdminReviewCard({
    required this.payment,
    required this.isReviewing,
    required this.onReview,
  });

  final PaymentItem payment;
  final bool isReviewing;
  final ValueChanged<String>? onReview;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              'Payment review',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Review the submitted payment proof. “Mark paid” records backend status Paid; rejecting the proof requires review remarks.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final stack =
                  constraints.maxWidth < 350 ||
                  MediaQuery.textScalerOf(context).scale(1) >= 1.4;
              final reject = OutlinedButton.icon(
                onPressed: isReviewing || onReview == null
                    ? null
                    : () => onReview?.call('Rejected'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                  side: BorderSide(color: Theme.of(context).colorScheme.error),
                ),
                icon: const Icon(Icons.close_rounded),
                label: const Text('Reject proof'),
              );
              final paid = FilledButton.icon(
                onPressed: isReviewing || onReview == null
                    ? null
                    : () => onReview?.call('Paid'),
                icon: isReviewing
                    ? const SizedBox.square(
                        dimension: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.verified_rounded),
                label: Text(isReviewing ? 'Reviewing' : 'Mark paid'),
              );

              if (stack) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [paid, const SizedBox(height: 8), reject],
                );
              }

              return Row(
                children: [
                  Expanded(child: reject),
                  const SizedBox(width: 10),
                  Expanded(child: paid),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PaymentDetailBody extends ConsumerStatefulWidget {
  const _PaymentDetailBody({
    required this.payment,
    required this.assisted,
    required this.customerName,
  });

  final PaymentItem payment;
  final bool assisted;
  final String? customerName;

  @override
  ConsumerState<_PaymentDetailBody> createState() => _PaymentDetailBodyState();
}

class _PaymentDetailBodyState extends ConsumerState<_PaymentDetailBody> {
  bool _isUploadingReceipt = false;
  bool _isReviewingReceipt = false;
  double? _receiptUploadProgress;
  CancelToken? _receiptUploadCancelToken;

  PaymentItem get payment => widget.payment;

  @override
  void dispose() {
    _receiptUploadCancelToken?.cancel('Upload screen closed.');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final capabilities = ref.watch(authControllerProvider).capabilities;

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 132),
      children: [
        _PaymentHeroCard(
          payment: payment,
          assisted: widget.assisted,
          customerName: widget.customerName,
        ),
        const SizedBox(height: 12),
        PaymentActionCard(
          payment: payment,
          isUploadingReceipt: _isUploadingReceipt,
          uploadProgress: _receiptUploadProgress,
          onCancelUpload: _isUploadingReceipt ? _cancelReceiptUpload : null,
          onInvoice: () => _openAuthenticatedInvoice(context),
          onReceipt: () => _openAuthenticatedPaymentProof(context),
          onUploadReceipt:
              _isUploadingReceipt ||
                  !(capabilities.canUploadPaymentReceipt ||
                      capabilities.canUploadCustomerPaymentReceipt)
              ? null
              : () => _pickAndUploadReceipt(context),
          onPayNow: () => _openPaymentUrl(
            context,
            payment.paymentUrl,
            fallbackMessage: 'Payment action is not available for this record.',
          ),
        ),
        const SizedBox(height: 12),
        _PaymentInfoCard(payment: payment),
        if (!widget.assisted &&
            _canReviewReceipt(payment, capabilities.canReviewPayments)) ...[
          const SizedBox(height: 12),
          _PaymentAdminReviewCard(
            payment: payment,
            isReviewing: _isReviewingReceipt,
            onReview: _isReviewingReceipt
                ? null
                : (status) => _reviewPaymentReceipt(context, status),
          ),
        ],
        const SizedBox(height: 14),
        SelectableText(
          'Payment ID: ${payment.id}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  bool _canReviewReceipt(PaymentItem payment, bool sessionCanReview) {
    return (payment.canReviewPayments || sessionCanReview) &&
        (payment.status == PaymentStatus.receiptSubmitted ||
            payment.status == PaymentStatus.underReview);
  }

  void _invalidatePaymentRelatedState() {
    final caseId = payment.serviceReference?.trim();
    invalidatePaymentMutation(ref, paymentId: payment.id, caseId: caseId);

    if (widget.assisted) {
      ref.invalidate(assistedPaymentDetailProvider(payment.id));
    }
  }

  Future<void> _reviewPaymentReceipt(
    BuildContext context,
    String status,
  ) async {
    final repository = ref.read(paymentsRepositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final remarksController = TextEditingController();
    final remarks = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          scrollable: true,
          title: Text(
            status == 'Rejected'
                ? 'Reject payment proof'
                : 'Mark payment paid?',
          ),
          content: TextField(
            controller: remarksController,
            autofocus: true,
            minLines: 2,
            maxLines: 4,
            onChanged: (_) => setDialogState(() {}),
            decoration: InputDecoration(
              labelText: status == 'Rejected'
                  ? 'Review remarks (required)'
                  : 'Review remarks (optional)',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                FocusScope.of(dialogContext).unfocus();
                Navigator.pop(dialogContext);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: status == 'Rejected'
                  ? FilledButton.styleFrom(
                      backgroundColor: Theme.of(
                        dialogContext,
                      ).colorScheme.error,
                      foregroundColor: Theme.of(
                        dialogContext,
                      ).colorScheme.onError,
                    )
                  : null,
              onPressed:
                  status == 'Rejected' && remarksController.text.trim().isEmpty
                  ? null
                  : () {
                      final value = remarksController.text.trim();
                      FocusScope.of(dialogContext).unfocus();
                      Navigator.pop(dialogContext, value);
                    },
              child: Text(status == 'Rejected' ? 'Reject proof' : 'Mark paid'),
            ),
          ],
        ),
      ),
    );

    await Future<void>.delayed(Duration.zero);
    remarksController.dispose();
    if (remarks == null || !mounted) return;

    setState(() => _isReviewingReceipt = true);

    try {
      await repository.reviewPaymentReceipt(
        paymentId: payment.id,
        status: status,
        remarks: remarks,
      );

      if (!context.mounted) return;

      messenger.showSnackBar(
        SnackBar(content: Text('Payment marked as $status.')),
      );

      _invalidatePaymentRelatedState();
    } catch (error) {
      if (!context.mounted) return;
      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Payment review failed',
        fallbackMessage:
            'Payment review could not be completed right now. Please try again.',
      );
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    } finally {
      if (mounted) {
        setState(() => _isReviewingReceipt = false);
      }
    }
  }

  Future<void> _openAuthenticatedInvoice(BuildContext context) async {
    if (payment.invoiceNumber?.trim().isEmpty ?? true) {
      _showSnack(context, 'Invoice is not available for this payment.');
      return;
    }

    try {
      final file = await ref
          .read(paymentsRepositoryProvider)
          .downloadInvoice(payment, assisted: widget.assisted);

      if (!context.mounted) return;

      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) =>
              DocumentPreviewScreen(fileName: file.name, bytes: file.bytes),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Invoice unavailable',
        fallbackMessage:
            'The authenticated invoice could not be opened right now.',
      );

      _showSnack(context, failure.message);
    }
  }

  Future<void> _openAuthenticatedPaymentProof(BuildContext context) async {
    if (payment.paymentProofUrl?.trim().isEmpty ?? true) {
      _showSnack(context, 'Payment proof is not available for this record.');
      return;
    }
    try {
      final file = await ref
          .read(paymentsRepositoryProvider)
          .downloadPaymentProof(payment);
      if (!context.mounted) return;

      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) =>
              DocumentPreviewScreen(fileName: file.name, bytes: file.bytes),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;
      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Payment proof unavailable',
        fallbackMessage:
            'The authenticated payment proof could not be opened right now.',
      );
      _showSnack(context, failure.message);
    }
  }

  Future<void> _pickAndUploadReceipt(BuildContext context) async {
    if (_isUploadingReceipt) return;

    final capabilities = ref.read(authControllerProvider).capabilities;
    final canUploadReceipt =
        capabilities.canUploadPaymentReceipt ||
        capabilities.canUploadCustomerPaymentReceipt;

    if (!canUploadReceipt) {
      _showSnack(
        context,
        capabilities.isPending
            ? 'Receipt upload will unlock after OMC approves your account.'
            : 'This account cannot upload payment receipts.',
      );
      return;
    }

    final controller = ref.read(documentAttachmentControllerProvider);
    final result = await controller.pickDocuments(
      allowedExtensionsOverride: const ['pdf', 'jpg', 'jpeg', 'png'],
      maxFiles: 1,
    );

    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    for (final message in result.rejectedMessages) {
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }

    if (!result.hasAcceptedFiles) {
      return;
    }

    final repository = ref.read(paymentsRepositoryProvider);
    final cancelToken = CancelToken();
    _receiptUploadCancelToken = cancelToken;

    setState(() {
      _isUploadingReceipt = true;
      _receiptUploadProgress = 0;
    });

    try {
      final uploadedFiles = await repository.uploadPaymentReceipts(
        paymentId: payment.id,
        attachments: result.accepted,
        cancelToken: cancelToken,
        onProgress: (sent, total) {
          if (!mounted || total <= 0) return;
          setState(() {
            _receiptUploadProgress = (sent / total).clamp(0.0, 1.0);
          });
        },
      );

      if (!context.mounted) return;

      final uploadedCount = uploadedFiles.length;
      final message = uploadedCount == 1
          ? 'Receipt uploaded for OMC review.'
          : 'Receipt upload did not complete. Please try again.';

      messenger.showSnackBar(SnackBar(content: Text(message)));

      _invalidatePaymentRelatedState();
    } on DioException catch (error) {
      if (!context.mounted) return;
      if (CancelToken.isCancel(error)) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Receipt upload cancelled.')),
        );
        return;
      }
      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Receipt upload failed',
        fallbackMessage:
            'Receipt upload could not be completed right now. Please try again.',
      );
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    } catch (error) {
      if (!context.mounted) return;
      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Receipt upload failed',
        fallbackMessage:
            'Receipt upload could not be completed right now. Please try again.',
      );
      final message = E2eNetworkAudit.enabled && error is ApiError
          ? error.message
          : failure.message;
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } finally {
      _receiptUploadCancelToken = null;
      if (mounted) {
        setState(() {
          _isUploadingReceipt = false;
          _receiptUploadProgress = null;
        });
      }
    }
  }

  void _cancelReceiptUpload() {
    final token = _receiptUploadCancelToken;
    if (token == null || token.isCancelled) return;
    token.cancel('Cancelled by user.');
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
      _showSnack(context, 'Invalid link received.');
      return;
    }

    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!context.mounted) return;

      if (!opened) {
        _showSnack(context, 'This link could not be opened right now.');
      }
    } catch (error) {
      if (!context.mounted) return;
      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Link unavailable',
        fallbackMessage: 'This link could not be opened right now.',
      );
      _showSnack(context, failure.message);
    }
  }

  Uri? _paymentUri(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    if (uri.hasScheme) {
      return _isAllowedWebScheme(uri.scheme) ? uri : null;
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

  bool _isAllowedWebScheme(String scheme) {
    final normalized = scheme.toLowerCase();
    return normalized == 'https' || normalized == 'http';
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
