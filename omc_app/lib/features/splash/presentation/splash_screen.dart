import 'dart:math' as math;

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
    final nextLocation = authState.status == AuthStatus.authenticated ? '/home' : '/login';

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
    return LayoutBuilder(
      builder: (context, constraints) {
        final logoSize = math.max(104.0, math.min(152.0, constraints.biggest.shortestSide * 0.42));
        final spacer = math.max(16.0, math.min(28.0, constraints.biggest.shortestSide * 0.08));

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _BrandMark(size: logoSize),
              SizedBox(height: spacer),
              const Text(
                'OMC House',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Premium business operations, simplified.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: AppTheme.textSecondary,
                ),
              ),
              SizedBox(height: spacer),
              const SizedBox(
                width: 32,
                height: 32,
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
      },
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF9B1022), Color(0xFFD7263D)],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x1A9B1022), blurRadius: 28, offset: Offset(0, 14)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: size * 0.12,
            top: size * 0.12,
            child: Container(
              width: size * 0.22,
              height: size * 0.22,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(size * 0.06),
              ),
            ),
          ),
          Positioned(
            right: size * 0.12,
            bottom: size * 0.12,
            child: Container(
              width: size * 0.22,
              height: size * 0.22,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(size * 0.06),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'OMC',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size * 0.22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -1.1,
                  ),
                ),
                SizedBox(height: size * 0.03),
                Container(
                  width: size * 0.34,
                  height: size * 0.035,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
