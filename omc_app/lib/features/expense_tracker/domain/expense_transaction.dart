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
    this.merchant,
    this.note,
    this.taxRelevant = false,
    this.businessRelated = false,
    this.recurring = false,
    this.reimbursable = false,
    this.receiptFile,
    this.source = 'Mobile',
    this.status = 'Active',
    this.createdFromGuest = false,
    this.synced = false,
  });

  final String id;
  final ExpenseTransactionType type;
  final double amount;
  final String category;
  final DateTime date;
  final String account;
  final String paymentMethod;
  final String? merchant;
  final String? note;
  final bool taxRelevant;
  final bool businessRelated;
  final bool recurring;
  final bool reimbursable;
  final String? receiptFile;
  final String source;
  final String status;
  final bool createdFromGuest;
  final bool synced;

  bool get isIncome => type == ExpenseTransactionType.income;
  bool get isExpense => type == ExpenseTransactionType.expense;
  bool get isArchived => status.toLowerCase() == 'archived';

  ExpenseTransaction copyWith({
    String? id,
    ExpenseTransactionType? type,
    double? amount,
    String? category,
    DateTime? date,
    String? account,
    String? paymentMethod,
    String? merchant,
    String? note,
    bool? taxRelevant,
    bool? businessRelated,
    bool? recurring,
    bool? reimbursable,
    String? receiptFile,
    String? source,
    String? status,
    bool? createdFromGuest,
    bool? synced,
  }) {
    return ExpenseTransaction(
      id: id ?? this.id,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      date: date ?? this.date,
      account: account ?? this.account,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      merchant: merchant ?? this.merchant,
      note: note ?? this.note,
      taxRelevant: taxRelevant ?? this.taxRelevant,
      businessRelated: businessRelated ?? this.businessRelated,
      recurring: recurring ?? this.recurring,
      reimbursable: reimbursable ?? this.reimbursable,
      receiptFile: receiptFile ?? this.receiptFile,
      source: source ?? this.source,
      status: status ?? this.status,
      createdFromGuest: createdFromGuest ?? this.createdFromGuest,
      synced: synced ?? this.synced,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sync_id': id,
      'type': type.name,
      'transaction_type': isIncome ? 'Income' : 'Expense',
      'amount': amount,
      'category': category,
      'date': date.toIso8601String(),
      'transaction_date': date.toIso8601String().split('T').first,
      'account': account,
      'paymentMethod': paymentMethod,
      'payment_method': paymentMethod,
      'merchant': merchant,
      'note': note,
      'tax_relevant': taxRelevant,
      'business_related': businessRelated,
      'recurring': recurring,
      'reimbursable': reimbursable,
      'receipt_file': receiptFile,
      'source': source,
      'status': status,
      'created_from_guest': createdFromGuest,
      'synced': synced,
    };
  }

  factory ExpenseTransaction.fromJson(Map<String, dynamic> json) {
    final rawType = json['transaction_type'] ?? json['type'];
    final parsedType = rawType?.toString().toLowerCase() == 'income'
        ? ExpenseTransactionType.income
        : ExpenseTransactionType.expense;

    return ExpenseTransaction(
      id: _cleanText(
        json['id'] ?? json['name'] ?? json['sync_id'],
        fallback: '',
      ),
      type: parsedType,
      amount: double.tryParse(json['amount']?.toString() ?? '') ?? 0,
      category: _cleanText(json['category'], fallback: 'Uncategorized'),
      date:
          DateTime.tryParse(
            json['date']?.toString() ??
                json['transaction_date']?.toString() ??
                '',
          ) ??
          DateTime.now(),
      account: _cleanText(json['account'], fallback: 'Cash'),
      paymentMethod: _cleanText(
        json['paymentMethod'] ?? json['payment_method'],
        fallback: 'Cash',
      ),
      merchant: _optionalText(json['merchant']),
      note: _optionalText(json['note']),
      taxRelevant: _boolValue(json['tax_relevant']),
      businessRelated: _boolValue(json['business_related']),
      recurring: _boolValue(json['recurring']),
      reimbursable: _boolValue(json['reimbursable']),
      receiptFile: _optionalText(json['receipt_file'] ?? json['receiptFile']),
      source: _cleanText(json['source'], fallback: 'Mobile'),
      status: _cleanText(json['status'], fallback: 'Active'),
      createdFromGuest: _boolValue(json['created_from_guest']),
      synced: _boolValue(json['synced']),
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

  static bool _boolValue(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;

    final text = value?.toString().trim().toLowerCase();
    return text == 'true' || text == '1' || text == 'yes' || text == 'on';
  }
}
