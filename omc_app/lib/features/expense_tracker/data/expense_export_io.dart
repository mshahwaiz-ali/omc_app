import 'dart:convert';
import 'dart:io';
import 'package:share_plus/share_plus.dart';
import 'expense_tracker_repository.dart';
import 'expense_export_validation.dart';

typedef ExpenseExportPublisher = Future<void> Function(String filePath);

Future<void> exportExpensePages(
  Stream<ExpenseCloudPage> pages, {
  required bool Function() isCancelled,
  required void Function(int) onProgress,
  ExpenseExportPublisher? publish,
}) async {
  if (isCancelled()) {
    throw StateError('Export cancelled.');
  }
  final directory = await Directory.systemTemp.createTemp(
    'omc_expense_export_',
  );
  final partial = File('${directory.path}/expenses.partial');
  final sink = partial.openWrite();
  // Observe asynchronous filesystem errors immediately, including before close.
  Object? writeFailure;
  final writes = sink.done.then<void>(
    (_) {},
    onError: (Object error) {
      writeFailure = error;
    },
  );
  final validation = ExpenseExportValidation();
  var written = 0;
  var closed = false;
  try {
    sink.write('[');
    await for (final page in pages) {
      if (isCancelled()) {
        throw StateError('Export cancelled.');
      }
      validation.add(page);
      for (final entry in page.entries) {
        if (written > 0) {
          sink.write(',');
        }
        sink.write(jsonEncode(entry.toJson()));
        written++;
      }
      await sink.flush();
      if (writeFailure != null) {
        throw StateError('Export file could not be written.');
      }
      onProgress(written);
    }
    validation.finish();
    if (isCancelled()) {
      throw StateError('Export cancelled.');
    }
    sink.write(']');
    await sink.flush();
    closed = true;
    await sink.close();
    await writes;
    if (writeFailure != null) {
      throw StateError('Export file could not be written.');
    }
    final completed = await partial.rename('${directory.path}/expenses.json');
    if (isCancelled()) {
      throw StateError('Export cancelled.');
    }
    if (publish != null) {
      await publish(completed.path);
    } else {
      await Share.shareXFiles([
        XFile(completed.path),
      ], subject: 'OMC expense history');
    }
  } finally {
    if (!closed) {
      try {
        await sink.close();
      } catch (_) {
        /* Preserve the original failure. */
      }
    }
    await writes;
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}
