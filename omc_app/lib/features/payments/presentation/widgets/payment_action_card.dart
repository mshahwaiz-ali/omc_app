import 'package:flutter/material.dart';

import '../../data/payment_item.dart';

class PaymentActionCard extends StatelessWidget {
  const PaymentActionCard({
    required this.payment,
    required this.onInvoice,
    required this.onReceipt,
    required this.onPayNow,
    super.key,
  });

  final PaymentItem payment;
  final VoidCallback onInvoice;
  final VoidCallback onReceipt;
  final VoidCallback onPayNow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canPay = payment.requiresAction;
    final canOpenReceipt = payment.status == PaymentStatus.paid;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Actions', style: theme.textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              'Invoice, receipt, and payment actions are prepared for backend payment endpoints.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _ActionTile(
              icon: Icons.receipt_long_outlined,
              title: 'View invoice',
              subtitle: 'Open the payment invoice when backend URL is ready.',
              onTap: onInvoice,
            ),
            const SizedBox(height: 10),
            _ActionTile(
              icon: Icons.verified_outlined,
              title: 'Download receipt',
              subtitle: canOpenReceipt
                  ? 'Download the paid receipt.'
                  : 'Receipt will be available after payment.',
              enabled: canOpenReceipt,
              onTap: onReceipt,
            ),
            const SizedBox(height: 10),
            _ActionTile(
              icon: Icons.payments_outlined,
              title: 'Pay now',
              subtitle: canPay
                  ? 'Continue to backend payment gateway.'
                  : 'No payment action is required.',
              enabled: canPay,
              onTap: onPayNow,
            ),
          ],
        ),
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
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = enabled
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: enabled ? onTap : null,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withValues(alpha: 0.10),
              foregroundColor: color,
              child: Icon(icon),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}
