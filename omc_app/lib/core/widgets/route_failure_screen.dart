import 'package:flutter/material.dart';

import '../../app/design_tokens.dart';
import '../../app/route_failure_recovery.dart';
import '../../app/theme.dart';
import '../diagnostics/omc_widget_keys.dart';

class RouteFailureScreen extends StatelessWidget {
  const RouteFailureScreen({
    required this.primaryActionLabel,
    required this.recoveryKind,
    required this.onPrimaryAction,
    this.onGoBack,
    super.key,
  });

  final String primaryActionLabel;
  final RouteFailureRecoveryKind recoveryKind;
  final VoidCallback onPrimaryAction;
  final VoidCallback? onGoBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      key: OmcWidgetKeys.routeFailure,
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.xxl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppLayout.formMaxWidth),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(AppRadius.card),
                      ),
                      child: Icon(
                        Icons.link_off_rounded,
                        color: theme.colorScheme.onPrimaryContainer,
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Semantics(
                    header: true,
                    child: Text(
                      'Page unavailable',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'This link is invalid, expired, or no longer available.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: onPrimaryAction,
                      icon: Icon(switch (recoveryKind) {
                        RouteFailureRecoveryKind.home => Icons.home_rounded,
                        RouteFailureRecoveryKind.signIn => Icons.login_rounded,
                        RouteFailureRecoveryKind.accountStatus =>
                          Icons.fact_check_outlined,
                      }),
                      label: Text(primaryActionLabel),
                    ),
                  ),
                  if (onGoBack != null) ...[
                    const SizedBox(height: AppSpacing.sm),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: onGoBack,
                        icon: const Icon(Icons.arrow_back_rounded),
                        label: const Text('Go back'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
