import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/design_tokens.dart';
import '../../app/navigation/navigation_coordinator.dart';

class AppBackHeader extends StatelessWidget implements PreferredSizeWidget {
  const AppBackHeader({
    required this.title,
    super.key,
    this.subtitle,
    this.action,
    this.actionIcon,
    this.actionTooltip,
    this.onAction,
    this.fallbackRoute,
  });

  final String title;
  final String? subtitle;
  final Widget? action;
  final IconData? actionIcon;
  final String? actionTooltip;
  final VoidCallback? onAction;
  final String? fallbackRoute;

  @override
  Size get preferredSize => Size.fromHeight(subtitle == null ? 84 : 104);

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final resolvedFallbackRoute =
        fallbackRoute ?? _fallbackRouteFor(router.state.uri.path);

    void goBack() => NavigationCoordinator.back(
      context,
      fallbackLocation: resolvedFallbackRoute,
    );

    return Material(
      color: colors.surface,
      child: SafeArea(
        bottom: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(bottom: BorderSide(color: colors.outlineVariant)),
          ),
          child: Row(
            children: [
              Tooltip(
                message: 'Back',
                child: Semantics(
                  button: true,
                  label: 'Go back',
                  excludeSemantics: true,
                  child: Material(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(AppRadius.small + 2),
                    child: InkWell(
                      onTap: goBack,
                      borderRadius: BorderRadius.circular(AppRadius.small + 2),
                      child: Container(
                        constraints: AppTouchTarget.constraints,
                        width: AppTouchTarget.minimum,
                        height: AppTouchTarget.minimum,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            AppRadius.small + 2,
                          ),
                          border: Border.all(color: colors.outlineVariant),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x0A111827),
                              blurRadius: 12,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          size: 20,
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: colors.onSurface,
                          height: 1.1,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                    if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          height: 1.25,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (action != null) ...[
                const SizedBox(width: AppSpacing.xs),
                action!,
              ],
              if (actionIcon != null && onAction != null) ...[
                const SizedBox(width: AppSpacing.xs),
                Tooltip(
                  message: actionTooltip ?? 'More action',
                  child: Semantics(
                    button: true,
                    label: actionTooltip ?? 'More action',
                    excludeSemantics: true,
                    child: Material(
                      color: colors.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadius.small + 2),
                      child: InkWell(
                        onTap: onAction,
                        borderRadius: BorderRadius.circular(
                          AppRadius.small + 2,
                        ),
                        child: Container(
                          constraints: AppTouchTarget.constraints,
                          width: AppTouchTarget.minimum,
                          height: AppTouchTarget.minimum,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              AppRadius.small + 2,
                            ),
                            border: Border.all(color: colors.outlineVariant),
                          ),
                          child: Icon(
                            actionIcon,
                            size: 21,
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _fallbackRouteFor(String location) {
  final path = location.trim();

  if (path.startsWith('/tasks/')) {
    return '/tasks';
  }

  if (path.startsWith('/leads/')) {
    return '/leads';
  }

  if (path.startsWith('/customers/')) {
    return '/customers';
  }

  if (path.startsWith('/payments/')) {
    return '/payments';
  }

  if (path.startsWith('/documents/')) {
    return '/documents';
  }

  if (path.startsWith('/notifications/')) {
    return '/notifications';
  }

  if (path.startsWith('/knowledge/')) {
    return '/knowledge';
  }

  if (path.startsWith('/support-tickets/')) {
    return '/support';
  }

  if (path.startsWith('/my-services/')) {
    return '/my-services';
  }

  if (path.startsWith('/internal-workspace/service-cases/')) {
    return '/internal-workspace/service-cases';
  }

  if (path.startsWith('/internal-workspace/operations')) {
    return '/internal-workspace';
  }

  if (path.startsWith('/services/')) {
    return '/services';
  }

  if (path.startsWith('/tax-calculator/')) {
    return '/tax-calculator';
  }

  if (path.startsWith('/expense-budget')) {
    return '/expense-tracker';
  }

  return '/home';
}
