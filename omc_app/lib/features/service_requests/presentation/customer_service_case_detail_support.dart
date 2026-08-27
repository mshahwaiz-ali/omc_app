part of 'customer_service_case_detail_screen.dart';

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 36),
      children: const [
        AppSkeleton(height: 170),
        SizedBox(height: 14),
        AppSkeleton(height: 330),
        SizedBox(height: 14),
        AppSkeleton(height: 140),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.title, required this.message, this.onRetry});

  final String title;
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: AppErrorState(title: title, message: message, onRetry: onRetry),
      ),
    );
  }
}

({IconData icon, Color foreground, Color background}) _milestoneVisual(
  CustomerServiceCaseMilestone milestone,
) {
  if (milestone.isComplete) {
    return (
      icon: Icons.check_rounded,
      foreground: AppTheme.success,
      background: AppTheme.success.withValues(alpha: 0.12),
    );
  }
  if (milestone.isSkipped) {
    return (
      icon: Icons.remove_rounded,
      foreground: AppTheme.textSecondary,
      background: AppTheme.primarySoft,
    );
  }
  if (milestone.isAttention) {
    return (
      icon: Icons.priority_high_rounded,
      foreground: AppTheme.danger,
      background: AppTheme.dangerSoft,
    );
  }
  if (milestone.isCurrent) {
    return (
      icon: Icons.circle,
      foreground: AppTheme.info,
      background: AppTheme.info.withValues(alpha: 0.12),
    );
  }
  return (
    icon: Icons.circle_outlined,
    foreground: AppTheme.textSecondary,
    background: AppTheme.primarySoft,
  );
}

bool _canOpenAction(
  CustomerServiceCaseAction action, {
  required bool canViewDocuments,
  required bool canViewPayments,
}) {
  final route = action.route.trim();
  if (route.isEmpty) return false;
  if (route.startsWith('/documents')) return canViewDocuments;
  if (route.startsWith('/payments')) return canViewPayments;
  return true;
}

void _openAction(
  BuildContext context,
  CustomerServiceCaseDetail detail,
  CustomerServiceCaseAction action,
) {
  final route = action.route.trim();
  if (route.startsWith('/payments')) {
    _openPayments(context, detail);
    return;
  }
  if (route.startsWith('/documents')) {
    context.go('/documents');
    return;
  }
  if (route.isNotEmpty && !route.startsWith('/my-services/')) {
    context.push(route.startsWith('/') ? route : '/$route');
  }
}

void _openPayments(BuildContext context, CustomerServiceCaseDetail detail) {
  final paymentId = detail.paymentId.trim();
  if (paymentId.isNotEmpty) {
    context.push('/payments/${Uri.encodeComponent(paymentId)}');
    return;
  }
  context.go('/payments');
}
