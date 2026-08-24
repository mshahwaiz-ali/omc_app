import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/features/tasks/data/task_item.dart';

void main() {
  test(
    'task model treats ERP status as primary and fails closed for writes',
    () {
      final task = TaskItem.fromJson({
        'name': 'TASK-1',
        'subject': 'ERP tracking task',
        'status': 'Working',
        'erp_status': 'Working',
        'display_status': 'Pending at QC',
        'operation_status': 'Pending at QC',
        'allowed_transitions': [
          {'value': 'Submitted by QC', 'label': 'Complete'},
        ],
        // Even a stale/legacy server response must never re-enable
        // mobile Task mutations.
        'can_manage_tasks': true,
        'can_manage_assigned_tasks': true,
      });

      expect(task.status, 'Working');
      expect(task.erpStatus, 'Working');
      expect(task.operationStatus, 'Pending at QC');

      expect(task.allowedTransitions, isEmpty);
      expect(task.serverCanManageTasks, isFalse);
      expect(task.serverCanManageAssignedTasks, isFalse);
    },
  );

  test(
    'repository uses bounded server pagination and exposes no write API',
    () {
      final source = File(
        'lib/features/tasks/data/tasks_repository.dart',
      ).readAsStringSync();

      expect(source, contains('class TaskPage'));
      expect(source, contains('fetchTasksPage'));
      expect(source, isNot(contains('while (true)')));

      expect(source, contains("'limit_start'"));
      expect(source, contains("'page_length'"));
      expect(source, contains("'search'"));
      expect(source, contains("'status'"));
      expect(source, contains("'priority'"));

      expect(source, isNot(contains('postMethod(')));
      expect(source, isNot(contains('updateTaskStatus')));
      expect(source, isNot(contains('reassignTask')));
      expect(source, isNot(contains('updateTaskPlan')));
      expect(source, isNot(contains('fetchTaskAssigneeOptions')));
    },
  );

  test('task list uses real ERP states and server-side paging', () {
    final source = File(
      'lib/features/tasks/presentation/tasks_screen.dart',
    ).readAsStringSync();

    for (final status in [
      'Open',
      'Working',
      'Overdue',
      'Completed',
      'Cancelled',
    ]) {
      expect(source, contains("'$status'"));
    }

    expect(source, isNot(contains("'In Progress'")));
    expect(source, contains('fetchTasksPage'));
    expect(source, contains('Load more'));
  });

  test('task detail is tracking-only with no mobile mutation controls', () {
    final source = File(
      'lib/features/tasks/presentation/task_detail_screen.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('updateTaskStatus')));
    expect(source, isNot(contains('fetchTaskAssigneeOptions')));
    expect(source, isNot(contains('reassignTask')));
    expect(source, isNot(contains('updateTaskPlan')));

    expect(source, isNot(contains("'Reassign'")));
    expect(source, isNot(contains("'Manage task'")));
    expect(source, isNot(contains("'Plan task'")));

    expect(source, contains('Read-only'));
    expect(source, contains('canViewAnyServiceCase'));
  });
}
