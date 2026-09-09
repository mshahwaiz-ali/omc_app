import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import '../../app/theme.dart';
import '../resilience/app_failure.dart';
import '../diagnostics/omc_widget_keys.dart';
import 'app_button.dart';

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AppStateView(
      title: title,
      message: message,
      icon: icon,
      accentColor: AppTheme.textSecondary,
      surfaceColor: AppTheme.cardSoft,
      actionLabel: actionLabel,
      onAction: onAction,
      compact: compact,
    );
  }
}

class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Try again',
    this.icon = Icons.error_outline_rounded,
    this.compact = false,
  });

  factory AppErrorState.fromError({
    Key? key,
    required Object error,
    VoidCallback? onRetry,
    String? fallbackTitle,
    String? fallbackMessage,
    bool compact = false,
  }) {
    final failure = AppFailureClassifier.classify(
      error,
      fallbackTitle: fallbackTitle,
      fallbackMessage: fallbackMessage,
    );

    return AppErrorState(
      key: key,
      title: failure.title,
      message: failure.message,
      onRetry: failure.canRetry ? onRetry : null,
      compact: compact,
    );
  }

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AppStateView(
      key: key ?? OmcWidgetKeys.appError,
      title: title,
      message: message,
      icon: icon,
      accentColor: AppTheme.danger,
      surfaceColor: AppTheme.dangerSoft,
      actionLabel: onRetry == null ? null : retryLabel,
      actionIcon: Icons.refresh_rounded,
      onAction: onRetry,
      compact: compact,
    );
  }
}

class AppConfigurationState extends StatelessWidget {
  const AppConfigurationState({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AppStateView(
      title: title,
      message: message,
      icon: Icons.settings_suggest_outlined,
      accentColor: AppTheme.warning,
      surfaceColor: AppTheme.warningSoft,
      actionLabel: actionLabel,
      onAction: onAction,
      compact: compact,
    );
  }
}

class AppAccessState extends StatelessWidget {
  const AppAccessState({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return AppStateView(
      title: title,
      message: message,
      icon: Icons.lock_outline_rounded,
      accentColor: AppTheme.info,
      surfaceColor: AppTheme.infoSoft,
      actionLabel: actionLabel,
      onAction: onAction,
      compact: compact,
    );
  }
}

class AppStateView extends StatelessWidget {
  const AppStateView({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    required this.accentColor,
    required this.surfaceColor,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
    this.compact = false,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color accentColor;
  final Color surfaceColor;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(compact ? AppSpacing.md : AppSpacing.lg),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Container(
                width: compact ? AppTouchTarget.minimum : 56,
                height: compact ? AppTouchTarget.minimum : 56,
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: Icon(icon, color: accentColor, size: compact ? 24 : 28),
              ),
            ),
            SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
            Semantics(
              header: true,
              child: Text(
                title,
                textAlign: TextAlign.center,
                softWrap: true,
                style:
                    (compact
                            ? theme.textTheme.titleMedium
                            : theme.textTheme.titleLarge)
                        ?.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              softWrap: true,
              style:
                  (compact
                          ? theme.textTheme.bodyMedium
                          : theme.textTheme.bodyLarge)
                      ?.copyWith(color: AppTheme.textSecondary),
            ),
            if (actionLabel != null && onAction != null) ...[
              SizedBox(height: compact ? AppSpacing.sm : AppSpacing.md),
              AppButton(
                label: actionLabel!,
                icon: actionIcon,
                onPressed: onAction,
                isExpanded: false,
              ),
            ],
          ],
        ),
      ),
    );

    if (compact) return content;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: content,
      ),
    );
  }
}
