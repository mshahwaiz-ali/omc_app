import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../../../core/resilience/app_failure.dart';
import '../../data/payment_accounting_repository.dart';
import '../../data/payment_accounting_summary.dart';
import '../../data/payments_repository.dart';

class RequestAccountingPanel extends ConsumerStatefulWidget {
  const RequestAccountingPanel({required this.serviceRequest, super.key});

  final String serviceRequest;

  @override
  ConsumerState<RequestAccountingPanel> createState() =>
      _RequestAccountingPanelState();
}

class _RequestAccountingPanelState
    extends ConsumerState<RequestAccountingPanel> {
  bool _creatingInstallment = false;

  String get _request => widget.serviceRequest.trim();

  @override
  Widget build(BuildContext context) {
    if (_request.isEmpty) return const SizedBox.shrink();
    final summaryAsync = ref.watch(paymentAccountingSummaryProvider(_request));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(height: 30),
        Semantics(
          header: true,
          child: Text(
            'Service balance',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: AppTheme.textPrimary),
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          'ERP invoice settlement is the financial source of truth for this service request.',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 14,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 14),
        summaryAsync.when(
          loading: () => const _AccountingLoading(),
          error: (error, _) => _AccountingError(
            error: error,
            onRetry: () =>
                ref.invalidate(paymentAccountingSummaryProvider(_request)),
          ),
          data: (summary) => _AccountingContent(
            summary: summary,
            creatingInstallment: _creatingInstallment,
            onCreateInstallment: summary.canMakePayment
                ? () => _createInstallment(context, summary)
                : null,
            onOpenPayment: (paymentId) => _openPayment(context, paymentId),
          ),
        ),
      ],
    );
  }

  Future<void> _createInstallment(
    BuildContext context,
    PaymentAccountingSummary summary,
  ) async {
    if (_creatingInstallment) return;
    final maximum = summary.maximumPaymentAmount;
    if (maximum <= 0) return;

    final amount = await showDialog<double>(
      context: context,
      builder: (_) => _InstallmentDialog(
        currency: summary.currency,
        maximumAmount: maximum,
      ),
    );
    if (amount == null || !mounted) return;

    setState(() => _creatingInstallment = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref
          .read(paymentAccountingRepositoryProvider)
          .createInstallment(serviceRequest: _request, amount: amount);
      if (!context.mounted) return;

      ref.invalidate(paymentAccountingSummaryProvider(_request));
      ref.invalidate(paymentsProvider);

      final paymentId = result.paymentId.trim();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.created
                ? 'Payment installment created.'
                : result.message.isNotEmpty
                ? result.message
                : 'An open payment already exists.',
          ),
        ),
      );
      if (paymentId.isNotEmpty && context.mounted) {
        _openPayment(context, paymentId);
      }
    } catch (error) {
      if (!context.mounted) return;
      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Payment unavailable',
        fallbackMessage:
            'Another payment could not be opened right now. Please try again.',
      );
      messenger.showSnackBar(SnackBar(content: Text(failure.message)));
    } finally {
      if (mounted) setState(() => _creatingInstallment = false);
    }
  }

  void _openPayment(BuildContext context, String paymentId) {
    final id = paymentId.trim();
    if (id.isEmpty) return;
    context.push('/payments/${Uri.encodeComponent(id)}');
  }
}

class _AccountingContent extends StatelessWidget {
  const _AccountingContent({
    required this.summary,
    required this.creatingInstallment,
    required this.onCreateInstallment,
    required this.onOpenPayment,
  });

  final PaymentAccountingSummary summary;
  final bool creatingInstallment;
  final VoidCallback? onCreateInstallment;
  final ValueChanged<String> onOpenPayment;

  @override
  Widget build(BuildContext context) {
    final holdReason = summary.paymentBlockReason.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _AmountMetric(
              label: 'Invoice total',
              value: _money(summary.currency, summary.invoiceTotal),
            ),
            _AmountMetric(
              label: 'ERP paid',
              value: _money(summary.currency, summary.paidAmount),
            ),
            _AmountMetric(
              label: 'Outstanding',
              value: _money(summary.currency, summary.outstandingAmount),
              emphasis: summary.outstandingAmount > 0,
            ),
          ],
        ),
        const SizedBox(height: 12),
        _StatusStrip(summary: summary),
        if (holdReason.isNotEmpty) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.warning.withValues(alpha: 0.18),
              ),
            ),
            child: Text(
              holdReason,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
        if (summary.canMakePayment) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: creatingInstallment ? null : onCreateInstallment,
            icon: creatingInstallment
                ? const SizedBox.square(
                    dimension: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.add_card_rounded),
            label: Text(
              creatingInstallment ? 'Opening payment' : 'Make another payment',
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose any amount up to ${_money(summary.currency, summary.maximumPaymentAmount)}. The same ERP Sales Invoice remains authoritative.',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ] else if (summary.hasOpenPayment) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => onOpenPayment(summary.openPaymentId),
            icon: const Icon(Icons.open_in_new_rounded),
            label: const Text('Open current payment'),
          ),
        ],
        if (summary.payments.isNotEmpty) ...[
          const Divider(height: 30),
          const Text(
            'Payment history',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < summary.payments.length; index++) ...[
            _HistoryRow(
              item: summary.payments[index],
              onOpen: () => onOpenPayment(summary.payments[index].paymentId),
            ),
            if (index != summary.payments.length - 1)
              const Divider(height: 18),
          ],
        ],
      ],
    );
  }
}

class _AmountMetric extends StatelessWidget {
  const _AmountMetric({
    required this.label,
    required this.value,
    this.emphasis = false,
  });

  final String label;
  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 112),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: (emphasis ? AppTheme.warning : AppTheme.info).withValues(
          alpha: 0.055,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (emphasis ? AppTheme.warning : AppTheme.border).withValues(
            alpha: emphasis ? 0.18 : 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.summary});

  final PaymentAccountingSummary summary;

  @override
  Widget build(BuildContext context) {
    final settled = summary.isSettled;
    final color = settled ? AppTheme.success : AppTheme.info;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            settled ? Icons.verified_rounded : Icons.account_balance_outlined,
            color: color,
            size: 20,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              '${summary.accountingStatus} · ${summary.activationStatus.isEmpty ? summary.requestState : summary.activationStatus}',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.item, required this.onOpen});

  final PaymentHistoryItem item;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpen,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${item.status} · ERP ${item.accountingStatus}',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Requested ${_money(item.currency, item.amount)} · Accounted ${_money(item.currency, item.accountedAmount)}',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppTheme.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountingLoading extends StatelessWidget {
  const _AccountingLoading();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SizedBox.square(
          dimension: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Loading ERP settlement balance...',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
        ),
      ],
    );
  }
}

class _AccountingError extends StatelessWidget {
  const _AccountingError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final failure = AppFailureClassifier.classify(
      error,
      fallbackTitle: 'Balance unavailable',
      fallbackMessage: 'ERP settlement balance could not be loaded right now.',
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded, color: AppTheme.warning),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              failure.message,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _InstallmentDialog extends StatefulWidget {
  const _InstallmentDialog({
    required this.currency,
    required this.maximumAmount,
  });

  final String currency;
  final double maximumAmount;

  @override
  State<_InstallmentDialog> createState() => _InstallmentDialogState();
}

class _InstallmentDialogState extends State<_InstallmentDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: _plainAmount(widget.maximumAmount),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Make another payment'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Outstanding: ${_money(widget.currency, widget.maximumAmount)}',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Payment amount',
              prefixText: '${widget.currency} ',
              errorText: _error,
            ),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 8),
          const Text(
            'You can pay the full outstanding amount or a smaller installment.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Continue')),
      ],
    );
  }

  void _submit() {
    final amount = double.tryParse(_controller.text.trim());
    if (amount == null || !amount.isFinite || amount <= 0) {
      setState(() => _error = 'Enter an amount greater than zero.');
      return;
    }
    if (amount > widget.maximumAmount + 0.000001) {
      setState(
        () => _error =
            'Amount cannot exceed ${_money(widget.currency, widget.maximumAmount)}.',
      );
      return;
    }
    Navigator.of(context).pop(amount);
  }
}

String _money(String currency, double amount) {
  final decimals = amount == amount.truncateToDouble() ? 0 : 2;
  return '$currency ${amount.toStringAsFixed(decimals)}';
}

String _plainAmount(double amount) {
  final decimals = amount == amount.truncateToDouble() ? 0 : 2;
  return amount.toStringAsFixed(decimals);
}
