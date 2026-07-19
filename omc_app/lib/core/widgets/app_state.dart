import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../resilience/app_failure.dart';
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
      title: title,
      message: message,
      icon: icon,
      accentColor: AppTheme.danger,
      surfaceColor: AppTheme.dangerSoft,
      actionLabel: onRetry == null ? null : retryLabel,
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
      surfaceColor: const Color(0xFFFFF7ED),
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
      surfaceColor: const Color(0xFFEFF6FF),
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
    this.onAction,
    this.compact = false,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color accentColor;
  final Color surfaceColor;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 18 : 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 48 : 60,
            height: compact ? 48 : 60,
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(compact ? 16 : 20),
            ),
            child: Icon(icon, color: accentColor, size: compact ? 24 : 30),
          ),
          SizedBox(height: compact ? 12 : 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: compact ? 16 : 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: compact ? 13 : 14,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            SizedBox(height: compact ? 14 : 18),
            AppButton(
              label: actionLabel!,
              icon: Icons.refresh_rounded,
              onPressed: onAction,
              isExpanded: false,
            ),
          ],
        ],
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
