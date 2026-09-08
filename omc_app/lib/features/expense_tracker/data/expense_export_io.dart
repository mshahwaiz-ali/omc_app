import 'dart:convert';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'expense_tracker_repository.dart';

Future<void> exportExpensePages(Stream<ExpenseCloudPage> pages, {
  required bool Function() isCancelled,
  required void Function(int) onProgress,
}) async {
  final directory = await Directory.systemTemp.createTemp('omc_expense_export_');
  final file = File('${directory.path}/expenses.json');
  final sink = file.openWrite();
  var count = 0;
  int? expectedCount;
  try {
    sink.write('[');
    await for (final page in pages) {
      if (isCancelled()) throw StateError('Cancelled');
      final total = (page.summary['transaction_count'] as num?)?.toInt();
      expectedCount ??= total;
      if (total != expectedCount) throw StateError('History changed during export. Please retry.');
      for (final entry in page.entries) {
        if (count > 0) sink.write(',');
        sink.write(jsonEncode(entry.toJson()));
        count++;
      }
      await sink.flush();
      onProgress(count);
    }
    if (expectedCount == null || count != expectedCount || isCancelled()) {
      throw StateError('Export incomplete. Please retry.');
    }
    sink.write(']');
    await sink.flush();
    await sink.close();
    if (isCancelled()) throw StateError('Cancelled');
    await Share.shareXFiles([XFile(file.path)], subject: 'OMC expense history');
  } finally {
    await sink.close();
    await directory.delete(recursive: true);
  }
}
