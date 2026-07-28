import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/app_state.dart';
import '../../../core/widgets/premium_card.dart';
import '../data/payment_item.dart';
import '../data/payments_repository.dart';

class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(paymentsProvider);

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(paymentsProvider);
            await ref.read(paymentsProvider.future);
          },
          child: paymentsAsync.when(
            data: (payments) => payments.isEmpty
                ? const _EmptyPaymentsView()
                : _PaymentsList(payments: payments),
            loading: () => const _PaymentsLoadingView(),
            error: (error, _) => _PaymentsErrorView(
              error: error,
              onRetry: () => ref.invalidate(paymentsProvider),
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentsList extends StatelessWidget {
  const _PaymentsList({required this.payments});

  final List<PaymentItem> payments;

  @override
  Widget build(BuildContext context) {
    final sorted = [...payments]
      ..sort((a, b) {
        final actionCompare = (b.requiresAction ? 1 : 0).compareTo(
          a.requiresAction ? 1 : 0,
        );
        if (actionCompare != 0) return actionCompare;
        return _statusRank(a.status).compareTo(_statusRank(b.status));
      });

    final actionCount = sorted
        .where((payment) => payment.requiresAction)
        .length;
    final reviewCount = sorted
        .where(
          (payment) =>
              payment.status == PaymentStatus.receiptSubmitted ||
              payment.status == PaymentStatus.underReview,
        )
        .length;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 150),
      children: [
        _PaymentsHeader(
          paymentCount: sorted.length,
          actionCount: actionCount,
          reviewCount: reviewCount,
        ),
        const SizedBox(height: 14),
        for (var index = 0; index < sorted.length; index++) ...[
          _PaymentCard(payment: sorted[index]),
          if (index != sorted.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }

  int _statusRank(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.rejected:
        return 0;
      case PaymentStatus.overdue:
        return 1;
      case PaymentStatus.pending:
        return 2;
      case PaymentStatus.receiptSubmitted:
        return 3;
      case PaymentStatus.underReview:
        return 4;
      case PaymentStatus.paid:
        return 5;
      case PaymentStatus.cancelled:
        return 6;
    }
  }
}

class _PaymentsHeader extends StatelessWidget {
  const _PaymentsHeader({
    required this.paymentCount,
    required this.actionCount,
    required this.reviewCount,
  });

  final int paymentCount;
  final int actionCount;
  final int reviewCount;

  @override
  Widget build(BuildContext context) {
    final message = actionCount > 0
        ? '$actionCount payment${actionCount == 1 ? '' : 's'} need your attention'
        : reviewCount > 0
        ? '$reviewCount receipt${reviewCount == 1 ? '' : 's'} under review'
        : 'Your payment records are up to date';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                color: AppTheme.primary,
                size: 23,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Payments',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 22,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Pay securely and track submitted receipts.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F5F7),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$paymentCount total',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: actionCount > 0
                ? AppTheme.primary.withValues(alpha: 0.065)
                : const Color(0xFFF4F7F5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: actionCount > 0
                  ? AppTheme.primary.withValues(alpha: 0.10)
                  : const Color(0xFFE7EBE8),
            ),
          ),
          child: Row(
            children: [
              Icon(
                actionCount > 0
                    ? Icons.notifications_active_outlined
                    : reviewCount > 0
                    ? Icons.hourglass_top_rounded
                    : Icons.check_circle_outline_rounded,
                size: 20,
                color: actionCount > 0
                    ? AppTheme.primary
                    : const Color(0xFF287A4D),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.payment});

  final PaymentItem payment;

  @override
  Widget build(BuildContext context) {
    final visual = _paymentVisual(payment.status);
    final detailPath = '/payments/${Uri.encodeComponent(payment.id)}';
    final action = _paymentAction(payment);

    return PremiumCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => context.push(detailPath),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(15, 15, 15, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 43,
                    height: 43,
                    decoration: BoxDecoration(
                      color: visual.background,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(visual.icon, color: visual.color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          payment.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 15,
                            height: 1.2,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (payment.serviceReference?.trim().isNotEmpty ==
                            true) ...[
                          const SizedBox(height: 4),
                          Text(
                            payment.serviceReference!.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusPill(
                    label: payment.status.label,
                    color: visual.color,
                    background: visual.background,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Text(
                      payment.amountLabel,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 21,
                        height: 1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.25,
                      ),
                    ),
                  ),
                  if (payment.dueDateLabel != null)
                    Text(
                      'Due ${payment.dueDateLabel}',
                      style: TextStyle(
                        color: visual.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    )
                  else if (payment.paidDateLabel != null)
                    Text(
                      'Paid ${payment.paidDateLabel}',
                      style: const TextStyle(
                        color: Color(0xFF287A4D),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 13),
              Container(height: 1, color: const Color(0xFFEDF0F2)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(action.icon, size: 18, color: visual.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      action.message,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11.5,
                        height: 1.35,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: () => context.push(detailPath),
                    style: TextButton.styleFrom(
                      foregroundColor: payment.requiresAction
                          ? AppTheme.primary
                          : visual.color,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 8,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      action.label,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w900,
                      ),
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

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 112),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

({Color color, Color background, IconData icon}) _paymentVisual(
  PaymentStatus status,
) {
  switch (status) {
    case PaymentStatus.pending:
      return (
        color: const Color(0xFFA25B00),
        background: const Color(0xFFFFF4E4),
        icon: Icons.account_balance_wallet_outlined,
      );
    case PaymentStatus.rejected:
    case PaymentStatus.overdue:
      return (
        color: const Color(0xFFC62828),
        background: const Color(0xFFFFEBEE),
        icon: Icons.error_outline_rounded,
      );
    case PaymentStatus.receiptSubmitted:
    case PaymentStatus.underReview:
      return (
        color: const Color(0xFF1769AA),
        background: const Color(0xFFEAF3FB),
        icon: Icons.hourglass_top_rounded,
      );
    case PaymentStatus.paid:
      return (
        color: const Color(0xFF287A4D),
        background: const Color(0xFFEAF7EF),
        icon: Icons.verified_outlined,
      );
    case PaymentStatus.cancelled:
      return (
        color: AppTheme.textSecondary,
        background: const Color(0xFFF2F4F6),
        icon: Icons.cancel_outlined,
      );
  }
}

({String label, String message, IconData icon}) _paymentAction(
  PaymentItem payment,
) {
  switch (payment.status) {
    case PaymentStatus.pending:
      return (
        label: 'Continue',
        message: 'Open payment details and submit your receipt.',
        icon: Icons.arrow_forward_rounded,
      );
    case PaymentStatus.overdue:
      return (
        label: 'Pay now',
        message: 'This payment is overdue and needs your attention.',
        icon: Icons.warning_amber_rounded,
      );
    case PaymentStatus.rejected:
      return (
        label: 'Replace receipt',
        message: 'Your receipt needs correction before work can continue.',
        icon: Icons.upload_file_outlined,
      );
    case PaymentStatus.receiptSubmitted:
    case PaymentStatus.underReview:
      return (
        label: 'View status',
        message: 'Your receipt is with OMC for verification.',
        icon: Icons.manage_search_rounded,
      );
    case PaymentStatus.paid:
      return (
        label: 'View',
        message: 'Payment confirmed. Your service can continue.',
        icon: Icons.check_circle_outline_rounded,
      );
    case PaymentStatus.cancelled:
      return (
        label: 'View',
        message: 'This payment record is no longer active.',
        icon: Icons.visibility_outlined,
      );
  }
}

class _EmptyPaymentsView extends StatelessWidget {
  const _EmptyPaymentsView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 150),
      children: const [
        _PaymentsHeader(paymentCount: 0, actionCount: 0, reviewCount: 0),
        SizedBox(height: 18),
        PremiumCard(
          padding: EdgeInsets.all(22),
          child: AppEmptyState(
            icon: Icons.account_balance_wallet_outlined,
            title: 'No payment is due',
            message:
                'A payment will appear here after all required documents are approved.',
          ),
        ),
      ],
    );
  }
}

class _PaymentsErrorView extends StatelessWidget {
  const _PaymentsErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 150),
      children: [
        const _PaymentsHeader(paymentCount: 0, actionCount: 0, reviewCount: 0),
        const SizedBox(height: 18),
        AppErrorState.fromError(
          error: error,
          onRetry: onRetry,
          fallbackTitle: 'Payments unavailable',
          fallbackMessage:
              'Your payment records could not be loaded right now.',
          compact: true,
        ),
      ],
    );
  }
}

class _PaymentsLoadingView extends StatelessWidget {
  const _PaymentsLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 150),
      children: [
        const _PaymentsHeader(paymentCount: 0, actionCount: 0, reviewCount: 0),
        const SizedBox(height: 14),
        for (var index = 0; index < 3; index++) ...[
          const PremiumCard(
            padding: EdgeInsets.all(16),
            child: Row(
              children: [
                SizedBox(
                  width: 42,
                  height: 42,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Loading payment details...',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (index != 2) const SizedBox(height: 10),
        ],
      ],
    );
  }
}
