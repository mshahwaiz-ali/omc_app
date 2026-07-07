import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/application/auth_state.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/signup_screen.dart';
import '../features/documents/presentation/document_detail_screen.dart';
import '../features/expense_tracker/presentation/expense_tracker_screen.dart';
import '../features/internal_workspace/presentation/internal_workspace_screen.dart';
import '../features/knowledge/presentation/knowledge_detail_screen.dart';
import '../features/knowledge/presentation/knowledge_screen.dart';
import '../features/tasks/presentation/task_detail_screen.dart';
import '../features/tasks/presentation/tasks_screen.dart';
import '../features/customers/presentation/customer_detail_screen.dart';
import '../features/customers/presentation/customers_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/leads/presentation/lead_detail_screen.dart';
import '../features/leads/presentation/leads_screen.dart';
import '../features/notifications/presentation/notification_detail_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/payments/presentation/payment_detail_screen.dart';
import '../features/payments/presentation/payments_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/service_catalogue/presentation/service_detail_screen.dart';
import '../features/service_requests/presentation/service_request_draft_screen.dart';
import '../features/service_requests/presentation/service_case_detail_screen.dart';
import '../features/support/presentation/support_screen.dart';
import '../features/support/presentation/support_ticket_detail_screen.dart';
import '../features/tax_calculator/presentation/tax_calculator_screen.dart';
import '../features/splash/presentation/splash_screen.dart';
import 'main_shell.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final routerRefreshNotifier = _RouterRefreshNotifier(ref);
  ref.onDispose(routerRefreshNotifier.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: routerRefreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
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
        path: '/services',
        name: 'services',
        builder: (context, state) => const MainShell(initialIndex: 1),
      ),
      GoRoute(
        path: '/track',
        name: 'track',
        builder: (context, state) => const MainShell(initialIndex: 2),
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
        builder: (context, state) => const MainShell(initialIndex: 2),
      ),
      GoRoute(
        path: '/dashboard',
        name: 'dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/documents',
        name: 'documents',
        builder: (context, state) => const MainShell(initialIndex: 3),
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
        path: '/knowledge',
        name: 'knowledge',
        builder: (context, state) => const KnowledgeScreen(),
      ),
      GoRoute(
        path: '/knowledge/:articleId',
        name: 'knowledge-detail',
        builder: (context, state) {
          final articleId = Uri.decodeComponent(
            state.pathParameters['articleId'] ?? '',
          );

          return KnowledgeDetailScreen(articleId: articleId);
        },
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/notifications/:notificationId',
        name: 'notification-detail',
        builder: (context, state) {
          final notificationId = Uri.decodeComponent(
            state.pathParameters['notificationId'] ?? '',
          );

          return NotificationDetailScreen(notificationId: notificationId);
        },
      ),
      GoRoute(
        path: '/support',
        name: 'support',
        builder: (context, state) => const SupportScreen(),
      ),
      GoRoute(
        path: '/tax-calculator',
        name: 'tax-calculator',
        builder: (context, state) => const TaxCalculatorScreen(),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/expense-tracker',
        name: 'expense-tracker',
        builder: (context, state) => const ExpenseTrackerScreen(),
      ),
      GoRoute(
        path: '/support-tickets/:ticketId',
        name: 'support-ticket-detail',
        builder: (context, state) {
          final ticketId = Uri.decodeComponent(
            state.pathParameters['ticketId'] ?? '',
          );

          return SupportTicketDetailScreen(ticketId: ticketId);
        },
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

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(this._ref) {
    _subscription = _ref.listen<AuthState>(
      authControllerProvider,
      (_, _) => notifyListeners(),
    );
  }

  final Ref _ref;
  late final ProviderSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}
