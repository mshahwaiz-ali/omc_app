import 'expense_tracker_repository.dart';

Future<void> exportExpensePages(Stream<ExpenseCloudPage> pages, {
  required bool Function() isCancelled,
  required void Function(int) onProgress,
}) async {
  throw UnsupportedError('Complete cloud export is available in the Android app.');
}
