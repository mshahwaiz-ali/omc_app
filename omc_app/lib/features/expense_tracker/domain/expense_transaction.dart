enum ExpenseTransactionType { income, expense }

class ExpenseTransaction {
  const ExpenseTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    required this.date,
    this.account = 'Cash',
    this.paymentMethod = 'Cash',
    this.note,
  });

  final String id;
  final ExpenseTransactionType type;
  final double amount;
  final String category;
  final DateTime date;
  final String account;
  final String paymentMethod;
  final String? note;

  bool get isIncome => type == ExpenseTransactionType.income;
  bool get isExpense => type == ExpenseTransactionType.expense;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'amount': amount,
      'category': category,
      'date': date.toIso8601String(),
      'account': account,
      'paymentMethod': paymentMethod,
      'note': note,
    };
  }

  factory ExpenseTransaction.fromJson(Map<String, dynamic> json) {
    return ExpenseTransaction(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() == ExpenseTransactionType.income.name
          ? ExpenseTransactionType.income
          : ExpenseTransactionType.expense,
      amount: double.tryParse(json['amount']?.toString() ?? '') ?? 0,
      category: _cleanText(json['category'], fallback: 'Uncategorized'),
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      account: _cleanText(json['account'], fallback: 'Cash'),
      paymentMethod: _cleanText(json['paymentMethod'], fallback: 'Cash'),
      note: _optionalText(json['note']),
    );
  }

  static String _cleanText(dynamic value, {required String fallback}) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? fallback : text;
  }

  static String? _optionalText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
