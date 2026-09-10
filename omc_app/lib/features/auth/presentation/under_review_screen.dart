import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
import '../../../app/theme.dart';
import '../../../core/config/support_config.dart';
import '../../../core/diagnostics/omc_widget_keys.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/premium_card.dart';
import '../application/auth_controller.dart';
import '../application/auth_state.dart';

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
      _statusMessage = 'Your application is still under review.';
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
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.sheet),
        ),
      ),
      builder: (sheetContext) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Contact OMC support',
              style: Theme.of(sheetContext).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Text('Email', style: Theme.of(sheetContext).textTheme.titleMedium),
            const SizedBox(height: 4),
            SelectableText(
              SupportConfig.email,
              style: Theme.of(sheetContext).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Text('Phone', style: Theme.of(sheetContext).textTheme.titleMedium),
            const SizedBox(height: 4),
            SelectableText(
              SupportConfig.phoneNumber,
              style: Theme.of(sheetContext).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Text(
              'Business hours',
              style: Theme.of(sheetContext).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              SupportConfig.businessHours,
              style: Theme.of(sheetContext).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final busy = _refreshing || _loggingOut;

    return Scaffold(
      key: OmcWidgetKeys.underReviewScreen,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppLayout.pageInsetFor(MediaQuery.sizeOf(context).width),
              24,
              AppLayout.pageInsetFor(MediaQuery.sizeOf(context).width),
              28,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: PremiumCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: AppTheme.processingSoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.hourglass_top_rounded,
                          color: AppTheme.textSecondary,
                          size: 24,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Application under review',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    if (_statusMessage != null) ...[
                      const SizedBox(height: 18),
                      Semantics(
                        liveRegion: true,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.processingSoft,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.border),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.info_outline_rounded,
                                color: AppTheme.textSecondary,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  _statusMessage!,
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    AppButton(
                      label: 'Refresh status',
                      icon: Icons.refresh_rounded,
                      isLoading: _refreshing,
                      onPressed: busy ? null : _refreshStatus,
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: busy ? null : _showSupport,
                      icon: const Icon(Icons.support_agent_rounded),
                      label: const Text('Contact support'),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      key: OmcWidgetKeys.underReviewLogout,
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
      ),
    );
  }
}
