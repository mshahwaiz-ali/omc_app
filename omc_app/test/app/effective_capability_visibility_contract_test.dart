import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omc_app/app/providers/effective_capabilities_provider.dart';
import 'package:omc_app/app/theme.dart';
import 'package:omc_app/features/auth/application/auth_state.dart';
import 'package:omc_app/features/service_catalogue/application/service_catalogue_controller.dart';
import 'package:omc_app/features/service_catalogue/data/service_item.dart';
import 'package:omc_app/features/service_catalogue/presentation/service_detail_screen.dart';
import 'package:omc_app/features/tasks/data/task_item.dart';
import 'package:omc_app/features/tasks/data/tasks_repository.dart';
import 'package:omc_app/features/tasks/presentation/task_detail_screen.dart';

const _authorityFiles = <String>[
  'lib/features/leads/presentation/leads_screen.dart',
  'lib/features/tasks/presentation/task_detail_screen.dart',
  'lib/features/service_catalogue/presentation/service_detail_screen_impl.dart',
  'lib/features/service_requests/presentation/service_request_draft_screen.dart',
  'lib/features/payments/presentation/payment_detail_screen.dart',
  'lib/features/support/presentation/support_screen_legacy.dart',
  'lib/features/support/presentation/support_ticket_detail_legacy_screen.dart',
  'lib/features/service_requests/presentation/operational_service_case_detail_screen.dart',
];

final _rawProviderCapabilities = RegExp(
  r'ref\s*\.\s*(?:watch|read)\s*'
  r'\(\s*authControllerProvider\s*\)\s*\.capabilities',
  multiLine: true,
);

final _rawStateCapabilities = RegExp(
  r'\bauthState\s*\.\s*capabilities\b',
  multiLine: true,
);

const _service = ServiceItem(
  id: 'SERVICE-EFFECTIVE-AUTHORITY',
  title: 'Effective Authority Service',
  category: 'Corporate',
  feeLabel: 'PKR 5,000',
  completionTime: '3 days',
  requirements: [],
);

const _task = TaskItem(
  id: 'TASK-EFFECTIVE-AUTHORITY',
  title: 'Review customer service case',
  status: 'Open',
  erpStatus: 'Open',
  operationStatus: 'Pending',
  allowedTransitions: [],
  priority: 'High',
  dueDateLabel: '2026-09-30',
  assignedTo: 'Staff User',
  serviceRequest: 'SR-EFFECTIVE-1',
  canViewLinkedServiceCase: true,
);

void _setView(WidgetTester tester) {
  tester.view.physicalSize = const Size(430, 2000);
  tester.view.devicePixelRatio = 1;

  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

void main() {
  test('live action owners use canonical effective capability authority', () {
    for (final path in _authorityFiles) {
      final source = File(path).readAsStringSync();

      expect(
        source,
        contains('effectiveCapabilitiesProvider'),
        reason: '$path must consume effective capability authority.',
      );

      expect(
        _rawProviderCapabilities.hasMatch(source),
        isFalse,
        reason:
            '$path must not read presentation authority directly from AuthController.',
      );

      expect(
        _rawStateCapabilities.hasMatch(source),
        isFalse,
        reason:
            '$path must not derive presentation authority from authState.capabilities.',
      );
    }
  });

  testWidgets(
    'service detail uses effective assisted-service grant for its primary action',
    (tester) async {
      _setView(tester);

      final router = GoRouter(
        initialLocation: '/service',
        routes: [
          GoRoute(
            path: '/service',
            builder: (context, state) => const ServiceDetailScreen(
              serviceId: 'SERVICE-EFFECTIVE-AUTHORITY',
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            effectiveCapabilitiesProvider.overrideWithValue(
              const AuthCapabilities(
                accessState: AccountAccessState.internal,
                canAccessInternalWorkspace: true,
                canCreateServiceForCustomer: true,
              ),
            ),
            serviceDetailProvider.overrideWith(
              (ref, serviceId) async => const [_service],
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Start for customer'), findsOneWidget);
      expect(find.text('Create account to start'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'task detail uses effective case visibility for linked-case action',
    (tester) async {
      _setView(tester);

      final router = GoRouter(
        initialLocation: '/task',
        routes: [
          GoRoute(
            path: '/task',
            builder: (context, state) =>
                const TaskDetailScreen(taskId: 'TASK-EFFECTIVE-AUTHORITY'),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            effectiveCapabilitiesProvider.overrideWithValue(
              const AuthCapabilities(
                accessState: AccountAccessState.internal,
                canAccessInternalWorkspace: true,
                canViewTasks: true,
                canViewAssignedServiceCases: true,
              ),
            ),
            taskDetailProvider.overrideWith((ref, taskId) async => _task),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(OutlinedButton, 'Open linked service case'),
        findsOneWidget,
      );
      expect(
        find.text(
          'This task does not grant access to open the linked service case.',
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
