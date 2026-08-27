import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:omc_app/core/diagnostics/e2e_network_audit.dart';
import 'package:omc_app/main.dart' as app;

import 'robots/auth_robot.dart';
import 'robots/navigation_robot.dart';
import 'support/e2e_config.dart';
import 'support/e2e_waits.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('real customer login, navigation and logout smoke journey', (
    tester,
  ) async {
    final config = E2eConfig.fromEnvironment();
    E2eNetworkAudit.clear();

    await app.main();
    await tester.pump();

    final waits = E2eWaits(tester);
    final auth = AuthRobot(tester, waits);
    final navigation = NavigationRobot(tester, waits);

    await auth.ensureLoggedOut();
    await auth.login(config);
    await navigation.smokePrimaryNavigation();
    await navigation.smokeMoreDestinations();
    await auth.logoutAndVerifyProtection();
  });
}
