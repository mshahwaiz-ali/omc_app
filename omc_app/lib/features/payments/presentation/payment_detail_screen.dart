import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/premium_empty_state.dart';
import '../../crm/presentation/widgets/crm_detail_widgets.dart';
import '../data/payment_item.dart';
import '../data/payments_repository.dart';

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
              title: 'Payment detail unavailable',
              message:
                  'Payment $paymentId is ready for the backend detail endpoint. Invoice, receipt, and payment actions will appear once data is available.',
            );
          }

          return _PaymentDetailBody(payment: payment);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => PremiumEmptyState(
          icon: Icons.account_balance_wallet_outlined,
          title: 'Payment detail unavailable',
          message:
              'Payment $paymentId could not be loaded right now. Please try again later.',
        ),
      ),
    );
  }
}

class _PaymentDetailBody extends StatelessWidget {
  const _PaymentDetailBody({required this.payment});

  final PaymentItem payment;

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
              'No payment timeline yet. Invoice creation, due reminders, receipt uploads, and reconciliation events will appear here once backend activity data is available.',
        ),
        const SizedBox(height: 16),
        const CrmDetailInfoCard(
          title: 'Actions',
          rows: [
            CrmInfoRow(label: 'Invoice', value: 'Backend-ready placeholder'),
            CrmInfoRow(label: 'Receipt', value: 'Backend-ready placeholder'),
            CrmInfoRow(label: 'Pay now', value: 'Backend-ready placeholder'),
          ],
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
}
