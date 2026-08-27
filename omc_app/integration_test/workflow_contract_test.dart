import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:omc_app/app/route_access_policy.dart';
import 'package:omc_app/features/auth/application/auth_state.dart';
import 'package:omc_app/features/service_requests/data/service_case.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'backend workflow projection and role revocation stay authoritative',
    (tester) async {
      const projectedCase = ServiceCase(
        id: 'OMC-SR-2042-0001',
        title: 'Income Tax Return Filing',
        category: 'Tax',
        status: 'Waiting for Customer',
        createdAtLabel: '02 Aug 2026',
        updatedAtLabel: '02 Aug 2026',
        progress: 0.12,
        progressPercent: 65,
        displayStatus: 'Action required',
        currentStage: 'Documents',
        customerActionRequired: true,
        milestones: ['Request received', 'Documents submitted'],
        completionBlockers: ['CNIC copy requires replacement'],
      );

      expect(projectedCase.progressPercent, 65);
      expect(projectedCase.progress, 0.65);
      expect(projectedCase.completionBlockers, hasLength(1));

      const combinedReviewer = AuthCapabilities(
        accessState: AccountAccessState.internal,
        canReviewDocuments: true,
        canReviewPayments: true,
      );
      const afterFinanceRoleRemoval = AuthCapabilities(
        accessState: AccountAccessState.internal,
        canReviewDocuments: true,
      );

      expect(canAccessRoute('/documents', combinedReviewer), isTrue);
      expect(canAccessRoute('/payments', combinedReviewer), isTrue);
      expect(canAccessRoute('/documents', afterFinanceRoleRemoval), isTrue);
      expect(canAccessRoute('/payments', afterFinanceRoleRemoval), isFalse);
    },
  );
}
