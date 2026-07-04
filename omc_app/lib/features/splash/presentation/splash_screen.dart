import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
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
    _resolveSession();
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
      backgroundColor: AppTheme.primaryRed,
      body: SafeArea(
        child: Center(
          child: Text(
            'OMC',
            style: TextStyle(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}
