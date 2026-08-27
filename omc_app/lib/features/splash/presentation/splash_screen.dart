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
      backgroundColor: const Color(0xFFFBFCFE),
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
    return Padding(
      key: OmcWidgetKeys.startupError,
      padding: const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const OmcLogo.symbol(size: 76, borderRadius: 0),
            const SizedBox(height: 26),
            const Text(
              'OMC could not start',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 22),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 126,
              height: 126,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(34),
                border: Border.all(color: const Color(0xFFE8EDF5)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x120F172A),
                    blurRadius: 32,
                    offset: Offset(0, 16),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(17),
              child: const OmcLogo.symbol(size: 92, borderRadius: 0),
            ),
            const SizedBox(height: 20),
            if (reducedMotion)
              const Text(
                'Starting OMC',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              )
            else
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.6,
                  color: AppTheme.primary,
                  backgroundColor: Color(0x12111827),
                  strokeCap: StrokeCap.round,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
