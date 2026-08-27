import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/features/tasks/data/task_item.dart';

void main() {
  test('display workflow state never becomes canonical ERP status', () {
    final task = TaskItem.fromJson({
      'name': 'TASK-1',
      'display_status': 'Pending at QC',
      'operation_status': 'Pending at QC',
    });

    expect(task.erpStatus, 'Open');
    expect(task.status, 'Open');
    expect(task.operationStatus, 'Pending at QC');
  });

  test('linked service case visibility is server authoritative', () {
    final model = File(
      'lib/features/tasks/data/task_item.dart',
    ).readAsStringSync();

    final detail = File(
      'lib/features/tasks/presentation/task_detail_screen.dart',
    ).readAsStringSync();

    expect(model, contains('canViewLinkedServiceCase'));
    expect(model, contains("json['can_view_linked_service_case']"));
    expect(detail, contains('task.canViewLinkedServiceCase'));
  });

  test('task linked case opens canonical exact-detail route', () {
    final detail = File(
      'lib/features/tasks/presentation/task_detail_screen.dart',
    ).readAsStringSync();

    final policy = File('lib/app/route_access_policy.dart').readAsStringSync();

    expect(detail, contains("'/my-services/"));
    expect(detail, isNot(contains("'/internal-workspace/service-cases/'")));

    expect(policy, contains("if (location == '/my-services')"));
    expect(policy, contains("if (location.startsWith('/my-services/'))"));
    expect(
      policy,
      contains(
        'return capabilities.canTrackRequests || '
        'capabilities.canViewAnyServiceCase;',
      ),
    );
  });

  test('large task collection uses lazy widget construction', () {
    final screen = File(
      'lib/features/tasks/presentation/tasks_screen.dart',
    ).readAsStringSync();

    expect(screen, anyOf(contains('SliverList'), contains('ListView.builder')));

    expect(screen, isNot(contains('for (final task in tasks)')));
  });
}
