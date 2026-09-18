class PaymentBankAccount {
  const PaymentBankAccount({
    required this.title,
    required this.bankName,
    required this.accountTitle,
    required this.accountNumber,
    required this.iban,
    required this.branch,
    required this.currency,
  });

  final String title;
  final String bankName;
  final String accountTitle;
  final String accountNumber;
  final String iban;
  final String branch;
  final String currency;

  bool get hasDetails =>
      bankName.isNotEmpty ||
      accountTitle.isNotEmpty ||
      accountNumber.isNotEmpty ||
      iban.isNotEmpty ||
      branch.isNotEmpty;

  String get displayDetails {
    final lines = <String>[
      if (title.isNotEmpty) 'Payment account: $title',
      if (bankName.isNotEmpty) 'Bank: $bankName',
      if (accountTitle.isNotEmpty) 'Account title: $accountTitle',
      if (accountNumber.isNotEmpty) 'Account number: $accountNumber',
      if (iban.isNotEmpty) 'IBAN: $iban',
      if (branch.isNotEmpty) 'Branch: $branch',
      if (currency.isNotEmpty) 'Currency: $currency',
    ];
    return lines.join('\n');
  }
}

enum PaymentStatus {
  pending,
  receiptSubmitted,
  underReview,
  partiallyPaid,
  deferred,
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
    this.paymentExecutionMode,
    this.payLaterApprovedAt,
    this.accountedAmountLabel,
    this.reference,
    this.invoiceNumber,
    this.invoiceNumbers = const <String>[],
    this.paymentProofUrl,
    this.paymentProofUrls = const <String>[],
    this.paymentUrl,
    this.paymentChannel,
    this.paymentActionLabel,
    this.onlineGatewayAvailable = false,
    this.paymentInstructions,
    this.bankAccountDetails,
    this.bankAccount,
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
  final String? accountedAmountLabel;
  final String? reference;
  final String? invoiceNumber;
  final List<String> invoiceNumbers;
  final String? paymentProofUrl;
  final List<String> paymentProofUrls;
  final String? paymentUrl;
  final String? paymentChannel;
  final String? paymentActionLabel;
  final bool onlineGatewayAvailable;
  final String? paymentInstructions;
  final String? bankAccountDetails;
  final PaymentBankAccount? bankAccount;
  final String? dueDateLabel;
  final String? paidDateLabel;
  final String? serviceReference;
  final String? remarks;
  final PaymentStatus status;
  final String? paymentExecutionMode;
  final String? payLaterApprovedAt;
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

  List<String> get effectiveInvoiceNumbers {
    final values = <String>[];
    for (final value in <String>[...invoiceNumbers, invoiceNumber ?? '']) {
      final clean = value.trim();
      if (clean.isNotEmpty && !values.contains(clean)) {
        values.add(clean);
      }
    }
    return List<String>.unmodifiable(values);
  }

  List<String> get effectivePaymentProofUrls {
    final values = <String>[];
    for (final value in <String>[...paymentProofUrls, paymentProofUrl ?? '']) {
      final clean = value.trim();
      if (clean.isNotEmpty && !values.contains(clean)) {
        values.add(clean);
      }
    }
    return List<String>.unmodifiable(values);
  }

  bool get isPayLater =>
      paymentExecutionMode?.trim().toLowerCase() == 'pay later' ||
      status == PaymentStatus.deferred;

  String get executionModeLabel => isPayLater ? 'Pay Later' : 'Prepaid';

  String get heroAmountTitle {
    if (status == PaymentStatus.deferred) return 'Pay Later amount';
    if (status == PaymentStatus.partiallyPaid) return 'ERP accounted';
    if (status == PaymentStatus.paid) return 'ERP paid';
    return 'Installment amount';
  }

  String get heroAmountLabel {
    final accounted = accountedAmountLabel?.trim() ?? '';
    if ((status == PaymentStatus.partiallyPaid ||
            status == PaymentStatus.paid) &&
        accounted.isNotEmpty) {
      return accounted;
    }
    return amountLabel;
  }

  bool get isSettlementEvidenceLocked =>
      status == PaymentStatus.partiallyPaid ||
      status == PaymentStatus.deferred ||
      status == PaymentStatus.paid ||
      status == PaymentStatus.cancelled;

  bool get requiresAction =>
      status == PaymentStatus.pending ||
      status == PaymentStatus.partiallyPaid ||
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
      case PaymentStatus.partiallyPaid:
        return 'Partially Paid';
      case PaymentStatus.deferred:
        return 'Pay Later';
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
