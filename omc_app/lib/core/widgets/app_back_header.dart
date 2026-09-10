import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/design_tokens.dart';
import '../../app/navigation/navigation_coordinator.dart';
import '../../app/theme.dart';

class AppBackHeader extends StatelessWidget implements PreferredSizeWidget {
  static const double _bottomBorderWidth = 1.0;

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
  Size get preferredSize {
    final views = WidgetsBinding.instance.platformDispatcher.views;
    if (views.isEmpty) {
      return Size.fromHeight(_fallbackPreferredHeight);
    }

    final media = MediaQueryData.fromView(views.first);
    final width = media.size.width;
    final horizontalInset = width >= 600 ? AppSpacing.xl : AppSpacing.md;
    final trailingReserve = action != null
        ? 120.0
        : actionIcon != null && onAction != null
        ? 60.0
        : 0.0;
    final availableTextWidth =
        (width -
                (horizontalInset * 2) -
                AppTouchTarget.minimum -
                AppSpacing.sm -
                trailingReserve)
            .clamp(96.0, width)
            .toDouble();

    final titleHeight = _measureTextHeight(
      title,
      style: AppTheme.textTheme.headlineMedium!,
      maxWidth: availableTextWidth,
      textScaler: media.textScaler,
    );
    final cleanSubtitle = subtitle?.trim();
    final subtitleHeight = cleanSubtitle == null || cleanSubtitle.isEmpty
        ? 0.0
        : _measureTextHeight(
            cleanSubtitle,
            style: AppTheme.textTheme.bodyMedium!,
            maxWidth: availableTextWidth,
            textScaler: media.textScaler,
          );
    final textHeight =
        titleHeight +
        (subtitleHeight > 0 ? AppSpacing.xxs + subtitleHeight : 0.0);
    final paddedTextHeight = (AppSpacing.xxs + textHeight).ceilToDouble();
    final rowHeight = paddedTextHeight > AppTouchTarget.minimum
        ? paddedTextHeight
        : AppTouchTarget.minimum;

    // Scaffold adds the system top inset to preferredSize. AppBackHeader keeps
    // SafeArea so the same widget also remains correct when used directly in a
    // Column outside Scaffold.appBar.
    final chromeHeight = AppSpacing.xs + AppSpacing.sm + _bottomBorderWidth;

    return Size.fromHeight(rowHeight + chromeHeight);
  }

  double get _fallbackPreferredHeight =>
      subtitle == null || subtitle!.trim().isEmpty ? 72 : 96;

  static double _measureTextHeight(
    String value, {
    required TextStyle style,
    required double maxWidth,
    required TextScaler textScaler,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: value, style: style),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout(maxWidth: maxWidth);
    return painter.height;
  }

  @override
  Widget build(BuildContext context) {
    final router = GoRouter.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final horizontalInset = width >= 600 ? AppSpacing.xl : AppSpacing.md;
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
          padding: EdgeInsets.fromLTRB(
            horizontalInset,
            AppSpacing.xs,
            horizontalInset,
            AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(
              bottom: BorderSide(
                color: colors.outlineVariant,
                width: _bottomBorderWidth,
              ),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeaderIconButton(
                tooltip: 'Back',
                semanticLabel: 'Go back',
                icon: Icons.arrow_back_rounded,
                onTap: goBack,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xxs),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          title,
                          softWrap: true,
                          style: theme.textTheme.headlineMedium?.copyWith(
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                      if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          subtitle!,
                          softWrap: true,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              if (action != null) ...[
                const SizedBox(width: AppSpacing.xs),
                ConstrainedBox(
                  constraints: AppTouchTarget.constraints,
                  child: Center(child: action!),
                ),
              ],
              if (actionIcon != null && onAction != null) ...[
                const SizedBox(width: AppSpacing.xs),
                _HeaderIconButton(
                  tooltip: actionTooltip ?? 'More action',
                  semanticLabel: actionTooltip ?? 'More action',
                  icon: actionIcon!,
                  onTap: onAction!,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({
    required this.tooltip,
    required this.semanticLabel,
    required this.icon,
    required this.onTap,
  });

  final String tooltip;
  final String semanticLabel;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: semanticLabel,
        excludeSemantics: true,
        child: Material(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.control),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadius.control),
            child: Container(
              constraints: AppTouchTarget.constraints,
              width: AppTouchTarget.minimum,
              height: AppTouchTarget.minimum,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.control),
                border: Border.all(color: colors.outlineVariant),
              ),
              child: Icon(icon, size: 24, color: colors.onSurface),
            ),
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
