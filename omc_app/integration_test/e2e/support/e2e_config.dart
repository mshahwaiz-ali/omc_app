import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/core/diagnostics/e2e_network_audit.dart';

class E2eConfig {
  const E2eConfig({
    required this.username,
    required this.password,
    this.serviceTitle = '',
    this.requestId = '',
  });

  factory E2eConfig.fromEnvironment() {
    const username = String.fromEnvironment('E2E_USERNAME');
    const password = String.fromEnvironment('E2E_PASSWORD');

    _validateBase(username: username, password: password);
    return const E2eConfig(username: username, password: password);
  }

  factory E2eConfig.customerJourney({bool requireRequestId = false}) {
    const username = String.fromEnvironment('E2E_USERNAME');
    const password = String.fromEnvironment('E2E_PASSWORD');
    const serviceTitle = String.fromEnvironment('E2E_SERVICE_TITLE');
    const requestId = String.fromEnvironment('E2E_REQUEST_ID');

    _validateBase(username: username, password: password);
    if (serviceTitle.trim().isEmpty) {
      fail(
        'Customer E2E requires E2E_SERVICE_TITLE for an actual published '
        'service. The journey does not invent or mock catalogue data.',
      );
    }
    if (requireRequestId && requestId.trim().isEmpty) {
      fail(
        'Customer verification E2E requires E2E_REQUEST_ID from the '
        'authorized backend settlement step.',
      );
    }
    return const E2eConfig(
      username: username,
      password: password,
      serviceTitle: serviceTitle,
      requestId: requestId,
    );
  }

  static void _validateBase({
    required String username,
    required String password,
  }) {
    if (username.trim().isEmpty || password.isEmpty) {
      fail(
        'Real Chrome E2E credentials are required. Provide non-empty '
        'E2E_USERNAME and E2E_PASSWORD through --dart-define; the journey '
        'is not skipped or replaced with fake authentication.',
      );
    }
    if (!E2eNetworkAudit.enabled) {
      fail(
        'Real Chrome E2E auditing is disabled. Run with '
        '--dart-define=OMC_E2E_AUDIT=true.',
      );
    }
  }

  final String username;
  final String password;
  final String serviceTitle;
  final String requestId;
}
