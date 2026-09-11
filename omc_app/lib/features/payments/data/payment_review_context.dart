class PaymentReviewAccount {
  const PaymentReviewAccount({
    required this.name,
    required this.title,
    required this.erpAccount,
    required this.modeOfPayment,
  });

  factory PaymentReviewAccount.fromJson(Map<String, dynamic> json) {
    String read(dynamic value) => value?.toString().trim() ?? '';

    return PaymentReviewAccount(
      name: read(json['name']),
      title: read(json['title']),
      erpAccount: read(json['erp_account']),
      modeOfPayment: read(json['mode_of_payment']),
    );
  }

  final String name;
  final String title;
  final String erpAccount;
  final String modeOfPayment;
}

class PaymentReviewContext {
  const PaymentReviewContext({
    required this.currency,
    required this.remainingAmount,
    required this.accounts,
  });

  final String currency;
  final double remainingAmount;
  final List<PaymentReviewAccount> accounts;
}
