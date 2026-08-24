import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/app/navigation/omc_navigation_ia.dart';
import 'package:omc_app/app/route_access_policy.dart';
import 'package:omc_app/features/auth/application/auth_state.dart';

const _features = OmcNavigationFeatureFlags(
  paymentsEnabled: true,
  expenseTrackerEnabled: true,
  knowledgeEnabled: true,
  supportEnabled: true,
);

void main() {
  test('backend can_view_tasks capability is parsed by Flutter', () {
    final capabilities = AuthCapabilities.fromJson({
      'access_state': 'internal',
      'can_access_internal_workspace': true,
      'can_view_tasks': true,
      'can_manage_tasks': false,
      'can_manage_assigned_tasks': false,
    });

    expect(capabilities.isInternal, isTrue);
    expect(capabilities.canViewTasks, isTrue);
    expect(capabilities.canManageTasks, isFalse);
    expect(capabilities.canManageAssignedTasks, isFalse);
  });

  test('read-only internal staff can open task list and detail routes', () {
    final capabilities = AuthCapabilities.fromJson({
      'access_state': 'internal',
      'can_access_internal_workspace': true,
      'can_view_tasks': true,
    });

    expect(canAccessRoute('/tasks', capabilities), isTrue);
    expect(canAccessRoute('/tasks/TASK-2026-02832', capabilities), isTrue);
  });

  test('task tracking appears in More for read-only internal staff', () {
    final capabilities = AuthCapabilities.fromJson({
      'access_state': 'internal',
      'can_access_internal_workspace': true,
      'can_view_tasks': true,
    });

    final groups = buildOmcMoreNavigation(
      capabilities: capabilities,
      features: _features,
      isGuest: false,
    );

    final tasks = groups
        .expand((group) => group.items)
        .where((item) => item.id == OmcNavigationActionId.tasks)
        .toList();

    expect(tasks, hasLength(1));
    expect(tasks.single.label, 'Tasks');
  });

  test('customer cannot access internal task tracking', () {
    final customer = AuthCapabilities.fromJson({
      'access_state': 'approved',
      'can_access_internal_workspace': false,
      'can_view_tasks': false,
    });

    expect(canAccessRoute('/tasks', customer), isFalse);
    expect(canAccessRoute('/tasks/TASK-1', customer), isFalse);
  });
}
