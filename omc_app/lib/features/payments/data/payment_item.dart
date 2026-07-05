enum PaymentStatus { pending, paid, overdue, cancelled }

class PaymentItem {
  const PaymentItem({
    required this.id,
    required this.title,
    required this.amountLabel,
    required this.status,
    this.reference,
    this.dueDateLabel,
    this.paidDateLabel,
    this.serviceReference,
    this.remarks,
  });

  final String id;
  final String title;
  final String amountLabel;
  final String? reference;
  final String? dueDateLabel;
  final String? paidDateLabel;
  final String? serviceReference;
  final String? remarks;
  final PaymentStatus status;

  bool get requiresAction =>
      status == PaymentStatus.pending || status == PaymentStatus.overdue;
}

extension PaymentStatusLabel on PaymentStatus {
  String get label {
    switch (this) {
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.overdue:
        return 'Overdue';
      case PaymentStatus.cancelled:
        return 'Cancelled';
    }
  }
}
