import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('task detail error state provides focused retry recovery', () {
    final source = File(
      'lib/features/tasks/presentation/task_detail_screen.dart',
    ).readAsStringSync();
    final appState = File('lib/core/widgets/app_state.dart').readAsStringSync();

    expect(source, contains('AppErrorState.fromError('));
    expect(
      source,
      contains('ref.invalidate(taskDetailProvider(widget.taskId))'),
    );
    expect(source, contains("fallbackTitle: 'Task unavailable'"));
    expect(source, contains("'This task could not be loaded right now.'"));
    expect(appState, contains("this.retryLabel = 'Try again'"));
  });
}
