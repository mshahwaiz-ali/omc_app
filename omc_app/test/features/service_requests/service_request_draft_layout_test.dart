import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:omc_app/app/providers/effective_capabilities_provider.dart';
import 'package:omc_app/app/theme.dart';
import 'package:omc_app/core/widgets/omc_premium.dart';
import 'package:omc_app/features/auth/application/auth_state.dart';
import 'package:omc_app/features/profile/data/profile_repository.dart';
import 'package:omc_app/features/service_catalogue/application/service_catalogue_controller.dart';
import 'package:omc_app/features/service_catalogue/data/service_item.dart';
import 'package:omc_app/features/service_requests/presentation/service_request_draft_screen.dart';

const _service = ServiceItem(
  id: 'SERVICE-DRAFT-LAYOUT',
  title: 'Business Registration',
  category: 'Corporate',
  feeLabel: 'PKR 5,000',
  completionTime: '3 days',
  requirements: [],
);

void main() {
  testWidgets(
    'submit bar shrink-wraps and leaves request form viewport usable',
    (tester) async {
      tester.view.physicalSize = const Size(430, 631);
      tester.view.devicePixelRatio = 1;

      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final router = GoRouter(
        initialLocation: '/request',
        routes: [
          GoRoute(
            path: '/request',
            builder: (context, state) => const ServiceRequestDraftScreen(
              serviceId: 'SERVICE-DRAFT-LAYOUT',
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
                accessState: AccountAccessState.approved,
                canCreateServiceRequest: true,
                canTrackRequests: true,
              ),
            ),
            profileSummaryProvider.overrideWith((ref) async => null),
            serviceRequestTemplateProvider.overrideWith(
              (ref, id) async => const [_service],
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.lightTheme,
            routerConfig: router,
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Start Request'), findsOneWidget);
      expect(find.text('Selected service'), findsOneWidget);
      expect(find.text('Contact details'), findsOneWidget);
      expect(find.text('Submit request'), findsOneWidget);

      final formPage = find.byType(OmcPageListView);
      expect(formPage, findsOneWidget);

      final formSize = tester.getSize(formPage);
      final submitRect = tester.getRect(find.text('Submit request'));

      // Regression: the sticky bottom bar must not consume the whole Scaffold.
      expect(formSize.height, greaterThan(300));
      expect(submitRect.center.dy, greaterThan(450));
      expect(submitRect.bottom, lessThanOrEqualTo(631));

      expect(tester.takeException(), isNull);
    },
  );
}
