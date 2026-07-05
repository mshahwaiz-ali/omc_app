enum ExpenseTransactionType { income, expense }

class ExpenseTransaction {
  const ExpenseTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.category,
    required this.date,
    this.note,
  });

  final String id;
  final ExpenseTransactionType type;
  final double amount;
  final String category;
  final DateTime date;
  final String? note;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'amount': amount,
      'category': category,
      'date': date.toIso8601String(),
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
      category: json['category']?.toString() ?? 'Uncategorized',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      note: json['note']?.toString(),
    );
  }
}
