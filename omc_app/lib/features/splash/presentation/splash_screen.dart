import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
import '../../../app/providers/core_providers.dart';
import '../../../app/theme.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/diagnostics/omc_widget_keys.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/omc_logo.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  bool _isResolving = false;
  String? _startupError;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _resolveSession();
    });
  }

  Future<void> _resolveSession() async {
    if (_isResolving) return;

    setState(() {
      _isResolving = true;
      _startupError = null;
    });

    try {
      final results = await Future.wait<Object>([
        ref
            .read(authControllerProvider.notifier)
            .checkSession()
            .then((_) => true),
        ref.read(preferencesServiceProvider.future),
      ]);

      if (!mounted) return;

      final authState = ref.read(authControllerProvider);
      final preferences = results[1] as dynamic;
      final hasCompletedOnboarding = preferences.hasCompletedOnboarding == true;
      final nextLocation = authState.status == AuthStatus.authenticated
          ? '/home'
          : hasCompletedOnboarding
          ? '/login'
          : '/onboarding';

      context.go(nextLocation);
    } catch (error) {
      if (!mounted) return;
      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'App could not start',
        fallbackMessage:
            'OMC could not prepare the app right now. Please try again.',
      );
      setState(() {
        _isResolving = false;
        _startupError = failure.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: OmcWidgetKeys.splashScreen,
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: _startupError == null
              ? const _SplashContent()
              : _SplashFailure(
                  message: _startupError!,
                  onRetry: _resolveSession,
                ),
        ),
      ),
    );
  }
}

class _SplashFailure extends StatelessWidget {
  const _SplashFailure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: ConstrainedBox(
        key: OmcWidgetKeys.startupError,
        constraints: const BoxConstraints(maxWidth: AppLayout.formMaxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppTheme.border),
              ),
              child: const OmcLogo.symbol(size: 56, borderRadius: 0),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'OMC could not start',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.xl),
            AppButton(
              label: 'Try again',
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
              isExpanded: false,
            ),
          ],
        ),
      ),
    );
  }
}

class _SplashContent extends StatelessWidget {
  const _SplashContent();

  @override
  Widget build(BuildContext context) {
    final reducedMotion = AppMotion.reducedMotion(context);

    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Starting OMC',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96,
                height: 96,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.dialog),
                  border: Border.all(color: AppTheme.border),
                ),
                child: const OmcLogo.symbol(size: 68, borderRadius: 0),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Starting OMC',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.sm),
              if (reducedMotion)
                const Icon(
                  Icons.hourglass_top_rounded,
                  color: AppTheme.textSecondary,
                  size: 24,
                )
              else
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
