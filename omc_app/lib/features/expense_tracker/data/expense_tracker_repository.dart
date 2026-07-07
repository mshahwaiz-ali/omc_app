import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/frappe_client.dart';
import '../domain/expense_transaction.dart';

final expenseTrackerRepositoryProvider = Provider<ExpenseTrackerRepository>((
  ref,
) {
  return ExpenseTrackerRepository(frappeClient: ref.watch(frappeClientProvider));
});

final expenseTrackerStorageModeProvider =
    AsyncNotifierProvider<ExpenseTrackerStorageModeController, ExpenseTrackerStorageMode>(
  ExpenseTrackerStorageModeController.new,
);

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
        return 'Expense tracker entries are saved in local app storage and are not synced to the OMC backend.';
      case ExpenseTrackerStorageMode.syncWithAccount:
        return 'Backend sync APIs are available, but the app still keeps local mode as the default until account sync is explicitly enabled.';
    }
  }
}

class ExpenseTrackerRepository {
  const ExpenseTrackerRepository({required FrappeClient frappeClient})
    : _frappeClient = frappeClient;

  static const _storageKey = 'omc_expense_tracker_transactions';
  static const _storageModeKey = 'omc_expense_tracker_storage_mode';

  final FrappeClient _frappeClient;

  ExpenseTrackerStorageMode get storageMode =>
      ExpenseTrackerStorageMode.localOnly;

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

  Future<List<ExpenseTransaction>> readTransactions() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageKey);

    if (raw == null || raw.trim().isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];

      return decoded
          .whereType<Map>()
          .map(
            (item) =>
                ExpenseTransaction.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((item) => item.id.isNotEmpty && item.amount > 0)
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
    final response = await _frappeClient.getMethod(
      ApiConfig.expenseEntriesMethod,
    );

    final rawEntries = _extractList(response, 'entries');
    return rawEntries
        .map(ExpenseTransaction.fromJson)
        .where((item) => item.id.isNotEmpty && item.amount > 0)
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

  Future<ExpenseTransaction?> updateSyncedTransaction(
    ExpenseTransaction transaction,
  ) async {
    final response = await _frappeClient.postMethod(
      ApiConfig.updateExpenseEntryMethod,
      data: {
        'entry_id': transaction.id,
        ..._toBackendPayload(transaction),
      },
    );

    return _extractTransaction(response);
  }

  Future<bool> deleteSyncedTransaction(String id) async {
    final response = await _frappeClient.postMethod(
      ApiConfig.deleteExpenseEntryMethod,
      data: {'entry_id': id},
    );

    final message = response['message'];
    final payload = message is Map<String, dynamic> ? message : response;
    return payload['deleted'] == true || payload['deleted'].toString() == '1';
  }

  Future<Map<String, dynamic>> fetchSyncedSummary() async {
    final response = await _frappeClient.getMethod(
      ApiConfig.expenseSummaryMethod,
    );

    final message = response['message'];
    if (message is Map<String, dynamic>) return message;
    return response;
  }

  Map<String, dynamic> _toBackendPayload(ExpenseTransaction transaction) {
    return {
      'transaction_type': transaction.isIncome ? 'Income' : 'Expense',
      'amount': transaction.amount,
      'category': transaction.category,
      'transaction_date': transaction.date.toIso8601String().split('T').first,
      'account': transaction.account,
      'payment_method': transaction.paymentMethod,
      'note': transaction.note,
    };
  }

  ExpenseTransaction? _extractTransaction(Map<String, dynamic> response) {
    final message = response['message'];
    final payload = message is Map<String, dynamic> ? message : response;
    final rawEntry = payload['entry'] ?? payload['expense'] ?? payload['data'];

    if (rawEntry is! Map) return null;
    return ExpenseTransaction.fromJson(Map<String, dynamic>.from(rawEntry));
  }

  List<Map<String, dynamic>> _extractList(
    Map<String, dynamic> response,
    String key,
  ) {
    final message = response['message'];
    final payload = message is Map<String, dynamic> ? message : response;
    final raw = payload[key] ?? payload['data'] ?? payload['results'] ?? [];

    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }
}
