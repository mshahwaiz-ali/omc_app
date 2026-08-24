import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/features/auth/application/auth_state.dart';
import 'package:omc_app/features/internal_workspace/application/internal_workspace_focus.dart';

void main() {
  test(
    'task-only internal staff see Tasks without gaining service-case scope',
    () {
      const capabilities = AuthCapabilities(
        accessState: AccountAccessState.internal,
        canAccessInternalWorkspace: true,
        canViewTasks: true,
      );

      final focus = InternalWorkspaceFocus.fromCapabilities(capabilities);

      expect(focus.canShowTasks, isTrue);
      expect(focus.canShowServiceCases, isFalse);
    },
  );

  test('workspace does not unconditionally fetch the service-case queue', () {
    final source = File(
      'lib/features/internal_workspace/presentation/'
      'internal_workspace_screen.dart',
    ).readAsStringSync();

    expect(
      source,
      isNot(
        contains('final queueAsync = ref.watch(internalServiceCasesProvider);'),
      ),
    );

    expect(source, contains('final queueAsync = focus.canShowServiceCases'));
  });
}
