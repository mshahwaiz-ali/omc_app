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
    this.invoiceNumber,
    this.paymentProofUrl,
    this.paymentUrl,
    this.paymentChannel,
    this.paymentActionLabel,
    this.onlineGatewayAvailable = false,
    this.paymentInstructions,
    this.bankAccountDetails,
    this.dueDateLabel,
    this.paidDateLabel,
    this.serviceReference,
    this.remarks,
    this.canReviewPayments = false,
    this.customerName,
    this.customerProfile,
    this.scopeType,
  });

  final String id;
  final String title;
  final String amountLabel;
  final String? reference;
  final String? invoiceNumber;
  final String? paymentProofUrl;
  final String? paymentUrl;
  final String? paymentChannel;
  final String? paymentActionLabel;
  final bool onlineGatewayAvailable;
  final String? paymentInstructions;
  final String? bankAccountDetails;
  final String? dueDateLabel;
  final String? paidDateLabel;
  final String? serviceReference;
  final String? remarks;
  final PaymentStatus status;
  final bool canReviewPayments;
  final String? customerName;
  final String? customerProfile;
  final String? scopeType;

  bool get isReferralPayment => scopeType?.trim().toLowerCase() == 'referral';

  bool get isOwnPayment => scopeType?.trim().toLowerCase() == 'own';

  String get customerLabel {
    final name = customerName?.trim();
    if (name != null && name.isNotEmpty) return name;

    final profile = customerProfile?.trim();
    if (profile != null && profile.isNotEmpty) return profile;

    return isReferralPayment ? 'Referral customer' : 'My payment';
  }

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
