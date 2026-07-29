import 'package:flutter/material.dart';

import '../../app/route_failure_recovery.dart';
import '../../app/theme.dart';

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
    return Scaffold(
      backgroundColor: const Color(0xFFFBFCFE),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: const Icon(
                      Icons.link_off_rounded,
                      color: AppTheme.primary,
                      size: 34,
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Page unavailable',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'This link is invalid, expired, or no longer available.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 24),
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
                    const SizedBox(height: 10),
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
