import 'package:flutter/material.dart';

import '../data/payment_review_context.dart';

class PaymentReviewSubmission {
  const PaymentReviewSubmission({
    required this.remarks,
    this.verifiedAmount,
    this.paymentAccount,
  });

  final String remarks;
  final double? verifiedAmount;
  final String? paymentAccount;
}

class PaymentReviewDialog extends StatefulWidget {
  const PaymentReviewDialog({
    required this.rejecting,
    this.reviewContext,
    super.key,
  });

  final bool rejecting;
  final PaymentReviewContext? reviewContext;

  @override
  State<PaymentReviewDialog> createState() => _PaymentReviewDialogState();
}

class _PaymentReviewDialogState extends State<PaymentReviewDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _remarksController;
  late final TextEditingController _amountController;
  String? _selectedAccount;

  @override
  void initState() {
    super.initState();
    _remarksController = TextEditingController();
    final remaining = widget.reviewContext?.remainingAmount ?? 0;
    _amountController = TextEditingController(text: _formatAmount(remaining));
    final accounts =
        widget.reviewContext?.accounts ?? const <PaymentReviewAccount>[];
    if (accounts.length == 1) _selectedAccount = accounts.single.name;
  }

  @override
  void dispose() {
    _remarksController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  String _formatAmount(double amount) {
    if (amount == amount.roundToDouble()) return amount.toStringAsFixed(0);
    return amount.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final review = widget.reviewContext;
    final accounts = review?.accounts ?? const <PaymentReviewAccount>[];
    final canVerify =
        widget.rejecting ||
        ((review?.remainingAmount ?? 0) > 0 && accounts.isNotEmpty);

    return AlertDialog(
      scrollable: true,
      title: Text(widget.rejecting ? 'Reject payment proof' : 'Verify receipt'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.rejecting && review != null) ...[
              Text(
                'Remaining balance: ${review.currency} ${_formatAmount(review.remainingAmount)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Verified amount',
                  helperText:
                      'Enter the amount actually received for this receipt.',
                ),
                validator: (value) {
                  final amount = double.tryParse(
                    (value ?? '').replaceAll(',', '').trim(),
                  );
                  if (amount == null || amount <= 0) {
                    return 'Enter an amount greater than zero.';
                  }
                  if (amount > review.remainingAmount + 0.000001) {
                    return 'Amount cannot exceed the remaining balance.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              if (accounts.isEmpty)
                Text(
                  'No receiving bank/cash account is mapped for this company and currency. Configure an OMC Payment Account before verification.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _selectedAccount,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Received into'),
                  items: [
                    for (final account in accounts)
                      DropdownMenuItem(
                        value: account.name,
                        child: Text(
                          account.modeOfPayment.isEmpty
                              ? account.title
                              : '${account.title} · ${account.modeOfPayment}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _selectedAccount = value),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Select the account where payment was received.'
                      : null,
                ),
              const SizedBox(height: 14),
            ],
            TextFormField(
              controller: _remarksController,
              autofocus: widget.rejecting,
              minLines: 3,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: widget.rejecting
                    ? 'Rejection reason'
                    : 'Review remarks (optional)',
              ),
              validator: (value) =>
                  widget.rejecting && (value ?? '').trim().isEmpty
                  ? 'Rejection reason is required.'
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: canVerify ? _submit : null,
          child: Text(widget.rejecting ? 'Reject proof' : 'Verify receipt'),
        ),
      ],
    );
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amount = widget.rejecting
        ? null
        : double.parse(_amountController.text.replaceAll(',', '').trim());
    Navigator.pop(
      context,
      PaymentReviewSubmission(
        remarks: _remarksController.text.trim(),
        verifiedAmount: amount,
        paymentAccount: widget.rejecting ? null : _selectedAccount,
      ),
    );
  }
}
