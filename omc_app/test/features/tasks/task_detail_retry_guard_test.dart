import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('task detail error state provides focused retry recovery', () {
    final source = File(
      'lib/features/tasks/presentation/task_detail_screen.dart',
    ).readAsStringSync();

    expect(source, contains("actionLabel: 'Try again'"));
    expect(source, contains('ref.invalidate(taskDetailProvider(taskId))'));
    expect(source, contains(r'Task $taskId could not be loaded right now.'));
  });
}
