import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/expense_transaction.dart';

final expenseTrackerRepositoryProvider = Provider<ExpenseTrackerRepository>((
  ref,
) {
  return const ExpenseTrackerRepository();
});

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
        return 'Backend sync is planned but not enabled yet. Your current entries stay local until sync is available.';
    }
  }
}

class ExpenseTrackerRepository {
  const ExpenseTrackerRepository();

  static const _storageKey = 'omc_expense_tracker_transactions';

  ExpenseTrackerStorageMode get storageMode =>
      ExpenseTrackerStorageMode.localOnly;

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
}
