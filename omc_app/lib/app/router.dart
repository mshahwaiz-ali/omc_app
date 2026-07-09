import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/application/auth_controller.dart';
import '../features/auth/application/auth_state.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/signup_screen.dart';
import '../features/auth/presentation/under_review_screen.dart';
import '../features/customers/presentation/customer_detail_screen.dart';
import '../features/customers/presentation/customers_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/documents/presentation/document_detail_screen.dart';
import '../features/expense_tracker/presentation/expense_tracker_screen.dart';
import '../features/internal_workspace/presentation/internal_service_cases_screen.dart';
import '../features/internal_workspace/presentation/internal_workspace_screen.dart';
import '../features/knowledge/presentation/knowledge_detail_screen.dart';
import '../features/knowledge/presentation/knowledge_screen.dart';
import '../features/leads/presentation/lead_detail_screen.dart';
import '../features/leads/presentation/leads_screen.dart';
import '../features/notifications/presentation/notification_detail_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/payments/presentation/payment_detail_screen.dart';
import '../features/payments/presentation/payments_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/service_catalogue/presentation/service_detail_screen.dart';
import '../features/service_requests/presentation/service_case_detail_screen.dart';
import '../features/service_requests/presentation/service_request_draft_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/splash/presentation/splash_screen.dart';
import '../features/support/presentation/support_screen.dart';
import '../features/support/presentation/support_ticket_detail_screen.dart';
import '../features/tasks/presentation/task_detail_screen.dart';
import '../features/tasks/presentation/tasks_screen.dart';
import '../features/tax_calculator/presentation/tax_calculation_history_screen.dart';
import '../features/tax_calculator/presentation/tax_calculator_screen.dart';
import 'main_shell.dart';
import 'shell_nav_scaffold.dart';

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
      final isUnderReviewRoute = location == '/under-review';

      if (authState.status == AuthStatus.checking) {
        return isSplash ? null : '/';
      }

      if (authState.status == AuthStatus.unauthenticated) {
        return isAuthRoute || isSplash ? null : '/login';
      }

      if (authState.status == AuthStatus.guest) {
        if (isSplash) return '/home';
        if (isAuthRoute) return null;
        return _isGuestAllowedRoute(location) ? null : '/home';
      }

      if (authState.status == AuthStatus.authenticated) {
        if (isAuthRoute || isSplash) return '/home';
        if (isUnderReviewRoute) {
          return authState.capabilities.isPending ? null : '/home';
        }

        final canAccessRoute = _canAccessRoute(location, authState.capabilities);
        if (canAccessRoute) return null;

        return authState.capabilities.isPending ? '/under-review' : '/home';
      }

      return null;
    },
    routes: [
      GoRoute(path: '/', name: 'splash', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', name: 'login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/signup', name: 'signup', builder: (context, state) => const SignupScreen()),
      GoRoute(path: '/under-review', name: 'under-review', builder: (context, state) => const UnderReviewScreen()),
      GoRoute(path: '/home', name: 'home', builder: (context, state) => const MainShell()),
      GoRoute(path: '/services', name: 'services', builder: (context, state) => const MainShell(initialIndex: 1)),
      GoRoute(path: '/track', name: 'track', builder: (context, state) => const MainShell(initialIndex: 2)),
      GoRoute(path: '/more', name: 'more', builder: (context, state) => const MainShell(initialIndex: 4)),
      GoRoute(
        path: '/services/:serviceId',
        name: 'service-detail',
        builder: (context, state) {
          final serviceId = Uri.decodeComponent(state.pathParameters['serviceId'] ?? '');
          return _withShell(ShellNavScaffold.servicesIndex, ServiceDetailScreen(serviceId: serviceId));
        },
      ),
      GoRoute(
        path: '/services/:serviceId/request',
        name: 'service-request-draft',
        builder: (context, state) {
          final serviceId = Uri.decodeComponent(state.pathParameters['serviceId'] ?? '');
          return _withShell(ShellNavScaffold.servicesIndex, ServiceRequestDraftScreen(serviceId: serviceId));
        },
      ),
      GoRoute(path: '/my-services', name: 'my-services', builder: (context, state) => const MainShell(initialIndex: 2)),
      GoRoute(path: '/dashboard', name: 'dashboard', builder: (context, state) => _withShell(ShellNavScaffold.moreIndex, const DashboardScreen())),
      GoRoute(path: '/documents', name: 'documents', builder: (context, state) => const MainShell(initialIndex: 3)),
      GoRoute(
        path: '/documents/:documentId',
        name: 'document-detail',
        builder: (context, state) {
          final documentId = Uri.decodeComponent(state.pathParameters['documentId'] ?? '');
          return _withShell(ShellNavScaffold.documentsIndex, DocumentDetailScreen(documentId: documentId));
        },
      ),
      GoRoute(path: '/payments', name: 'payments', builder: (context, state) => _withShell(ShellNavScaffold.moreIndex, const PaymentsScreen())),
      GoRoute(
        path: '/payments/:paymentId',
        name: 'payment-detail',
        builder: (context, state) {
          final paymentId = Uri.decodeComponent(state.pathParameters['paymentId'] ?? '');
          return _withShell(ShellNavScaffold.moreIndex, PaymentDetailScreen(paymentId: paymentId));
        },
      ),
      GoRoute(path: '/leads', name: 'leads', builder: (context, state) => _withShell(ShellNavScaffold.moreIndex, const LeadsScreen())),
      GoRoute(path: '/customers', name: 'customers', builder: (context, state) => _withShell(ShellNavScaffold.moreIndex, const CustomersScreen())),
      GoRoute(path: '/tasks', name: 'tasks', builder: (context, state) => _withShell(ShellNavScaffold.moreIndex, const TasksScreen())),
      GoRoute(
        path: '/leads/:leadId',
        name: 'lead-detail',
        builder: (context, state) {
          final leadId = Uri.decodeComponent(state.pathParameters['leadId'] ?? '');
          return _withShell(ShellNavScaffold.moreIndex, LeadDetailScreen(leadId: leadId));
        },
      ),
      GoRoute(
        path: '/customers/:customerId',
        name: 'customer-detail',
        builder: (context, state) {
          final customerId = Uri.decodeComponent(state.pathParameters['customerId'] ?? '');
          return _withShell(ShellNavScaffold.moreIndex, CustomerDetailScreen(customerId: customerId));
        },
      ),
      GoRoute(
        path: '/tasks/:taskId',
        name: 'task-detail',
        builder: (context, state) {
          final taskId = Uri.decodeComponent(state.pathParameters['taskId'] ?? '');
          return _withShell(ShellNavScaffold.moreIndex, TaskDetailScreen(taskId: taskId));
        },
      ),
      GoRoute(
        path: '/my-services/:caseId',
        name: 'service-case-detail',
        builder: (context, state) {
          final caseId = Uri.decodeComponent(state.pathParameters['caseId'] ?? '');
          return _withShell(ShellNavScaffold.trackIndex, ServiceCaseDetailScreen(caseId: caseId));
        },
      ),
      GoRoute(path: '/knowledge', name: 'knowledge', builder: (context, state) => _withShell(ShellNavScaffold.moreIndex, const KnowledgeScreen())),
      GoRoute(
        path: '/knowledge/:articleId',
        name: 'knowledge-detail',
        builder: (context, state) {
          final articleId = Uri.decodeComponent(state.pathParameters['articleId'] ?? '');
          return _withShell(ShellNavScaffold.moreIndex, KnowledgeDetailScreen(articleId: articleId));
        },
      ),
      GoRoute(path: '/notifications', name: 'notifications', builder: (context, state) => _withShell(ShellNavScaffold.moreIndex, const NotificationsScreen())),
      GoRoute(
        path: '/notifications/:notificationId',
        name: 'notification-detail',
        builder: (context, state) {
          final notificationId = Uri.decodeComponent(state.pathParameters['notificationId'] ?? '');
          return _withShell(ShellNavScaffold.moreIndex, NotificationDetailScreen(notificationId: notificationId));
        },
      ),
      GoRoute(path: '/support', name: 'support', builder: (context, state) => _withShell(ShellNavScaffold.moreIndex, const SupportScreen())),
      GoRoute(path: '/tax-calculator', name: 'tax-calculator', builder: (context, state) => _withShell(ShellNavScaffold.moreIndex, const TaxCalculatorScreen())),
      GoRoute(path: '/tax-calculator/history', name: 'tax-calculation-history', builder: (context, state) => _withShell(ShellNavScaffold.moreIndex, const TaxCalculationHistoryScreen())),
      GoRoute(path: '/profile', name: 'profile', builder: (context, state) => _withShell(ShellNavScaffold.moreIndex, const ProfileScreen())),
      GoRoute(path: '/expense-tracker', name: 'expense-tracker', builder: (context, state) => _withShell(ShellNavScaffold.moreIndex, const ExpenseTrackerScreen())),
      GoRoute(
        path: '/support-tickets/:ticketId',
        name: 'support-ticket-detail',
        builder: (context, state) {
          final ticketId = Uri.decodeComponent(state.pathParameters['ticketId'] ?? '');
          return _withShell(ShellNavScaffold.moreIndex, SupportTicketDetailScreen(ticketId: ticketId));
        },
      ),
      GoRoute(path: '/settings', name: 'settings', builder: (context, state) => _withShell(ShellNavScaffold.moreIndex, const SettingsScreen())),
      GoRoute(path: '/internal-workspace', name: 'internal-workspace', builder: (context, state) => _withShell(ShellNavScaffold.moreIndex, const InternalWorkspaceScreen())),
      GoRoute(path: '/internal-workspace/service-cases', name: 'internal-service-cases', builder: (context, state) => _withShell(ShellNavScaffold.moreIndex, const InternalServiceCasesScreen())),
    ],
  );
});

Widget _withShell(int selectedIndex, Widget child) {
  return ShellNavScaffold(selectedIndex: selectedIndex, child: child);
}

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(this._ref) {
    _subscription = _ref.listen<AuthState>(authControllerProvider, (_, _) => notifyListeners());
  }

  final Ref _ref;
  late final ProviderSubscription<AuthState> _subscription;

  @override
  void dispose() {
    _subscription.close();
    super.dispose();
  }
}

bool _isGuestAllowedRoute(String location) {
  if (location == '/home' ||
      location == '/services' ||
      location == '/more' ||
      location == '/knowledge' ||
      location == '/tax-calculator' ||
      location == '/expense-tracker' ||
      location == '/support') {
    return true;
  }

  if (location.startsWith('/knowledge/')) return true;

  return location.startsWith('/services/') && !location.endsWith('/request');
}

bool _canAccessRoute(String location, AuthCapabilities capabilities) {
  if (_isGuestAllowedRoute(location)) return true;

  if (_isServiceRequestRoute(location)) return capabilities.canCreateServiceRequest;

  if (location == '/dashboard') {
    return capabilities.canViewCustomerDashboard || capabilities.canAccessCustomerDashboard || capabilities.canAccessInternalWorkspace;
  }

  if (location == '/track' || location == '/my-services' || location.startsWith('/my-services/')) {
    return capabilities.canTrackRequests || capabilities.canViewCustomerDashboard || capabilities.canAccessCustomerDashboard || capabilities.isApproved || capabilities.canAccessInternalWorkspace;
  }

  if (location == '/documents' || location.startsWith('/documents/')) {
    return capabilities.canViewDocuments || capabilities.canReviewDocuments || capabilities.isApproved;
  }

  if (location == '/payments' || location.startsWith('/payments/')) {
    return capabilities.canViewPayments || capabilities.canReviewPayments || capabilities.isApproved || capabilities.isInternal;
  }

  if (location == '/notifications' || location.startsWith('/notifications/')) {
    return capabilities.canViewCustomerNotifications || capabilities.isApproved || capabilities.isInternal || capabilities.canAccessInternalWorkspace;
  }

  if (location.startsWith('/support-tickets/')) {
    return capabilities.canViewSupportTickets || capabilities.canAccessInternalWorkspace;
  }

  if (location == '/expense-tracker') {
    return !capabilities.isInternal;
  }

  if (location == '/internal-workspace' || location.startsWith('/internal-workspace/')) {
    return capabilities.canAccessInternalWorkspace;
  }

  if (location == '/leads' || location.startsWith('/leads/')) {
    return capabilities.canManageLeads || capabilities.canAccessInternalWorkspace;
  }

  if (location == '/customers' || location.startsWith('/customers/')) {
    return capabilities.canManageCustomers || capabilities.canAccessInternalWorkspace;
  }

  if (location == '/tasks' || location.startsWith('/tasks/')) {
    return capabilities.canManageTasks || capabilities.canAccessInternalWorkspace;
  }

  return true;
}

bool _isServiceRequestRoute(String location) {
  return location.startsWith('/services/') && location.endsWith('/request');
}
