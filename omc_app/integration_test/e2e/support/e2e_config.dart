import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/core/diagnostics/e2e_network_audit.dart';

class E2eConfig {
  const E2eConfig({required this.username, required this.password});

  factory E2eConfig.fromEnvironment() {
    const username = String.fromEnvironment('E2E_USERNAME');
    const password = String.fromEnvironment('E2E_PASSWORD');

    if (username.trim().isEmpty || password.isEmpty) {
      fail(
        'Real Chrome E2E credentials are required. Provide non-empty '
        'E2E_USERNAME and E2E_PASSWORD through --dart-define; the smoke '
        'journey is not skipped or replaced with fake authentication.',
      );
    }
    if (!E2eNetworkAudit.enabled) {
      fail(
        'Real Chrome E2E auditing is disabled. Run with '
        '--dart-define=OMC_E2E_AUDIT=true.',
      );
    }

    return const E2eConfig(username: username, password: password);
  }

  final String username;
  final String password;
}
