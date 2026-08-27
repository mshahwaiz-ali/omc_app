import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/core/diagnostics/omc_widget_keys.dart';

import '../support/e2e_waits.dart';
import '../support/internal_e2e_config.dart';

class InternalWorkflowRobot {
  InternalWorkflowRobot(this.tester, this.waits);

  final WidgetTester tester;
  final E2eWaits waits;

  Future<void> verifyLinkedTaskIsVisibleAndReadOnly(
    InternalE2eConfig config,
  ) async {
    await waits.tapAndWait(
      target: find.byKey(OmcWidgetKeys.navMore),
      destination: find.byKey(OmcWidgetKeys.moreScreen),
      description: 'Internal workflow -> More',
    );

    final tasksAction = find.byKey(OmcWidgetKeys.moreAction('tasks'));
    await waits.waitFor(
      tasksAction,
      description: 'Internal Tasks navigation action',
    );
    await tester.ensureVisible(tasksAction);
    await tester.tap(tasksAction.hitTestable());
    await tester.pump();

    await waits.waitFor(
      find.text('Read-only ERP Task tracking for internal staff.'),
      description: 'Internal Tasks screen',
      timeout: const Duration(seconds: 20),
    );
    await waits.waitForNetworkIdle(description: 'Internal Tasks screen');
    waits.assertHealthy('Internal Tasks screen');

    final search = find.byType(TextField);
    await waits.waitFor(search, description: 'Internal task search');
    await tester.enterText(search.first, config.taskId.trim());
    await tester.pump(const Duration(milliseconds: 650));
    await waits.waitForNetworkIdle(description: 'Filtered internal task list');

    final taskReference = find.text(config.taskId.trim());
    await waits.waitFor(
      taskReference,
      description: 'Linked ERP Task ${config.taskId}',
      timeout: const Duration(seconds: 20),
    );
    await tester.ensureVisible(taskReference.first);
    await tester.tap(taskReference.first.hitTestable());
    await tester.pump();

    await waits.waitFor(
      find.text('Read-only tracking'),
      description: 'Linked ERP Task detail',
      timeout: const Duration(seconds: 20),
    );
    await waits.waitForNetworkIdle(description: 'Linked ERP Task detail');

    expect(
      find.text(config.taskId.trim()),
      findsWidgets,
      reason: 'Task detail must identify the exact ERP Task created by activation.',
    );
    expect(
      find.text('Task updates are managed in ERPNext.'),
      findsOneWidget,
      reason: 'Flutter must preserve ERPNext as task-write authority.',
    );
    expect(
      find.byType(TextFormField),
      findsNothing,
      reason: 'Read-only Task detail must not expose editable form fields.',
    );
    expect(
      find.text('Save'),
      findsNothing,
      reason: 'Read-only Task detail must not expose a save mutation.',
    );
    expect(
      find.text('Complete task'),
      findsNothing,
      reason: 'Task completion must happen through ERPNext, not Flutter.',
    );
    waits.assertHealthy('Linked ERP Task read-only authority');
  }

  Future<void> returnToShell() async {
    for (var attempt = 0; attempt < 3; attempt++) {
      if (find.byKey(OmcWidgetKeys.navHome).evaluate().isNotEmpty) return;
      await tester.pageBack();
      await tester.pump(const Duration(milliseconds: 250));
    }
    await waits.waitFor(
      find.byKey(OmcWidgetKeys.navHome),
      description: 'Return from internal Task detail to protected shell',
    );
  }
}
