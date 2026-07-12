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
      Future<void>.delayed(const Duration(milliseconds: 700)).then((_) => true),
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
      backgroundColor: Color(0xFFFBFCFE),
      body: SafeArea(child: Center(child: _SplashContent())),
    );
  }
}

class _SplashContent extends StatelessWidget {
  const _SplashContent();

  @override
  Widget build(BuildContext context) {
    return Column(
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
        const SizedBox(height: 34),
        const SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.6,
            color: AppTheme.primary,
            backgroundColor: Color(0x12A40D22),
            strokeCap: StrokeCap.round,
          ),
        ),
      ],
    );
  }
}
