import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omc_app/features/auth/application/auth_controller.dart';
import 'package:omc_app/features/auth/application/auth_state.dart';
import 'package:omc_app/features/service_requests/data/service_case.dart';
import 'package:omc_app/features/service_requests/data/service_case_repository.dart';
import 'package:omc_app/features/service_requests/presentation/service_case_detail_legacy_screen.dart';

class _CustomerAuthController extends AuthController {
  @override
  AuthState build() {
    return const AuthState.authenticated(
      userId: 'customer@example.com',
      capabilities: AuthCapabilities(
        accessState: AccountAccessState.approved,
        canTrackRequests: true,
        canUploadDocuments: true,
        canViewDocuments: true,
        canViewPayments: true,
      ),
    );
  }
}

Widget _appFor(ServiceCase serviceCase) {
  final router = GoRouter(
    initialLocation: '/detail',
    routes: [
      GoRoute(
        path: '/detail',
        builder: (context, state) =>
            ServiceCaseDetailScreen(caseId: serviceCase.id),
      ),
      GoRoute(
        path: '/payments/:paymentId',
        builder: (context, state) =>
            const Scaffold(body: Text('Payment detail')),
      ),
      GoRoute(
        path: '/documents',
        builder: (context, state) => const Scaffold(body: Text('Documents')),
      ),
    ],
  );

  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(_CustomerAuthController.new),
      serviceCaseDetailProvider.overrideWith(
        (ref, caseId) async => serviceCase,
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('historical detail suppresses upload and cancellation actions', (
    tester,
  ) async {
    const serviceCase = ServiceCase(
      id: 'HIST-DETAIL-UPLOAD',
      title: 'Legacy tax filing',
      category: 'Tax',
      status: 'Historical',
      requestState: 'Historical',
      operationalStatus: 'Historical',
      displayStatus: 'Historical',
      createdAtLabel: '2025',
      updatedAtLabel: '2025',
      progress: 0,
      canCancel: true,
      customerActionRequired: true,
      missingDocuments: ['CNIC'],
      missingDocumentsCount: 1,
      documentDetails: [
        ServiceCaseDocument(
          id: 'DOC-LEGACY-1',
          title: 'CNIC',
          type: 'CNIC',
          status: 'Missing',
        ),
      ],
      nextStep: 'Upload documents',
    );

    await tester.pumpWidget(_appFor(serviceCase));
    await tester.pumpAndSettle();

    expect(find.text('Historical service record'), findsOneWidget);

    expect(find.widgetWithText(FilledButton, 'Upload documents'), findsNothing);
    expect(
      find.widgetWithText(FilledButton, 'Upload corrected documents'),
      findsNothing,
    );
    expect(find.text('Cancel request'), findsNothing);
  });

  testWidgets('historical detail suppresses payment action', (tester) async {
    const serviceCase = ServiceCase(
      id: 'HIST-DETAIL-PAYMENT',
      title: 'Legacy company service',
      category: 'Corporate',
      status: 'Historical',
      requestState: 'Historical',
      operationalStatus: 'Historical',
      displayStatus: 'Historical',
      createdAtLabel: '2025',
      updatedAtLabel: '2025',
      progress: 0,
      paymentEligible: true,
      paymentId: 'PAY-HIST-1',
      paymentDetails: [
        ServiceCasePayment(
          id: 'PAY-HIST-1',
          title: 'Legacy payment',
          status: 'Open',
          amount: 5000,
          currency: 'PKR',
        ),
      ],
    );

    await tester.pumpWidget(_appFor(serviceCase));
    await tester.pumpAndSettle();

    expect(find.text('Historical service record'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'View payments'), findsNothing);
    expect(find.text('Ready for payment'), findsNothing);
    expect(find.text('Payment is ready'), findsNothing);
  });
}
