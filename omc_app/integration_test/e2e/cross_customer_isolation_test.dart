import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:omc_app/core/diagnostics/e2e_network_audit.dart';
import 'package:omc_app/main.dart' as app;

import 'robots/auth_robot.dart';
import 'robots/security_regression_robot.dart';
import 'support/e2e_waits.dart';
import 'support/edge_e2e_config.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'different customer cannot see request or internal work surfaces',
    (tester) async {
      final config = EdgeE2eConfig.fromEnvironment();
      E2eNetworkAudit.clear();

      await app.main();
      await tester.pump();

      final waits = E2eWaits(tester);
      final auth = AuthRobot(tester, waits);
      final security = SecurityRegressionRobot(tester, waits);

      await auth.ensureLoggedOut();
      await auth.login(config.otherAuth);
      await security.verifyOtherCustomerIsolation(config);
      await auth.logoutAndVerifyProtection();
    },
  );
}
