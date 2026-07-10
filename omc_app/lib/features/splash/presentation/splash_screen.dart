import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/core_providers.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/omc_logo.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/application/auth_state.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _resolveSession();
    });
  }

  Future<void> _resolveSession() async {
    final results = await Future.wait<Object>([
      ref
          .read(authControllerProvider.notifier)
          .checkSession()
          .then((_) => true),
      ref.read(preferencesServiceProvider.future),
      Future<void>.delayed(const Duration(milliseconds: 900)).then((_) => true),
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
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(child: Center(child: _SplashContent())),
    );
  }
}

class _SplashContent extends StatelessWidget {
  const _SplashContent();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 156,
            height: 156,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(38),
              border: Border.all(color: const Color(0xFFE8EDF5)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x140F172A),
                  blurRadius: 36,
                  offset: Offset(0, 18),
                ),
              ],
            ),
            padding: const EdgeInsets.all(18),
            child: const OmcLogo.symbol(size: 118, borderRadius: 0),
          ),
          const SizedBox(height: 28),
          const OmcLogo.full(width: 190, height: 60),
          const SizedBox(height: 10),
          const Text(
            'Premium business operations, simplified.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 30),
          const SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              color: AppTheme.primaryRed,
              backgroundColor: Color(0x14A40D22),
              strokeCap: StrokeCap.round,
            ),
          ),
        ],
      ),
    );
  }
}
