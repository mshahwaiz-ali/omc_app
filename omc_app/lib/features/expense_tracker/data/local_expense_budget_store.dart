import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalExpenseBudgetStore {
  const LocalExpenseBudgetStore(this.userId);

  final String? userId;

  static const _storageKeyPrefix = 'omc_expense_tracker_budgets';

  String get _storageKey {
    final cleanUserId = userId?.trim().toLowerCase();
    final identity = cleanUserId == null || cleanUserId.isEmpty
        ? 'guest-device'
        : cleanUserId;
    final namespace = base64Url.encode(utf8.encode(identity)).replaceAll('=', '');
    return '$_storageKeyPrefix::$namespace';
  }

  Future<List<Map<String, dynamic>>> readBudgets() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveBudget(Map<String, dynamic> budget) async {
    final preferences = await SharedPreferences.getInstance();
    final current = [...await readBudgets()];
    final next = Map<String, dynamic>.from(budget);

    final suppliedName = next['name']?.toString().trim() ?? '';
    final category = _normaliseCategory(next['category']);
    final month = next['month']?.toString().trim() ?? '';

    var index = -1;
    if (suppliedName.isNotEmpty) {
      index = current.indexWhere(
        (item) => item['name']?.toString().trim() == suppliedName,
      );
    }

    if (index < 0) {
      index = current.indexWhere(
        (item) =>
            _normaliseCategory(item['category']) == category &&
            (item['month']?.toString().trim() ?? '') == month,
      );
    }

    final name = suppliedName.isNotEmpty
        ? suppliedName
        : index >= 0
        ? current[index]['name']?.toString().trim() ?? ''
        : 'LOCAL-BUD-${DateTime.now().microsecondsSinceEpoch}';

    next['name'] = name.isEmpty
        ? 'LOCAL-BUD-${DateTime.now().microsecondsSinceEpoch}'
        : name;
    next['category'] = category == 'overall' ? null : budget['category'];

    if (index >= 0) {
      current[index] = next;
    } else {
      current.add(next);
    }

    await preferences.setString(_storageKey, jsonEncode(current));
  }

  String _normaliseCategory(dynamic value) {
    final text = value?.toString().trim().toLowerCase() ?? '';
    return text.isEmpty ? 'overall' : text;
  }
}
