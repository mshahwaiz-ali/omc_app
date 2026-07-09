import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/frappe_client.dart';
import '../domain/expense_transaction.dart';

final expenseTrackerRepositoryProvider = Provider<ExpenseTrackerRepository>((
  ref,
) {
  return ExpenseTrackerRepository(
    frappeClient: ref.watch(frappeClientProvider),
  );
});

final expenseTrackerStorageModeProvider =
    AsyncNotifierProvider<
      ExpenseTrackerStorageModeController,
      ExpenseTrackerStorageMode
    >(ExpenseTrackerStorageModeController.new);

class ExpenseTrackerStorageModeController
    extends AsyncNotifier<ExpenseTrackerStorageMode> {
  late final ExpenseTrackerRepository _repository;

  @override
  Future<ExpenseTrackerStorageMode> build() async {
    _repository = ref.read(expenseTrackerRepositoryProvider);
    return _repository.readStorageMode();
  }

  Future<void> setMode(ExpenseTrackerStorageMode mode) async {
    state = AsyncData(mode);
    await _repository.saveStorageMode(mode);
  }
}

enum ExpenseTrackerStorageMode { localOnly, syncWithAccount }

enum ExpenseTrackerAccessMode {
  guestLocal,
  pendingLocal,
  approvedSync,
  internalHidden,
  offlineApproved,
}

extension ExpenseTrackerStorageModeLabel on ExpenseTrackerStorageMode {
  String get label {
    switch (this) {
      case ExpenseTrackerStorageMode.localOnly:
        return 'Stored only on this device';
      case ExpenseTrackerStorageMode.syncWithAccount:
        return 'Sync with my OMC account';
    }
  }

  String get description {
    switch (this) {
      case ExpenseTrackerStorageMode.localOnly:
        return 'Entries stay safely on this device. You can export JSON backup anytime.';
      case ExpenseTrackerStorageMode.syncWithAccount:
        return 'Approved customers can sync entries to OMC Desk for backup, reports and consultant review.';
    }
  }
}

class ExpenseTrackerConfig {
  const ExpenseTrackerConfig({
    required this.categories,
    required this.guestLimit,
    required this.syncAvailable,
    required this.receiptUploadAvailable,
    required this.reportAvailable,
  });

  factory ExpenseTrackerConfig.fallback() {
    return const ExpenseTrackerConfig(
      categories: ExpenseTrackerCategory.defaultCategories,
      guestLimit: 30,
      syncAvailable: false,
      receiptUploadAvailable: false,
      reportAvailable: false,
    );
  }

  final List<ExpenseTrackerCategory> categories;
  final int guestLimit;
  final bool syncAvailable;
  final bool receiptUploadAvailable;
  final bool reportAvailable;

  factory ExpenseTrackerConfig.fromJson(Map<String, dynamic> json) {
    final rawCategories = json['categories'];
    final categories = rawCategories is List
        ? rawCategories
            .whereType<Map>()
            .map((item) => ExpenseTrackerCategory.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false)
        : const <ExpenseTrackerCategory>[];

    return ExpenseTrackerConfig(
      categories: categories.isEmpty
          ? ExpenseTrackerCategory.defaultCategories
          : categories,
      guestLimit: int.tryParse(json['guest_limit']?.toString() ?? '') ?? 30,
      syncAvailable: _boolValue(json['sync_available']),
      receiptUploadAvailable: _boolValue(json['receipt_upload_available']),
      reportAvailable: _boolValue(json['report_available']),
    );
  }
}

class ExpenseTrackerCategory {
  const ExpenseTrackerCategory({
    required this.name,
    required this.title,
    required this.type,
    this.icon = 'category',
    this.color = '',
    this.isTaxRelevant = false,
    this.businessDefault = false,
    this.sortOrder = 0,
  });

  final String name;
  final String title;
  final ExpenseTransactionType type;
  final String icon;
  final String color;
  final bool isTaxRelevant;
  final bool businessDefault;
  final int sortOrder;

  bool get isIncome => type == ExpenseTransactionType.income;
  bool get isExpense => type == ExpenseTransactionType.expense;

  factory ExpenseTrackerCategory.fromJson(Map<String, dynamic> json) {
    final rawType = json['transaction_type'] ?? json['type'];
    return ExpenseTrackerCategory(
      name: _cleanText(json['name'], fallback: _cleanText(json['title'], fallback: 'Other')),
      title: _cleanText(json['title'] ?? json['category_name'], fallback: 'Other'),
      type: rawType?.toString().toLowerCase() == 'income'
          ? ExpenseTransactionType.income
          : ExpenseTransactionType.expense,
      icon: _cleanText(json['icon'], fallback: 'category'),
      color: _cleanText(json['color'], fallback: ''),
      isTaxRelevant: _boolValue(json['is_tax_relevant']),
      businessDefault: _boolValue(json['business_default']),
      sortOrder: int.tryParse(json['sort_order']?.toString() ?? '') ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'title': title,
      'transaction_type': isIncome ? 'Income' : 'Expense',
      'icon': icon,
      'color': color,
      'is_tax_relevant': isTaxRelevant,
      'business_default': businessDefault,
      'sort_order': sortOrder,
    };
  }

  static const defaultCategories = [
    ExpenseTrackerCategory(name: 'Food', title: 'Food', type: ExpenseTransactionType.expense, icon: 'restaurant', sortOrder: 10),
    ExpenseTrackerCategory(name: 'Fuel', title: 'Fuel', type: ExpenseTransactionType.expense, icon: 'local_gas_station', sortOrder: 20),
    ExpenseTrackerCategory(name: 'Bills', title: 'Bills', type: ExpenseTransactionType.expense, icon: 'receipt', sortOrder: 30),
    ExpenseTrackerCategory(name: 'Rent', title: 'Rent', type: ExpenseTransactionType.expense, icon: 'home', sortOrder: 40),
    ExpenseTrackerCategory(name: 'Shopping', title: 'Shopping', type: ExpenseTransactionType.expense, icon: 'shopping_bag', sortOrder: 50),
    ExpenseTrackerCategory(name: 'Transport', title: 'Transport', type: ExpenseTransactionType.expense, icon: 'directions_car', sortOrder: 60),
    ExpenseTrackerCategory(name: 'Health', title: 'Health', type: ExpenseTransactionType.expense, icon: 'health_and_safety', sortOrder: 70, isTaxRelevant: true),
    ExpenseTrackerCategory(name: 'Education', title: 'Education', type: ExpenseTransactionType.expense, icon: 'school', sortOrder: 80, isTaxRelevant: true),
    ExpenseTrackerCategory(name: 'Business', title: 'Business', type: ExpenseTransactionType.expense, icon: 'business_center', sortOrder: 90, businessDefault: true),
    ExpenseTrackerCategory(name: 'Tax / Legal', title: 'Tax / Legal', type: ExpenseTransactionType.expense, icon: 'gavel', sortOrder: 100, isTaxRelevant: true),
    ExpenseTrackerCategory(name: 'Utilities', title: 'Utilities', type: ExpenseTransactionType.expense, icon: 'bolt', sortOrder: 110),
    ExpenseTrackerCategory(name: 'Other', title: 'Other', type: ExpenseTransactionType.expense, icon: 'category', sortOrder: 999),
    ExpenseTrackerCategory(name: 'Salary', title: 'Salary', type: ExpenseTransactionType.income, icon: 'payments', sortOrder: 10),
    ExpenseTrackerCategory(name: 'Business Income', title: 'Business Income', type: ExpenseTransactionType.income, icon: 'storefront', sortOrder: 20),
    ExpenseTrackerCategory(name: 'Freelance', title: 'Freelance', type: ExpenseTransactionType.income, icon: 'laptop', sortOrder: 30),
    ExpenseTrackerCategory(name: 'Rental Income', title: 'Rental Income', type: ExpenseTransactionType.income, icon: 'apartment', sortOrder: 40),
    ExpenseTrackerCategory(name: 'Investment', title: 'Investment', type: ExpenseTransactionType.income, icon: 'trending_up', sortOrder: 50),
    ExpenseTrackerCategory(name: 'Other Income', title: 'Other Income', type: ExpenseTransactionType.income, icon: 'add_card', sortOrder: 999),
  ];
}

class ExpenseTrackerRepository {
  const ExpenseTrackerRepository({required FrappeClient frappeClient})
    : this._(frappeClient);

  const ExpenseTrackerRepository._(this._frappeClient);

  static const _storageKey = 'omc_expense_tracker_transactions';
  static const _storageModeKey = 'omc_expense_tracker_storage_mode';

  final FrappeClient _frappeClient;

  ExpenseTrackerStorageMode get storageMode => ExpenseTrackerStorageMode.localOnly;

  Future<ExpenseTrackerStorageMode> readStorageMode() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageModeKey);

    if (raw == ExpenseTrackerStorageMode.syncWithAccount.name) {
      return ExpenseTrackerStorageMode.syncWithAccount;
    }

    return ExpenseTrackerStorageMode.localOnly;
  }

  Future<void> saveStorageMode(ExpenseTrackerStorageMode mode) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(_storageModeKey, mode.name);
  }

  Future<ExpenseTrackerConfig> fetchConfig() async {
    try {
      final response = await _frappeClient.getMethod(ApiConfig.expenseConfigMethod);
      final payload = _extractPayload(response);
      return ExpenseTrackerConfig.fromJson(payload);
    } catch (_) {
      return ExpenseTrackerConfig.fallback();
    }
  }

  Future<List<ExpenseTrackerCategory>> fetchCategories() async {
    try {
      final response = await _frappeClient.getMethod(ApiConfig.expenseCategoriesMethod);
      final rawCategories = _extractList(response, 'categories');
      return rawCategories
          .map(ExpenseTrackerCategory.fromJson)
          .toList(growable: false);
    } catch (_) {
      return ExpenseTrackerCategory.defaultCategories;
    }
  }

  Future<List<ExpenseTransaction>> readTransactions() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageKey);

    if (raw == null || raw.trim().isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];

      return decoded
          .whereType<Map>()
          .map((item) => ExpenseTransaction.fromJson(Map<String, dynamic>.from(item)))
          .where((item) => item.id.isNotEmpty && item.amount > 0 && !item.isArchived)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveTransactions(List<ExpenseTransaction> transactions) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      transactions.map((transaction) => transaction.toJson()).toList(),
    );

    await preferences.setString(_storageKey, encoded);
  }

  Future<void> clearTransactions() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(_storageKey);
  }

  Future<List<ExpenseTransaction>> fetchSyncedTransactions() async {
    final response = await _frappeClient.getMethod(ApiConfig.expenseEntriesMethod);
    final rawEntries = _extractList(response, 'entries');
    return rawEntries
        .map(ExpenseTransaction.fromJson)
        .where((item) => item.id.isNotEmpty && item.amount > 0 && !item.isArchived)
        .toList(growable: false);
  }

  Future<ExpenseTransaction?> createSyncedTransaction(
    ExpenseTransaction transaction,
  ) async {
    final response = await _frappeClient.postMethod(
      ApiConfig.createExpenseEntryMethod,
      data: _toBackendPayload(transaction),
    );

    return _extractTransaction(response);
  }

  Future<List<ExpenseTransaction>> bulkSyncTransactions(
    List<ExpenseTransaction> transactions,
  ) async {
    final response = await _frappeClient.postMethod(
      ApiConfig.bulkSyncExpenseEntriesMethod,
      data: {
        'entries': transactions.map((item) => _toBackendPayload(item)).toList(),
      },
    );

    return _extractList(response, 'entries')
        .map(ExpenseTransaction.fromJson)
        .where((item) => item.id.isNotEmpty && item.amount > 0 && !item.isArchived)
        .toList(growable: false);
  }

  Future<ExpenseTransaction?> updateSyncedTransaction(
    ExpenseTransaction transaction,
  ) async {
    final response = await _frappeClient.postMethod(
      ApiConfig.updateExpenseEntryMethod,
      data: {'entry_id': transaction.id, ..._toBackendPayload(transaction)},
    );

    return _extractTransaction(response);
  }

  Future<bool> deleteSyncedTransaction(String id) async {
    final response = await _frappeClient.postMethod(
      ApiConfig.deleteExpenseEntryMethod,
      data: {'entry_id': id},
    );

    final payload = _extractPayload(response);
    return payload['deleted'] == true || payload['deleted'].toString() == '1';
  }

  Future<Map<String, dynamic>> fetchSyncedSummary() async {
    final response = await _frappeClient.getMethod(ApiConfig.expenseSummaryMethod);
    return _extractPayload(response);
  }

  Future<List<Map<String, dynamic>>> fetchBudgets() async {
    final response = await _frappeClient.getMethod(ApiConfig.expenseBudgetsMethod);
    return _extractList(response, 'budgets');
  }

  Future<void> saveBudget(Map<String, dynamic> budget) async {
    await _frappeClient.postMethod(
      ApiConfig.saveExpenseBudgetMethod,
      data: budget,
    );
  }

  Future<String> uploadReceiptFile({
    required String entryId,
    required String fileName,
    String? filePath,
    List<int>? fileBytes,
  }) async {
    final response = await _frappeClient.uploadFile(
      filePath: filePath,
      fileBytes: fileBytes == null ? null : Uint8List.fromList(fileBytes),
      fileName: fileName,
      doctype: ApiConfig.expenseReceiptUploadDoctype,
      docname: entryId,
      isPrivate: true,
    );

    final payload = _extractPayload(response);
    final message = payload['message'];
    final fileUrl = message is Map
        ? message['file_url'] ?? message['file_url'.toString()]
        : payload['file_url'];

    return fileUrl?.toString() ?? '';
  }

  Map<String, dynamic> _toBackendPayload(ExpenseTransaction transaction) {
    return {
      'sync_id': transaction.id,
      'transaction_type': transaction.isIncome ? 'Income' : 'Expense',
      'amount': transaction.amount,
      'category': transaction.category,
      'transaction_date': transaction.date.toIso8601String().split('T').first,
      'account': transaction.account,
      'payment_method': transaction.paymentMethod,
      'merchant': transaction.merchant,
      'note': transaction.note,
      'tax_relevant': transaction.taxRelevant ? 1 : 0,
      'business_related': transaction.businessRelated ? 1 : 0,
      'recurring': transaction.recurring ? 1 : 0,
      'reimbursable': transaction.reimbursable ? 1 : 0,
      'receipt_file': transaction.receiptFile,
      'source': transaction.source,
      'status': transaction.status,
      'created_from_guest': transaction.createdFromGuest ? 1 : 0,
    };
  }

  ExpenseTransaction? _extractTransaction(Map<String, dynamic> response) {
    final payload = _extractPayload(response);
    final rawEntry = payload['entry'] ?? payload['expense'] ?? payload['data'];

    if (rawEntry is! Map) return null;
    return ExpenseTransaction.fromJson(Map<String, dynamic>.from(rawEntry));
  }

  Map<String, dynamic> _extractPayload(Map<String, dynamic> response) {
    final message = response['message'];
    if (message is Map<String, dynamic>) return message;
    return response;
  }

  List<Map<String, dynamic>> _extractList(
    Map<String, dynamic> response,
    String key,
  ) {
    final payload = _extractPayload(response);
    final raw = payload[key] ?? payload['data'] ?? payload['results'] ?? [];

    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }
}

String _cleanText(dynamic value, {required String fallback}) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? fallback : text;
}

bool _boolValue(dynamic value) {
  if (value is bool) return value;
  if (value is num) return value != 0;

  final text = value?.toString().trim().toLowerCase();
  return text == 'true' || text == '1' || text == 'yes' || text == 'on';
}
