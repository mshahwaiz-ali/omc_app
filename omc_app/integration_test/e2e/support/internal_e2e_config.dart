import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/core/diagnostics/e2e_network_audit.dart';

import 'e2e_config.dart';

class InternalE2eConfig {
  const InternalE2eConfig({
    required this.username,
    required this.password,
    required this.taskId,
    required this.requestId,
  });

  factory InternalE2eConfig.fromEnvironment() {
    const username = String.fromEnvironment('E2E_INTERNAL_USERNAME');
    const password = String.fromEnvironment('E2E_INTERNAL_PASSWORD');
    const taskId = String.fromEnvironment('E2E_TASK_ID');
    const requestId = String.fromEnvironment('E2E_REQUEST_ID');

    if (username.trim().isEmpty || password.isEmpty) {
      fail(
        'Internal E2E requires E2E_INTERNAL_USERNAME and '
        'E2E_INTERNAL_PASSWORD for a real authorized staff persona.',
      );
    }
    if (taskId.trim().isEmpty || requestId.trim().isEmpty) {
      fail(
        'Internal E2E requires E2E_TASK_ID and E2E_REQUEST_ID from the '
        'guarded backend preflight.',
      );
    }
    if (!E2eNetworkAudit.enabled) {
      fail(
        'Internal E2E auditing is disabled. Run with '
        '--dart-define=OMC_E2E_AUDIT=true.',
      );
    }

    return const InternalE2eConfig(
      username: username,
      password: password,
      taskId: taskId,
      requestId: requestId,
    );
  }

  E2eConfig get authConfig => E2eConfig(
    username: username,
    password: password,
    requestId: requestId,
  );

  final String username;
  final String password;
  final String taskId;
  final String requestId;
}
