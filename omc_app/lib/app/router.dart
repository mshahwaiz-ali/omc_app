import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/widgets/route_failure_screen.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/application/auth_state.dart';
import '../features/auth/presentation/email_verification_screen.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/reset_password_screen.dart';
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/signup_screen.dart';
import '../features/auth/presentation/under_review_screen.dart';
import '../features/customers/presentation/customer_detail_screen.dart';
import '../features/customers/presentation/customers_screen.dart';
import '../features/dashboard/presentation/dashboard_screen.dart';
import '../features/documents/presentation/document_detail_screen.dart';
import '../features/expense_tracker/presentation/expense_budget_screen.dart';
import '../features/expense_tracker/presentation/expense_tracker_screen.dart';
import '../features/internal_workspace/presentation/internal_operations_center_screen.dart';
import '../features/internal_workspace/presentation/internal_service_cases_screen.dart';
import '../features/internal_workspace/presentation/internal_workspace_screen.dart';
import '../features/knowledge/presentation/knowledge_detail_screen.dart';
import '../features/knowledge/presentation/knowledge_screen.dart';
import '../features/leads/presentation/lead_detail_screen.dart';
import '../features/leads/presentation/leads_screen.dart';
import '../features/notifications/presentation/notification_detail_screen.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/onboarding/presentation/onboarding_screen.dart';
import '../features/payments/presentation/payment_detail_screen.dart';
import '../features/payments/presentation/payments_screen.dart';
import '../features/profile/presentation/my_referrals_screen.dart';
import '../features/profile/presentation/referral_detail_screen.dart';
import '../features/profile/presentation/edit_profile_screen.dart';
import '../features/profile/presentation/profile_screen.dart';
import '../features/service_catalogue/presentation/service_detail_screen.dart';
import '../features/service_requests/presentation/service_case_detail_screen.dart';
import '../features/service_requests/presentation/service_request_draft_screen.dart';
import '../features/settings/presentation/change_password_screen.dart';
import '../features/settings/presentation/settings_screen.dart';
import '../features/splash/presentation/splash_screen.dart';
import '../features/support/presentation/support_screen.dart';
import '../features/support/presentation/support_ticket_detail_screen.dart';
import '../features/tasks/presentation/task_detail_screen.dart';
import '../features/tasks/presentation/tasks_screen.dart';
import '../features/tax_calculator/presentation/tax_calculation_history_screen.dart';
import '../features/tax_calculator/presentation/tax_calculator_screen.dart';
import 'auth_route_redirect.dart';
import 'main_shell.dart';
import 'route_failure_recovery.dart';
import 'providers/effective_capabilities_provider.dart';
import 'shell_nav_scaffold.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final routerRefreshNotifier = _RouterRefreshNotifier(ref);
  ref.onDispose(routerRefreshNotifier.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: routerRefreshNotifier,
    errorBuilder: (context, state) {
      final authState = ref.read(authControllerProvider);
      final recovery = resolveRouteFailureRecovery(
        status: authState.status,
        capabilities: ref.read(effectiveCapabilitiesProvider),
      );
      final navigator = Navigator.of(context);

      return RouteFailureScreen(
        primaryActionLabel: recovery.label,
        recoveryKind: recovery.kind,
        onPrimaryAction: () => context.go(recovery.location),
        onGoBack: navigator.canPop() ? navigator.pop : null,
      );
    },
    redirect: (context, state) {
      final authState = ref.read(authControllerProvider);
      final capabilities = ref.read(effectiveCapabilitiesProvider);
      return resolveAuthRouteRedirect(
        status: authState.status,
        capabilities: capabilities,
        location: state.matchedLocation,
      );
    },
    routes: [
      GoRoute(
        path: '/',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        name: 'onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/reset-password',
        name: 'reset-password',
        builder: (context, state) => ResetPasswordScreen(
          token: state.uri.queryParameters['token'] ?? '',
        ),
      ),
      GoRoute(
        path: '/signup',
        name: 'signup',
        builder: (context, state) => const SignupScreen(),
      ),
      GoRoute(
        path: '/verify-email',
        name: 'verify-email',
        builder: (context, state) => EmailVerificationScreen(
          token: state.uri.queryParameters['token'] ?? '',
        ),
      ),
      GoRoute(
        path: '/under-review',
        name: 'under-review',
        builder: (context, state) => const UnderReviewScreen(),
      ),
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => MainShell(
          showAccessDeniedNotice:
              state.uri.queryParameters['notice'] == 'access-denied',
        ),
      ),
      GoRoute(
        path: '/services',
        name: 'services',
        builder: (context, state) => MainShell(
          initialIndex: 1,
          initialServiceQuery: state.uri.queryParameters['query'] ?? '',
        ),
      ),
      GoRoute(
        path: '/track',
        name: 'track',
        builder: (context, state) => const MainShell(initialIndex: 2),
      ),
      GoRoute(
        path: '/more',
        name: 'more',
        builder: (context, state) => const MainShell(showMoreOnLoad: true),
      ),
      GoRoute(
        path: '/services/:serviceId',
        name: 'service-detail',
        builder: (context, state) {
          final serviceId = Uri.decodeComponent(
            state.pathParameters['serviceId'] ?? '',
          );
          return _withShell(
            ShellNavScaffold.servicesIndex,
            ServiceDetailScreen(serviceId: serviceId),
          );
        },
      ),
      GoRoute(
        path: '/services/:serviceId/request',
        name: 'service-request-draft',
        builder: (context, state) {
          final serviceId = Uri.decodeComponent(
            state.pathParameters['serviceId'] ?? '',
          );
          return _withShell(
            ShellNavScaffold.servicesIndex,
            ServiceRequestDraftScreen(serviceId: serviceId),
          );
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
        builder: (context, state) =>
            _withShell(ShellNavScaffold.moreIndex, const DashboardScreen()),
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
          return _withShell(
            ShellNavScaffold.documentsIndex,
            DocumentDetailScreen(documentId: documentId),
          );
        },
      ),
      GoRoute(
        path: '/payments',
        name: 'payments',
        builder: (context, state) =>
            _withShell(ShellNavScaffold.moreIndex, const PaymentsScreen()),
      ),
      GoRoute(
        path: '/payments/:paymentId',
        name: 'payment-detail',
        builder: (context, state) {
          final paymentId = Uri.decodeComponent(
            state.pathParameters['paymentId'] ?? '',
          );
          return _withShell(
            ShellNavScaffold.moreIndex,
            PaymentDetailScreen(paymentId: paymentId),
          );
        },
      ),
      GoRoute(
        path: '/leads',
        name: 'leads',
        builder: (context, state) => _withShell(
          ShellNavScaffold.moreIndex,
          LeadsScreen(
            openCreateOnLoad: state.uri.queryParameters['action'] == 'create',
          ),
        ),
      ),
      GoRoute(
        path: '/customers',
        name: 'customers',
        builder: (context, state) =>
            _withShell(ShellNavScaffold.moreIndex, const CustomersScreen()),
      ),
      GoRoute(
        path: '/tasks',
        name: 'tasks',
        builder: (context, state) => _withShell(
          ShellNavScaffold.moreIndex,
          TasksScreen(
            openCreateOnLoad: state.uri.queryParameters['action'] == 'create',
          ),
        ),
      ),
      GoRoute(
        path: '/leads/:leadId',
        name: 'lead-detail',
        builder: (context, state) {
          final leadId = Uri.decodeComponent(
            state.pathParameters['leadId'] ?? '',
          );
          return _withShell(
            ShellNavScaffold.moreIndex,
            LeadDetailScreen(leadId: leadId),
          );
        },
      ),
      GoRoute(
        path: '/customers/:customerId',
        name: 'customer-detail',
        builder: (context, state) {
          final customerId = Uri.decodeComponent(
            state.pathParameters['customerId'] ?? '',
          );
          return _withShell(
            ShellNavScaffold.moreIndex,
            CustomerDetailScreen(customerId: customerId),
          );
        },
      ),
      GoRoute(
        path: '/tasks/:taskId',
        name: 'task-detail',
        builder: (context, state) {
          final taskId = Uri.decodeComponent(
            state.pathParameters['taskId'] ?? '',
          );
          return _withShell(
            ShellNavScaffold.moreIndex,
            TaskDetailScreen(taskId: taskId),
          );
        },
      ),
      GoRoute(
        path: '/my-services/:caseId',
        name: 'service-case-detail',
        builder: (context, state) {
          final caseId = Uri.decodeComponent(
            state.pathParameters['caseId'] ?? '',
          );
          return _withShell(
            ShellNavScaffold.trackIndex,
            ServiceCaseDetailScreen(caseId: caseId),
          );
        },
      ),
      GoRoute(
        path: '/knowledge',
        name: 'knowledge',
        builder: (context, state) =>
            _withShell(ShellNavScaffold.moreIndex, const KnowledgeScreen()),
      ),
      GoRoute(
        path: '/knowledge/:articleId',
        name: 'knowledge-detail',
        builder: (context, state) {
          final articleId = Uri.decodeComponent(
            state.pathParameters['articleId'] ?? '',
          );
          return _withShell(
            ShellNavScaffold.moreIndex,
            KnowledgeDetailScreen(articleId: articleId),
          );
        },
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) =>
            _withShell(ShellNavScaffold.moreIndex, const NotificationsScreen()),
      ),
      GoRoute(
        path: '/notifications/:notificationId',
        name: 'notification-detail',
        builder: (context, state) {
          final notificationId = Uri.decodeComponent(
            state.pathParameters['notificationId'] ?? '',
          );
          return _withShell(
            ShellNavScaffold.moreIndex,
            NotificationDetailScreen(notificationId: notificationId),
          );
        },
      ),
      GoRoute(
        path: '/support',
        name: 'support',
        builder: (context, state) =>
            _withShell(ShellNavScaffold.moreIndex, const SupportScreen()),
      ),
      GoRoute(
        path: '/tax-calculator',
        name: 'tax-calculator',
        builder: (context, state) =>
            _withShell(ShellNavScaffold.moreIndex, const TaxCalculatorScreen()),
      ),
      GoRoute(
        path: '/tax-calculator/history',
        name: 'tax-calculation-history',
        builder: (context, state) => _withShell(
          ShellNavScaffold.moreIndex,
          const TaxCalculationHistoryScreen(),
        ),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) =>
            _withShell(ShellNavScaffold.moreIndex, const ProfileScreen()),
      ),
      GoRoute(
        path: '/profile/edit',
        name: 'edit-profile',
        builder: (context, state) =>
            _withShell(ShellNavScaffold.moreIndex, const EditProfileScreen()),
      ),
      GoRoute(
        path: '/my-referrals',
        name: 'my-referrals',
        builder: (context, state) =>
            _withShell(ShellNavScaffold.moreIndex, const MyReferralsScreen()),
      ),
      GoRoute(
        path: '/my-referrals/:customerId',
        name: 'my-referral-detail',
        builder: (context, state) {
          final customerId = Uri.decodeComponent(
            state.pathParameters['customerId'] ?? '',
          );
          final customerName = state.uri.queryParameters['name'] ?? '';

          return _withShell(
            ShellNavScaffold.moreIndex,
            ReferralDetailScreen(
              customerProfile: customerId,
              customerName: customerName,
            ),
          );
        },
      ),
      GoRoute(
        path: '/expense-tracker',
        name: 'expense-tracker',
        builder: (context, state) => _withShell(
          ShellNavScaffold.moreIndex,
          const ExpenseTrackerScreen(),
        ),
      ),
      GoRoute(
        path: '/expense-budget',
        name: 'expense-budget',
        builder: (context, state) =>
            _withShell(ShellNavScaffold.moreIndex, const ExpenseBudgetScreen()),
      ),
      GoRoute(
        path: '/support-tickets/:ticketId',
        name: 'support-ticket-detail',
        builder: (context, state) {
          final ticketId = Uri.decodeComponent(
            state.pathParameters['ticketId'] ?? '',
          );
          return _withShell(
            ShellNavScaffold.moreIndex,
            SupportTicketDetailScreen(ticketId: ticketId),
          );
        },
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) =>
            _withShell(ShellNavScaffold.moreIndex, const SettingsScreen()),
      ),
      GoRoute(
        path: '/change-password',
        name: 'change-password',
        builder: (context, state) => _withShell(
          ShellNavScaffold.moreIndex,
          const ChangePasswordScreen(),
        ),
      ),
      GoRoute(
        path: '/internal-workspace',
        name: 'internal-workspace',
        builder: (context, state) => _withShell(
          ShellNavScaffold.moreIndex,
          const InternalWorkspaceScreen(),
        ),
      ),
      GoRoute(
        path: '/internal-workspace/service-cases',
        name: 'internal-service-cases',
        builder: (context, state) => _withShell(
          ShellNavScaffold.trackIndex,
          const InternalServiceCasesScreen(),
        ),
      ),
      GoRoute(
        path: '/internal-workspace/customers',
        name: 'internal-customers',
        builder: (context, state) =>
            _withShell(ShellNavScaffold.moreIndex, const CustomersScreen()),
      ),
      GoRoute(
        path: '/internal-workspace/documents',
        name: 'internal-documents',
        builder: (context, state) => _withShell(
          ShellNavScaffold.moreIndex,
          const InternalOperationsCenterScreen(
            area: InternalOperationArea.documents,
          ),
        ),
      ),
      GoRoute(
        path: '/internal-workspace/payments',
        name: 'internal-payments',
        builder: (context, state) => _withShell(
          ShellNavScaffold.moreIndex,
          const InternalOperationsCenterScreen(
            area: InternalOperationArea.payments,
          ),
        ),
      ),
      GoRoute(
        path: '/internal-workspace/service-cases/:caseId',
        name: 'internal-service-case-workspace',
        builder: (context, state) {
          final caseId = Uri.decodeComponent(
            state.pathParameters['caseId'] ?? '',
          );
          return _withShell(
            ShellNavScaffold.trackIndex,
            InternalServiceCaseWorkspaceScreen(caseId: caseId),
          );
        },
      ),
    ],
  );
});

Widget _withShell(int selectedIndex, Widget child) {
  return ShellNavScaffold(selectedIndex: selectedIndex, child: child);
}

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(this._ref) {
    _authSubscription = _ref.listen<AuthState>(
      authControllerProvider,
      (_, _) => notifyListeners(),
    );
    _capabilitiesSubscription = _ref.listen<AuthCapabilities>(
      effectiveCapabilitiesProvider,
      (_, _) => notifyListeners(),
    );
  }

  final Ref _ref;
  late final ProviderSubscription<AuthState> _authSubscription;
  late final ProviderSubscription<AuthCapabilities> _capabilitiesSubscription;

  @override
  void dispose() {
    _authSubscription.close();
    _capabilitiesSubscription.close();
    super.dispose();
  }
}
