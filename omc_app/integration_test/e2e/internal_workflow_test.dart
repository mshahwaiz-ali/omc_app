import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:omc_app/core/diagnostics/e2e_network_audit.dart';
import 'package:omc_app/main.dart' as app;

import 'robots/auth_robot.dart';
import 'robots/internal_workflow_robot.dart';
import 'support/e2e_waits.dart';
import 'support/internal_e2e_config.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('authorized internal user sees linked ERP Task as read-only', (
    tester,
  ) async {
    final config = InternalE2eConfig.fromEnvironment();
    E2eNetworkAudit.clear();

    await app.main();
    await tester.pump();

    final waits = E2eWaits(tester);
    final auth = AuthRobot(tester, waits);
    final internal = InternalWorkflowRobot(tester, waits);

    await auth.ensureLoggedOut();
    await auth.login(config.authConfig);
    await internal.verifyLinkedTaskIsVisibleAndReadOnly(config);
    await internal.returnToShell();
    await auth.logoutAndVerifyProtection();
  });
}
