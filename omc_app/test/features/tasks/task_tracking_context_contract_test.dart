import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('task model maps direct ERP tracking context', () {
    final source = File(
      'lib/features/tasks/data/task_item.dart',
    ).readAsStringSync();

    for (final token in [
      'workflowState',
      'taskType',
      'source',
      'company',
      'progress',
      'expectedStartDate',
      "json['workflow_state']",
      "json['task_type']",
      "json['source']",
      "json['company']",
      "json['progress']",
      "json['expected_start_date']",
    ]) {
      expect(source, contains(token));
    }
  });

  test('task card uses customer and task type as business context', () {
    final source = File(
      'lib/features/tasks/presentation/tasks_screen.dart',
    ).readAsStringSync();

    expect(source, contains('task.customerName'));
    expect(source, contains('task.taskType'));
  });

  test('task detail keeps ERP workflow and operation statuses distinct', () {
    final source = File(
      'lib/features/tasks/presentation/task_detail_screen.dart',
    ).readAsStringSync();

    expect(source, contains("'ERP status'"));
    expect(source, contains("'Workflow state'"));
    expect(source, contains("'Operation status'"));

    expect(source, contains('task.workflowState'));
    expect(source, contains('task.operationStatus'));

    expect(source, isNot(contains("'Workflow stage', task.operationStatus")));
  });

  test('task detail exposes useful populated ERP context', () {
    final source = File(
      'lib/features/tasks/presentation/task_detail_screen.dart',
    ).readAsStringSync();

    for (final token in [
      "'Customer'",
      "'Task type'",
      "'Source'",
      "'Progress'",
      "'Expected start'",
      'task.customerName',
      'task.taskType',
      'task.source',
      'task.progress',
      'task.expectedStartDate',
    ]) {
      expect(source, contains(token));
    }
  });
}
