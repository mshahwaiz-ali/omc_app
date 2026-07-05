import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/application/auth_state.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/signup_screen.dart';
import '../features/documents/presentation/document_detail_screen.dart';
import '../features/documents/presentation/documents_screen.dart';
import '../features/internal_workspace/presentation/internal_workspace_screen.dart';
import '../features/tasks/presentation/task_detail_screen.dart';
import '../features/tasks/presentation/tasks_screen.dart';
import '../features/customers/presentation/customer_detail_screen.dart';
import '../features/customers/presentation/customers_screen.dart';
import '../features/leads/presentation/lead_detail_screen.dart';
import '../features/leads/presentation/leads_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/payments/presentation/payment_detail_screen.dart';
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
        path: '/documents/:documentId',
        name: 'document-detail',
        builder: (context, state) {
          final documentId = Uri.decodeComponent(
            state.pathParameters['documentId'] ?? '',
          );

          return DocumentDetailScreen(documentId: documentId);
        },
      ),
      GoRoute(
        path: '/payments',
        name: 'payments',
        builder: (context, state) => const PaymentsScreen(),
      ),
      GoRoute(
        path: '/payments/:paymentId',
        name: 'payment-detail',
        builder: (context, state) {
          final paymentId = Uri.decodeComponent(
            state.pathParameters['paymentId'] ?? '',
          );

          return PaymentDetailScreen(paymentId: paymentId);
        },
      ),
      GoRoute(
        path: '/leads',
        name: 'leads',
        builder: (context, state) => const LeadsScreen(),
      ),
      GoRoute(
        path: '/customers',
        name: 'customers',
        builder: (context, state) => const CustomersScreen(),
      ),
      GoRoute(
        path: '/tasks',
        name: 'tasks',
        builder: (context, state) => const TasksScreen(),
      ),

      GoRoute(
        path: '/leads/:leadId',
        name: 'lead-detail',
        builder: (context, state) {
          final leadId = Uri.decodeComponent(
            state.pathParameters['leadId'] ?? '',
          );

          return LeadDetailScreen(leadId: leadId);
        },
      ),
      GoRoute(
        path: '/customers/:customerId',
        name: 'customer-detail',
        builder: (context, state) {
          final customerId = Uri.decodeComponent(
            state.pathParameters['customerId'] ?? '',
          );

          return CustomerDetailScreen(customerId: customerId);
        },
      ),
      GoRoute(
        path: '/tasks/:taskId',
        name: 'task-detail',
        builder: (context, state) {
          final taskId = Uri.decodeComponent(
            state.pathParameters['taskId'] ?? '',
          );

          return TaskDetailScreen(taskId: taskId);
        },
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
