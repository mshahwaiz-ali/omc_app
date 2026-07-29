import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/config/support_config.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/premium_card.dart';
import '../application/auth_controller.dart';
import '../application/auth_state.dart';
import '../../../core/resilience/app_failure.dart';

class UnderReviewScreen extends ConsumerStatefulWidget {
  const UnderReviewScreen({super.key});

  @override
  ConsumerState<UnderReviewScreen> createState() => _UnderReviewScreenState();
}

class _UnderReviewScreenState extends ConsumerState<UnderReviewScreen> {
  static const message =
      'Your application is under review. OMC will enable the relevant access after approval.';

  bool _refreshing = false;
  bool _loggingOut = false;
  String? _statusMessage;

  Future<void> _refreshStatus() async {
    if (_refreshing || _loggingOut) return;

    setState(() {
      _refreshing = true;
      _statusMessage = null;
    });

    await ref.read(authControllerProvider.notifier).checkSession();
    if (!mounted) return;

    final authState = ref.read(authControllerProvider);
    if (authState.status == AuthStatus.unauthenticated) {
      context.go('/login');
      return;
    }
    if (authState.status == AuthStatus.authenticated &&
        !authState.capabilities.isPending) {
      context.go('/home');
      return;
    }

    setState(() {
      _refreshing = false;
      _statusMessage =
          'Your application is still under review. We will notify you after approval.';
    });
  }

  Future<void> _logout() async {
    if (_loggingOut || _refreshing) return;

    setState(() => _loggingOut = true);
    try {
      await ref.read(authControllerProvider.notifier).logout();
      if (!mounted) return;
      context.go('/login');
    } catch (error) {
      if (!mounted) return;

      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Sign out incomplete',
        fallbackMessage:
            'Your session could not be cleared right now. Please try again.',
      );
      setState(() => _statusMessage = failure.message);
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  void _showSupport() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Contact OMC support',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 14),
              SelectableText(
                SupportConfig.email,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              SelectableText(
                SupportConfig.phoneNumber,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                SupportConfig.businessHours,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = _refreshing || _loggingOut;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: PremiumCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Align(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: const Icon(
                        Icons.hourglass_top_rounded,
                        color: AppTheme.primary,
                        size: 30,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Application under review',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_statusMessage != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      _statusMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  AppButton(
                    label: 'Refresh Status',
                    icon: Icons.refresh_rounded,
                    isLoading: _refreshing,
                    onPressed: busy ? null : _refreshStatus,
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: busy ? null : _showSupport,
                    icon: const Icon(Icons.support_agent_rounded),
                    label: const Text('Contact Support'),
                  ),
                  const SizedBox(height: 6),
                  TextButton.icon(
                    onPressed: busy ? null : _logout,
                    icon: _loggingOut
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.logout_rounded),
                    label: Text(_loggingOut ? 'Signing out...' : 'Sign out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
