import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    await Future.wait<void>([
      ref.read(authControllerProvider.notifier).checkSession(),
      Future<void>.delayed(const Duration(milliseconds: 900)),
    ]);

    if (!mounted) return;

    final authState = ref.read(authControllerProvider);
    final nextLocation = authState.status == AuthStatus.authenticated
        ? '/home'
        : '/login';

    context.go(nextLocation);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: _SplashContent(),
        ),
      ),
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
        SizedBox(
          width: 190,
          height: 190,
          child: Center(
            child: Transform.scale(
              scale: 1.65,
              child: const OmcLogo.symbol(
                size: 150,
                borderRadius: 0,
              ),
            ),
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
    );
  }
}
