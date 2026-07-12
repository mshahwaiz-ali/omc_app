import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/omc_premium.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_list_header.dart';
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
            error: (error, _) =>
                _PaymentsErrorView(message: _cleanError(error)),
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
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 164),
      itemCount: payments.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        if (index == 0) return _PaymentsHeader(payments: payments);

        return _PaymentCard(payment: payments[index - 1]);
      },
    );
  }
}

class _PaymentsHeader extends StatelessWidget {
  const _PaymentsHeader({required this.payments});

  final List<PaymentItem> payments;

  @override
  Widget build(BuildContext context) {
    final paidCount = payments
        .where((item) => item.status == PaymentStatus.paid)
        .length;
    final pendingCount = payments
        .where(
          (item) =>
              item.status == PaymentStatus.pending ||
              item.status == PaymentStatus.receiptSubmitted ||
              item.status == PaymentStatus.underReview,
        )
        .length;
    final overdueCount = payments
        .where((item) => item.status == PaymentStatus.overdue)
        .length;
    final actionCount = payments.where((item) => item.requiresAction).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PremiumListHeader(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Payments',
          subtitle: 'Invoices, receipts and payment status in one place.',
          metaLabel: '${payments.length} total',
        ),
        if (payments.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 19),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF111A31), Color(0xFF202C4C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x24111A31),
                  blurRadius: 22,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.10),
                    ),
                  ),
                  child: const Icon(
                    Icons.receipt_long_outlined,
                    color: Colors.white,
                    size: 27,
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Payment overview',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          height: 1.15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        actionCount > 0
                            ? '$actionCount payment${actionCount == 1 ? '' : 's'} need your attention.'
                            : 'All current payment records are up to date.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 12.5,
                          height: 1.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: actionCount > 0
                        ? AppTheme.primary
                        : const Color(0xFF2DA567),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    actionCount > 0 ? '$actionCount action' : 'Up to date',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 1.72,
            children: [
              OmcMetricCard(
                icon: Icons.receipt_long_outlined,
                label: 'Total',
                value: payments.length.toString(),
                color: OmcPremium.payments,
              ),
              OmcMetricCard(
                icon: Icons.hourglass_top_rounded,
                label: 'In progress',
                value: pendingCount.toString(),
                color: OmcPremium.action,
              ),
              OmcMetricCard(
                icon: Icons.warning_amber_rounded,
                label: 'Overdue',
                value: overdueCount.toString(),
                color: OmcPremium.danger,
              ),
              OmcMetricCard(
                icon: Icons.verified_rounded,
                label: 'Paid',
                value: paidCount.toString(),
                color: OmcPremium.success,
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
      ],
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.payment});

  final PaymentItem payment;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(payment.status);
    final detailPath = '/payments/${Uri.encodeComponent(payment.id)}';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => context.push(detailPath),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE7E9EF)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x080B1633),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      _statusIcon(payment.status),
                      color: statusColor,
                      size: 27,
                    ),
                  ),
                  const SizedBox(width: 14),
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
                            fontSize: 16.5,
                            height: 1.2,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (payment.serviceReference?.trim().isNotEmpty ==
                            true) ...[
                          const SizedBox(height: 5),
                          Text(
                            payment.serviceReference!.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFF526887),
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _PaymentStatusPill(
                    label: payment.status.label,
                    color: statusColor,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Amount',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          payment.amountLabel,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 22,
                            height: 1,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (payment.reference?.trim().isNotEmpty == true)
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Reference',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            payment.reference!.trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: const TextStyle(
                              color: Color(0xFF526887),
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              if (payment.dueDateLabel != null ||
                  payment.paidDateLabel != null ||
                  payment.remarks?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 15),
                Container(height: 1, color: const Color(0xFFE7E9EF)),
                const SizedBox(height: 13),
              ],
              if (payment.dueDateLabel != null || payment.paidDateLabel != null)
                Row(
                  children: [
                    Icon(
                      payment.paidDateLabel != null
                          ? Icons.event_available_outlined
                          : Icons.calendar_today_outlined,
                      size: 18,
                      color: payment.paidDateLabel != null
                          ? OmcPremium.success
                          : statusColor,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        payment.paidDateLabel != null
                            ? 'Paid on ${payment.paidDateLabel}'
                            : 'Due ${payment.dueDateLabel}',
                        style: const TextStyle(
                          color: Color(0xFF526887),
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              if (payment.remarks?.trim().isNotEmpty == true) ...[
                if (payment.dueDateLabel != null ||
                    payment.paidDateLabel != null)
                  const SizedBox(height: 10),
                Text(
                  payment.remarks!.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: payment.requiresAction
                    ? FilledButton.icon(
                        onPressed: () => context.push(detailPath),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: Icon(_actionIcon(payment), size: 20),
                        label: Text(
                          _actionLabel(payment),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      )
                    : OutlinedButton.icon(
                        onPressed: () => context.push(detailPath),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: statusColor,
                          side: BorderSide(
                            color: statusColor.withValues(alpha: 0.42),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: Icon(_actionIcon(payment), size: 20),
                        label: Text(
                          _actionLabel(payment),
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _actionLabel(PaymentItem payment) {
    switch (payment.status) {
      case PaymentStatus.pending:
      case PaymentStatus.overdue:
        return payment.paymentUrl?.trim().isNotEmpty == true
            ? 'Pay Now'
            : 'View Payment Details';
      case PaymentStatus.rejected:
        return 'Upload Receipt Again';
      case PaymentStatus.receiptSubmitted:
      case PaymentStatus.underReview:
        return payment.receiptUrl?.trim().isNotEmpty == true
            ? 'View Submitted Receipt'
            : 'View Payment Status';
      case PaymentStatus.paid:
        return payment.receiptUrl?.trim().isNotEmpty == true
            ? 'View Receipt'
            : 'View Payment';
      case PaymentStatus.cancelled:
        return 'View Details';
    }
  }

  IconData _actionIcon(PaymentItem payment) {
    switch (payment.status) {
      case PaymentStatus.pending:
      case PaymentStatus.overdue:
        return payment.paymentUrl?.trim().isNotEmpty == true
            ? Icons.payments_outlined
            : Icons.visibility_outlined;
      case PaymentStatus.rejected:
        return Icons.cloud_upload_outlined;
      case PaymentStatus.receiptSubmitted:
      case PaymentStatus.underReview:
        return Icons.receipt_long_outlined;
      case PaymentStatus.paid:
        return Icons.verified_outlined;
      case PaymentStatus.cancelled:
        return Icons.visibility_outlined;
    }
  }

  Color _statusColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.receiptSubmitted:
      case PaymentStatus.underReview:
        return OmcPremium.review;
      case PaymentStatus.paid:
        return OmcPremium.success;
      case PaymentStatus.rejected:
      case PaymentStatus.overdue:
        return OmcPremium.danger;
      case PaymentStatus.cancelled:
        return OmcPremium.system;
      case PaymentStatus.pending:
        return OmcPremium.action;
    }
  }

  IconData _statusIcon(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.receiptSubmitted:
        return Icons.receipt_long_rounded;
      case PaymentStatus.underReview:
        return Icons.manage_search_rounded;
      case PaymentStatus.paid:
        return Icons.verified_rounded;
      case PaymentStatus.rejected:
        return Icons.report_gmailerrorred_rounded;
      case PaymentStatus.overdue:
        return Icons.warning_amber_rounded;
      case PaymentStatus.cancelled:
        return Icons.cancel_outlined;
      case PaymentStatus.pending:
        return Icons.account_balance_wallet_outlined;
    }
  }
}

class _PaymentStatusPill extends StatelessWidget {
  const _PaymentStatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 124),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _EmptyPaymentsView extends StatelessWidget {
  const _EmptyPaymentsView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 164),
      children: [
        const _PaymentsHeader(payments: []),
        const SizedBox(height: 24),
        PremiumCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: OmcPremium.payments.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: OmcPremium.payments,
                  size: 32,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'No payments yet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Invoices, dues and receipts will appear here when records are available.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _cleanError(Object error) {
  if (error is ApiError && error.message.trim().isNotEmpty) {
    return error.message.trim();
  }

  final message = error.toString().replaceFirst('ApiError:', '').trim();
  if (message.isEmpty) {
    return 'Payments could not be loaded right now. Please try again.';
  }
  return message;
}

class _PaymentsErrorView extends StatelessWidget {
  const _PaymentsErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 164),
      children: [
        const _PaymentsHeader(payments: []),
        const SizedBox(height: 24),
        PremiumCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: OmcPremium.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  color: OmcPremium.danger,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Payments unavailable',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaymentsLoadingRow extends StatelessWidget {
  const _PaymentsLoadingRow({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _PaymentsLoadingBlock(width: 48, height: 48, radius: 16, color: color),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PaymentsLoadingBlock(
                width: double.infinity,
                height: 14,
                radius: 999,
                color: color,
              ),
              const SizedBox(height: 10),
              _PaymentsLoadingBlock(
                width: 170,
                height: 11,
                radius: 999,
                color: color,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaymentsLoadingBlock extends StatelessWidget {
  const _PaymentsLoadingBlock({
    required this.width,
    required this.height,
    required this.radius,
    required this.color,
  });

  final double width;
  final double height;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _PaymentsLoadingView extends StatelessWidget {
  const _PaymentsLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 164),
      itemBuilder: (context, index) {
        if (index == 0) return const _PaymentsHeader(payments: []);

        return PremiumCard(
          padding: const EdgeInsets.all(18),
          child: _PaymentsLoadingRow(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
          ),
        );
      },
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemCount: 4,
    );
  }
}
