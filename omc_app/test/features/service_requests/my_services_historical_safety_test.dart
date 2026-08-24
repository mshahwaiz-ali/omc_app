import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/app/providers/effective_capabilities_provider.dart';
import 'package:omc_app/features/auth/application/auth_state.dart';
import 'package:omc_app/features/service_requests/data/service_case.dart';
import 'package:omc_app/features/service_requests/data/service_case_repository.dart';
import 'package:omc_app/features/service_requests/presentation/my_services_screen.dart';

void main() {
  testWidgets('historical service never exposes live customer action CTA', (
    tester,
  ) async {
    const historicalCase = ServiceCase(
      id: 'HIST-SAFETY-1',
      title: 'Legacy tax filing',
      category: 'Tax',
      status: 'Historical',
      requestState: 'Historical',
      operationalStatus: 'Historical',
      displayStatus: 'Historical',
      createdAtLabel: '2025',
      updatedAtLabel: '2025',
      progress: 0,
      customerActionRequired: true,
      missingDocuments: ['CNIC'],
      missingDocumentsCount: 1,
      paymentEligible: true,
      receipt: ServiceCaseReceipt(status: 'Rejected'),
      paymentDetails: [
        ServiceCasePayment(
          id: 'PAY-LEGACY-1',
          title: 'Legacy payment',
          status: 'Rejected',
          amount: 1000,
          currency: 'PKR',
        ),
      ],
      nextStep: 'Upload documents',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          serviceCasesProvider.overrideWith(
            (ref) async => const [historicalCase],
          ),
          effectiveCapabilitiesProvider.overrideWithValue(
            const AuthCapabilities(
              accessState: AccountAccessState.approved,
              canTrackRequests: true,
              canUploadDocuments: true,
            ),
          ),
        ],
        child: const MaterialApp(home: MyServicesScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Historical'), findsOneWidget);
    expect(find.text('Action needed'), findsNothing);

    expect(find.widgetWithText(TextButton, 'Upload documents'), findsNothing);
    expect(find.widgetWithText(TextButton, 'View details'), findsOneWidget);
  });
}
