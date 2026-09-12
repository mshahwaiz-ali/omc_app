class PaymentAccountingSummary {
  const PaymentAccountingSummary({
    required this.requestId,
    required this.canonicalInvoice,
    required this.currency,
    required this.invoiceTotal,
    required this.paidAmount,
    required this.outstandingAmount,
    required this.accountingStatus,
    required this.activationStatus,
    required this.requestState,
    required this.canMakePayment,
    required this.maximumPaymentAmount,
    required this.paymentBlockReason,
    required this.openPaymentId,
    required this.payments,
  });

  factory PaymentAccountingSummary.fromJson(Map<String, dynamic> json) {
    final rawPayments = json['payments'];
    return PaymentAccountingSummary(
      requestId: _text(json['request']),
      canonicalInvoice: _text(json['canonical_invoice']),
      currency: _text(json['currency'], fallback: 'PKR'),
      invoiceTotal: _number(json['invoice_total']),
      paidAmount: _number(json['paid_amount']),
      outstandingAmount: _number(json['outstanding_amount']),
      accountingStatus: _text(json['accounting_status'], fallback: 'Unmatched'),
      activationStatus: _text(json['activation_status']),
      requestState: _text(json['request_state']),
      canMakePayment: _bool(json['can_make_payment']),
      maximumPaymentAmount: _number(json['maximum_payment_amount']),
      paymentBlockReason: _text(json['payment_block_reason']),
      openPaymentId: _text(json['open_payment']),
      payments: rawPayments is List
          ? rawPayments
                .whereType<Map<String, dynamic>>()
                .map(PaymentHistoryItem.fromJson)
                .toList(growable: false)
          : const <PaymentHistoryItem>[],
    );
  }

  final String requestId;
  final String canonicalInvoice;
  final String currency;
  final double invoiceTotal;
  final double paidAmount;
  final double outstandingAmount;
  final String accountingStatus;
  final String activationStatus;
  final String requestState;
  final bool canMakePayment;
  final double maximumPaymentAmount;
  final String paymentBlockReason;
  final String openPaymentId;
  final List<PaymentHistoryItem> payments;

  bool get isSettled =>
      accountingStatus.trim().toLowerCase() == 'settled' ||
      outstandingAmount <= 0.000001;

  bool get hasOpenPayment => openPaymentId.trim().isNotEmpty;
}

class PaymentHistoryItem {
  const PaymentHistoryItem({
    required this.paymentId,
    required this.title,
    required this.amount,
    required this.accountedAmount,
    required this.currency,
    required this.status,
    required this.receiptStatus,
    required this.accountingStatus,
    required this.linkedInvoice,
    required this.linkedPaymentEntry,
    required this.paidOn,
    required this.createdAt,
  });

  factory PaymentHistoryItem.fromJson(Map<String, dynamic> json) {
    return PaymentHistoryItem(
      paymentId: _text(json['payment']),
      title: _text(json['title'], fallback: 'Service payment'),
      amount: _number(json['amount']),
      accountedAmount: _number(json['accounted_amount']),
      currency: _text(json['currency'], fallback: 'PKR'),
      status: _text(json['status'], fallback: 'Pending'),
      receiptStatus: _text(json['receipt_status'], fallback: 'Not Submitted'),
      accountingStatus: _text(json['accounting_status'], fallback: 'Unmatched'),
      linkedInvoice: _text(json['linked_invoice']),
      linkedPaymentEntry: _text(json['linked_payment_entry']),
      paidOn: _text(json['paid_on']),
      createdAt: _text(json['created_at']),
    );
  }

  final String paymentId;
  final String title;
  final double amount;
  final double accountedAmount;
  final String currency;
  final String status;
  final String receiptStatus;
  final String accountingStatus;
  final String linkedInvoice;
  final String linkedPaymentEntry;
  final String paidOn;
  final String createdAt;
}

class CreateInstallmentResult {
  const CreateInstallmentResult({
    required this.created,
    required this.paymentId,
    required this.amount,
    required this.currency,
    required this.status,
    required this.accountingStatus,
    required this.remainingBeforePayment,
    required this.maximumPaymentAmount,
    required this.linkedInvoice,
    required this.message,
  });

  factory CreateInstallmentResult.fromJson(Map<String, dynamic> json) {
    return CreateInstallmentResult(
      created: _bool(json['created']),
      paymentId: _text(json['payment']),
      amount: _number(json['amount']),
      currency: _text(json['currency'], fallback: 'PKR'),
      status: _text(json['status'], fallback: 'Pending'),
      accountingStatus: _text(json['accounting_status']),
      remainingBeforePayment: _number(json['remaining_before_payment']),
      maximumPaymentAmount: _number(json['maximum_payment_amount']),
      linkedInvoice: _text(json['linked_invoice']),
      message: _text(json['message']),
    );
  }

  final bool created;
  final String paymentId;
  final double amount;
  final String currency;
  final String status;
  final String accountingStatus;
  final double remainingBeforePayment;
  final double maximumPaymentAmount;
  final String linkedInvoice;
  final String message;
}

double _number(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

bool _bool(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final text = value?.toString().trim().toLowerCase() ?? '';
  return text == '1' || text == 'true' || text == 'yes' || text == 'on';
}

String _text(dynamic value, {String fallback = ''}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}
