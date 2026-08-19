part of 'approved_customer_home_view.dart';

class _CustomerHomeLoading extends StatelessWidget {
  const _CustomerHomeLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 150),
      children: const [
        _LoadingPanel(height: 70),
        SizedBox(height: 18),
        _LoadingPanel(height: 360),
        SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _LoadingPanel(height: 92)),
            SizedBox(width: 8),
            Expanded(child: _LoadingPanel(height: 92)),
            SizedBox(width: 8),
            Expanded(child: _LoadingPanel(height: 92)),
          ],
        ),
      ],
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppTheme.primarySoft,
          borderRadius: BorderRadius.circular(22),
        ),
      ),
    );
  }
}

({IconData icon, Color foreground, Color background}) _milestoneVisual(
  HomeDashboardLifecycleMilestone milestone,
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

void _openAction(
  BuildContext context,
  HomeDashboardServiceSnapshot service,
  HomeDashboardNextAction action,
) {
  final route = action.route.trim();
  if (route.isEmpty) {
    _openService(context, service);
    return;
  }
  context.push(route.startsWith('/') ? route : '/$route');
}

void _openService(BuildContext context, HomeDashboardServiceSnapshot service) {
  if (service.id.trim().isEmpty) {
    context.go('/my-services');
    return;
  }
  context.push('/my-services/${Uri.encodeComponent(service.id)}');
}
