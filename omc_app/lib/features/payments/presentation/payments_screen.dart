import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_info_chip.dart';
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
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
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
        .where((item) => item.status == PaymentStatus.pending)
        .length;
    final overdueCount = payments
        .where((item) => item.status == PaymentStatus.overdue)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PremiumListHeader(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Payments',
          subtitle:
              'Track invoices, dues, receipts and service payment status.',
          metaLabel: '${payments.length} total',
        ),
        if (payments.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _PaymentStatTile(
                  icon: Icons.receipt_long_outlined,
                  label: 'Total',
                  value: payments.length.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PaymentStatTile(
                  icon: Icons.hourglass_top_rounded,
                  label: 'Pending',
                  value: pendingCount.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PaymentStatTile(
                  icon: Icons.warning_amber_rounded,
                  label: 'Overdue',
                  value: overdueCount.toString(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _PaymentStatTile(
                  icon: Icons.verified_rounded,
                  label: 'Paid',
                  value: paidCount.toString(),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 10),
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
      padding: const EdgeInsets.all(11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryRed.withValues(alpha: 0.07),
              ),
            ),
            child: Icon(icon, color: AppTheme.primaryRed, size: 17),
          ),
          const SizedBox(height: 9),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.payment});

  final PaymentItem payment;

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(payment.status);

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => context.push('/payments/${Uri.encodeComponent(payment.id)}'),
      child: PremiumCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(_statusIcon(payment.status), color: statusColor),
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
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    payment.amountLabel,
                    style: const TextStyle(
                      color: AppTheme.primaryRed,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      PremiumInfoChip(
                        label: payment.status.label,
                        color: statusColor,
                      ),
                      if (payment.reference != null)
                        PremiumInfoChip(label: payment.reference!),
                      if (payment.dueDateLabel != null)
                        PremiumInfoChip(label: 'Due ${payment.dueDateLabel!}'),
                      if (payment.paidDateLabel != null)
                        PremiumInfoChip(
                          label: 'Paid ${payment.paidDateLabel!}',
                        ),
                      if (payment.serviceReference != null)
                        PremiumInfoChip(label: payment.serviceReference!),
                    ],
                  ),
                  if (payment.remarks != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      payment.remarks!,
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
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppTheme.primaryRed.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.primaryRed,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _statusColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.paid:
        return Colors.green.shade700;
      case PaymentStatus.overdue:
        return Colors.red.shade700;
      case PaymentStatus.cancelled:
        return Colors.grey.shade700;
      case PaymentStatus.pending:
        return Colors.orange.shade800;
    }
  }

  IconData _statusIcon(PaymentStatus status) {
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
}

class _EmptyPaymentsView extends StatelessWidget {
  const _EmptyPaymentsView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
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
                  color: AppTheme.primaryRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: AppTheme.primaryRed,
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
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
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
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.cloud_off_rounded,
                  color: Colors.red,
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
        _PaymentsLoadingBlock(
          width: 48,
          height: 48,
          radius: 16,
          color: color,
        ),
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
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
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
