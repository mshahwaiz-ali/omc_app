import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/diagnostics/omc_widget_keys.dart';
import '../../../core/widgets/app_state.dart';
import '../../../core/widgets/omc_premium.dart';
import '../../../core/widgets/premium_card.dart';
import '../data/payment_item.dart';
import '../data/payments_repository.dart';

class PaymentsScreen extends ConsumerWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentsAsync = ref.watch(paymentsProvider);

    return Scaffold(
      key: OmcWidgetKeys.paymentsScreen,
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

    final actionable = sorted
        .where((payment) => payment.requiresAction)
        .toList(growable: false);
    final reviewCount = sorted
        .where(
          (payment) =>
              payment.status == PaymentStatus.receiptSubmitted ||
              payment.status == PaymentStatus.underReview,
        )
        .length;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 132),
      children: [
        _PaymentsHeader(
          paymentCount: sorted.length,
          actionable: actionable,
          reviewCount: reviewCount,
        ),
        const SizedBox(height: 20),
        Semantics(
          header: true,
          child: const Text(
            'Payment records',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 21,
              height: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (var index = 0; index < sorted.length; index++) ...[
          _PaymentCard(payment: sorted[index]),
          if (index != sorted.length - 1) const SizedBox(height: 12),
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
    required this.actionable,
    required this.reviewCount,
  });

  final int paymentCount;
  final List<PaymentItem> actionable;
  final int reviewCount;

  @override
  Widget build(BuildContext context) {
    final actionCount = actionable.length;
    final message = actionCount > 0
        ? '$actionCount payment${actionCount == 1 ? '' : 's'} need your attention'
        : reviewCount > 0
        ? '$reviewCount receipt${reviewCount == 1 ? '' : 's'} under review'
        : 'Your payment records are up to date';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppTheme.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.info.withValues(alpha: 0.14),
                ),
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                color: AppTheme.info,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: const Text(
                      'Payments',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 26,
                        height: 1.12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    message,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 15,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (actionCount > 0) ...[
          const SizedBox(height: 16),
          PremiumCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  actionCount == 1
                      ? 'Amount needing action'
                      : 'Payments needing action',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                if (actionCount == 1)
                  Text(
                    actionable.first.amountLabel,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 28,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else
                  Text(
                    '$actionCount payments',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 28,
                      height: 1.1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                const SizedBox(height: 5),
                Text(
                  actionCount == 1
                      ? _paymentAction(actionable.first).message
                      : 'Amounts are shown on each payment record so currency values are not combined locally.',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ] else if (paymentCount > 0) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: (reviewCount > 0 ? AppTheme.warning : AppTheme.success)
                  .withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              reviewCount > 0
                  ? 'No new payment action is required while OMC reviews your submitted receipt.'
                  : 'No payment action is required right now.',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 15,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
    final isTerminal =
        payment.status == PaymentStatus.paid ||
        payment.status == PaymentStatus.cancelled;

    return Semantics(
      button: true,
      label:
          '${payment.title}, ${payment.amountLabel}, ${payment.status.label}',
      child: PremiumCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final stack =
                    constraints.maxWidth < 360 ||
                    MediaQuery.textScalerOf(context).scale(1) >= 1.4;
                final identity = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payment.title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 17,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (payment.serviceReference?.trim().isNotEmpty ==
                        true) ...[
                      const SizedBox(height: 5),
                      Text(
                        payment.serviceReference!.trim(),
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                          height: 1.35,
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
            const SizedBox(height: 14),
            Text(
              payment.amountLabel,
              style: TextStyle(
                color: isTerminal
                    ? AppTheme.textPrimary.withValues(alpha: 0.78)
                    : AppTheme.textPrimary,
                fontSize: 28,
                height: 1.1,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (payment.dueDateLabel != null ||
                payment.paidDateLabel != null) ...[
              const SizedBox(height: 6),
              Text(
                payment.dueDateLabel != null
                    ? 'Due ${payment.dueDateLabel}'
                    : 'Paid ${payment.paidDateLabel}',
                style: TextStyle(
                  color: payment.status == PaymentStatus.overdue
                      ? AppTheme.danger
                      : AppTheme.textSecondary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            const Divider(height: 28),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(action.icon, size: 20, color: visual.color),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    action.message,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: payment.requiresAction
                  ? FilledButton.icon(
                      onPressed: () => context.push(detailPath),
                      icon: Icon(action.icon),
                      label: Text(action.label),
                    )
                  : OutlinedButton.icon(
                      onPressed: () => context.push(detailPath),
                      icon: Icon(action.icon),
                      label: Text(action.label),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

({Color color, IconData icon}) _paymentVisual(PaymentStatus status) {
  switch (status) {
    case PaymentStatus.pending:
      return (
        color: AppTheme.warning,
        icon: Icons.account_balance_wallet_outlined,
      );
    case PaymentStatus.rejected:
    case PaymentStatus.overdue:
      return (color: AppTheme.danger, icon: Icons.error_outline_rounded);
    case PaymentStatus.receiptSubmitted:
    case PaymentStatus.underReview:
      return (color: AppTheme.info, icon: Icons.hourglass_top_rounded);
    case PaymentStatus.paid:
      return (color: AppTheme.success, icon: Icons.verified_outlined);
    case PaymentStatus.cancelled:
      return (color: AppTheme.textSecondary, icon: Icons.cancel_outlined);
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 132),
      children: [
        const _EmptyPaymentsHeader(),
        SizedBox(height: 18),
        PremiumCard(
          padding: EdgeInsets.all(22),
          child: AppEmptyState(
            icon: Icons.account_balance_wallet_outlined,
            title: 'No payment is due',
            message:
                'A payment will appear here after all required documents are uploaded.',
          ),
        ),
      ],
    );
  }
}

class _EmptyPaymentsHeader extends StatelessWidget {
  const _EmptyPaymentsHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Payments',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 26,
              height: 1.12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        SizedBox(height: 6),
        Text(
          'Pay securely and track submitted receipts.',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 15,
            height: 1.4,
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 132),
      children: [
        const _EmptyPaymentsHeader(),
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 132),
      children: [
        const _EmptyPaymentsHeader(),
        const SizedBox(height: 18),
        for (var index = 0; index < 3; index++) ...[
          const PremiumCard(
            padding: EdgeInsets.all(18),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 44,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Loading payment details...',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (index != 2) const SizedBox(height: 12),
        ],
      ],
    );
  }
}
