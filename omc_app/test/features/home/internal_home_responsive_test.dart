import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/app/theme.dart';
import 'package:omc_app/features/auth/application/auth_state.dart';
import 'package:omc_app/features/home/data/home_dashboard_repository.dart';
import 'package:omc_app/features/home/presentation/internal_home_view.dart';
import 'package:omc_app/features/notifications/data/notifications_repository.dart';

const _capabilities = AuthCapabilities(
  accessState: AccountAccessState.internal,
  canAccessInternalWorkspace: true,
  canManageCustomers: true,
  canManageLeads: true,
  canManageTasks: true,
  canReviewDocuments: true,
  canReviewPayments: true,
);

const _summary = HomeDashboardSummary(
  activeCases: 8,
  completedCases: 4,
  pendingDocuments: 3,
  serviceSnapshots: [
    HomeDashboardServiceSnapshot(
      id: 'SR-RESPONSIVE-1',
      title: 'Corporate tax compliance service',
      status: 'Pending',
      customerName: 'A customer with a deliberately long display name',
      requestState: 'Financial Hold',
      operationalStatus: 'Pending internal review',
      documentSummary: HomeDashboardDocumentSummary.empty(),
      paymentSummary: HomeDashboardPaymentSummary.empty(),
      progress: 0.4,
    ),
  ],
  operationsSummary: HomeDashboardOperationsSummary(
    openLeads: 12,
    activeCustomers: 25,
    pendingTasks: 9,
    pendingPayments: 7,
    documentsWaitingReview: 11,
    activeServices: 14,
    waitingCustomer: 5,
  ),
  recentActivity: [
    HomeDashboardActivity(
      title: 'A deliberately long operational activity title',
      subtitle:
          'A long activity description that should wrap without overflowing.',
      status: 'Pending internal review',
      createdAtLabel: 'A few moments ago',
    ),
  ],
);

void _setView(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 3000);
  tester.view.devicePixelRatio = 1;

  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

Future<void> _pumpHome(
  WidgetTester tester, {
  required double width,
  required double textScale,
}) async {
  _setView(tester, width);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [unreadNotificationsProvider.overrideWith((ref) async => 0)],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) {
          final mediaQuery = MediaQuery.of(context);
          return MediaQuery(
            data: mediaQuery.copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          );
        },
        home: InternalHomeView(
          displayName: 'Internal Operations User',
          avatarUrl: null,
          summary: _summary,
          quickActions: const [],
          capabilities: _capabilities,
          loadMessage: null,
          onRetryHomeLoad: () {},
          onOpenNotifications: () {},
        ),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

void main() {
  testWidgets('internal home does not overflow on a narrow phone', (
    tester,
  ) async {
    await _pumpHome(tester, width: 320, textScale: 1);

    expect(find.text('Needs attention'), findsOneWidget);
    expect(find.text('Review Documents'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('two-column quick actions reflow inside narrow tiles', (
    tester,
  ) async {
    await _pumpHome(tester, width: 380, textScale: 1);

    expect(find.text('Review Documents'), findsOneWidget);
    expect(find.text('Review Payments'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('internal home remains overflow-free at high text scale', (
    tester,
  ) async {
    await _pumpHome(tester, width: 360, textScale: 2);

    expect(find.text('Needs attention'), findsOneWidget);
    expect(find.text('Review Documents'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
