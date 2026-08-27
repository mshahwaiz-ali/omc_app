import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/core/diagnostics/e2e_network_audit.dart';

import 'e2e_config.dart';

class EdgeE2eConfig {
  const EdgeE2eConfig({
    required this.primaryUsername,
    required this.primaryPassword,
    required this.otherUsername,
    required this.otherPassword,
    required this.invalidPassword,
    required this.requestId,
    required this.taskId,
  });

  factory EdgeE2eConfig.fromEnvironment() {
    const primaryUsername = String.fromEnvironment('E2E_USERNAME');
    const primaryPassword = String.fromEnvironment('E2E_PASSWORD');
    const otherUsername = String.fromEnvironment('E2E_OTHER_USERNAME');
    const otherPassword = String.fromEnvironment('E2E_OTHER_PASSWORD');
    const invalidPassword = String.fromEnvironment(
      'E2E_INVALID_PASSWORD',
      defaultValue: '__OMC_E2E_INTENTIONALLY_INVALID_PASSWORD__',
    );
    const requestId = String.fromEnvironment('E2E_REQUEST_ID');
    const taskId = String.fromEnvironment('E2E_TASK_ID');

    if (primaryUsername.trim().isEmpty || primaryPassword.isEmpty) {
      fail('Phase 4 requires E2E_USERNAME and E2E_PASSWORD.');
    }
    if (otherUsername.trim().isEmpty || otherPassword.isEmpty) {
      fail(
        'Phase 4 requires E2E_OTHER_USERNAME and E2E_OTHER_PASSWORD for a '
        'different approved customer.',
      );
    }
    if (primaryUsername.trim().toLowerCase() ==
        otherUsername.trim().toLowerCase()) {
      fail('E2E_OTHER_USERNAME must identify a different customer.');
    }
    if (invalidPassword.isEmpty || invalidPassword == primaryPassword) {
      fail(
        'E2E_INVALID_PASSWORD must be non-empty and different from the real password.',
      );
    }
    if (requestId.trim().isEmpty || taskId.trim().isEmpty) {
      fail('Phase 4 requires request/task markers from its backend preflight.');
    }
    if (!E2eNetworkAudit.enabled) {
      fail('Phase 4 requires --dart-define=OMC_E2E_AUDIT=true.');
    }

    return const EdgeE2eConfig(
      primaryUsername: primaryUsername,
      primaryPassword: primaryPassword,
      otherUsername: otherUsername,
      otherPassword: otherPassword,
      invalidPassword: invalidPassword,
      requestId: requestId,
      taskId: taskId,
    );
  }

  E2eConfig get primaryAuth => E2eConfig(
    username: primaryUsername,
    password: primaryPassword,
    requestId: requestId,
  );

  E2eConfig get otherAuth => E2eConfig(
    username: otherUsername,
    password: otherPassword,
    requestId: requestId,
  );

  final String primaryUsername;
  final String primaryPassword;
  final String otherUsername;
  final String otherPassword;
  final String invalidPassword;
  final String requestId;
  final String taskId;
}
