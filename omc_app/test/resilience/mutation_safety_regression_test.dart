import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('critical UI mutations remain duplicate-safe and recoverable', () {
    final support = File(
      'lib/features/support/presentation/support_screen.dart',
    ).readAsStringSync();
    final expenses = File(
      'lib/features/expense_tracker/presentation/'
      'expense_tracker_screen.dart',
    ).readAsStringSync();
    final review = File(
      'lib/features/auth/presentation/under_review_screen.dart',
    ).readAsStringSync();

    expect(support, contains('if (_isSubmitting) return;'));

    expect(expenses, contains('bool _isSaving = false;'));
    expect(expenses, contains('if (_isSaving) return;'));
    expect(expenses, contains('isLoading: _isSaving'));
    expect(expenses, contains('onPressed: _isSaving ? null : _save'));
    expect(expenses, contains("fallbackTitle: 'Transaction not saved'"));
    expect(expenses, contains('setState(() => _isSaving = false)'));

    expect(review, contains("fallbackTitle: 'Sign out incomplete'"));
    expect(review, contains('setState(() => _loggingOut = false)'));
  });
}
