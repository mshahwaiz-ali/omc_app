enum PaymentStatus {
  pending,
  receiptSubmitted,
  underReview,
  paid,
  rejected,
  overdue,
  cancelled,
}

class PaymentItem {
  const PaymentItem({
    required this.id,
    required this.title,
    required this.amountLabel,
    required this.status,
    this.reference,
    this.invoiceUrl,
    this.receiptUrl,
    this.paymentUrl,
    this.paymentInstructions,
    this.bankAccountDetails,
    this.dueDateLabel,
    this.paidDateLabel,
    this.serviceReference,
    this.remarks,
  });

  final String id;
  final String title;
  final String amountLabel;
  final String? reference;
  final String? invoiceUrl;
  final String? receiptUrl;
  final String? paymentUrl;
  final String? paymentInstructions;
  final String? bankAccountDetails;
  final String? dueDateLabel;
  final String? paidDateLabel;
  final String? serviceReference;
  final String? remarks;
  final PaymentStatus status;

  bool get requiresAction =>
      status == PaymentStatus.pending ||
      status == PaymentStatus.rejected ||
      status == PaymentStatus.overdue;
}

extension PaymentStatusLabel on PaymentStatus {
  String get label {
    switch (this) {
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.receiptSubmitted:
        return 'Receipt Submitted';
      case PaymentStatus.underReview:
        return 'Under Review';
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.rejected:
        return 'Rejected';
      case PaymentStatus.overdue:
        return 'Overdue';
      case PaymentStatus.cancelled:
        return 'Cancelled';
    }
  }
}
