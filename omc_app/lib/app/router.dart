import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/feature_placeholder_screen.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/application/auth_state.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/signup_screen.dart';
import '../features/documents/presentation/documents_screen.dart';
import '../features/internal_workspace/presentation/internal_workspace_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/payments/presentation/payments_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/service_catalogue/presentation/service_detail_screen.dart';
import '../features/service_requests/presentation/service_request_draft_screen.dart';
import '../features/service_requests/presentation/service_case_detail_screen.dart';
import '../features/service_requests/presentation/my_services_screen.dart';
import '../features/splash/presentation/splash_screen.dart';
import 'main_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final location = state.matchedLocation;

      final isSplash = location == '/';
      final isAuthRoute = location == '/login' || location == '/signup';

      if (authState.status == AuthStatus.checking) {
        return isSplash ? null : '/';
      }

      if (authState.status == AuthStatus.unauthenticated) {
        return isAuthRoute || isSplash ? null : '/login';
      }

      if (authState.status == AuthStatus.authenticated) {
        return isAuthRoute || isSplash ? '/home' : null;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/signup',
        name: 'signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const MainShell(),
      ),
      GoRoute(
        path: '/services/:serviceId',
        name: 'service-detail',
        builder: (context, state) {
          final serviceId = Uri.decodeComponent(
            state.pathParameters['serviceId'] ?? '',
          );

          return ServiceDetailScreen(serviceId: serviceId);
        },
      ),
      GoRoute(
        path: '/services/:serviceId/request',
        name: 'service-request-draft',
        builder: (context, state) {
          final serviceId = Uri.decodeComponent(
            state.pathParameters['serviceId'] ?? '',
          );

          return ServiceRequestDraftScreen(serviceId: serviceId);
        },
      ),
      GoRoute(
        path: '/my-services',
        name: 'my-services',
        builder: (context, state) => const MyServicesScreen(),
      ),
      GoRoute(
        path: '/documents',
        name: 'documents',
        builder: (context, state) => const DocumentsScreen(),
      ),
      GoRoute(
        path: '/payments',
        name: 'payments',
        builder: (context, state) => const PaymentsScreen(),
      ),
      GoRoute(
        path: '/leads',
        name: 'leads',
        builder: (context, state) => const FeaturePlaceholderScreen(
          title: 'Leads',
          message:
              'Lead pipeline, follow-ups, and opportunities will appear here.',
          icon: Icons.trending_up_rounded,
        ),
      ),
      GoRoute(
        path: '/customers',
        name: 'customers',
        builder: (context, state) => const FeaturePlaceholderScreen(
          title: 'Customers',
          message:
              'Customer records, activity, and service history will appear here.',
          icon: Icons.groups_2_rounded,
        ),
      ),
      GoRoute(
        path: '/tasks',
        name: 'tasks',
        builder: (context, state) => const FeaturePlaceholderScreen(
          title: 'Tasks',
          message:
              'Assigned work, reminders, and pending actions will appear here.',
          icon: Icons.task_alt_rounded,
        ),
      ),
      GoRoute(
        path: '/my-services/:caseId',
        name: 'service-case-detail',
        builder: (context, state) {
          final caseId = Uri.decodeComponent(
            state.pathParameters['caseId'] ?? '',
          );

          return ServiceCaseDetailScreen(caseId: caseId);
        },
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/internal-workspace',
        name: 'internal-workspace',
        builder: (context, state) => const InternalWorkspaceScreen(),
      ),
    ],
  );
});
