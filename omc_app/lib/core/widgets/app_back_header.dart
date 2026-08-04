import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
  Size get preferredSize => Size.fromHeight(subtitle == null ? 76 : 90);

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.of(context);
    final colors = Theme.of(context).colorScheme;
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
              Semantics(
                button: true,
                label: 'Go back',
                child: Material(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    onTap: goBack,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
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
                        size: 18,
                        color: colors.onSurface,
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
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.onSurface,
                        fontSize: 19,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colors.onSurfaceVariant,
                          fontSize: 12,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (action != null) ...[const SizedBox(width: 10), action!],
              if (actionIcon != null && onAction != null) ...[
                const SizedBox(width: 10),
                Tooltip(
                  message: actionTooltip ?? 'More action',
                  child: Material(
                    color: colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: onAction,
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
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
