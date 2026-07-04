import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/feature_placeholder_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/signup_screen.dart';
import '../features/service_catalogue/presentation/service_detail_screen.dart';
import '../features/service_requests/presentation/service_request_draft_screen.dart';
import '../features/splash/presentation/splash_screen.dart';
import 'main_shell.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
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
      path: '/notifications',
      name: 'notifications',
      builder: (context, state) => const FeaturePlaceholderScreen(
        title: 'Notifications',
        message:
            'Service updates, document requests and tax alerts appear here.',
        icon: Icons.notifications_none_rounded,
      ),
    ),
    GoRoute(
      path: '/profile',
      name: 'profile',
      builder: (context, state) => const FeaturePlaceholderScreen(
        title: 'Profile',
        message: 'Personal information and account preferences appear here.',
        icon: Icons.person_outline_rounded,
      ),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      builder: (context, state) => const FeaturePlaceholderScreen(
        title: 'Settings',
        message: 'Theme, notification and app preferences appear here.',
        icon: Icons.settings_outlined,
      ),
    ),
    GoRoute(
      path: '/internal-workspace',
      name: 'internal-workspace',
      builder: (context, state) => const FeaturePlaceholderScreen(
        title: 'Internal Workspace',
        message: 'Leads, customers, tasks and payments appear here.',
        icon: Icons.admin_panel_settings_outlined,
      ),
    ),
  ],
);
