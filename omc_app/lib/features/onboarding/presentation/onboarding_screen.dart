import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/core_providers.dart';
import '../../../app/theme.dart';
import '../../../core/config/api_config.dart';
import '../../../core/widgets/omc_logo.dart';
import '../../../core/widgets/premium_card.dart';
import '../../auth/application/auth_controller.dart';
import '../data/onboarding_repository.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _index = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _markCompleteAndGo(String route) async {
    final preferences = await ref.read(preferencesServiceProvider.future);
    await preferences.setHasCompletedOnboarding(true);

    if (!mounted) return;
    context.go(route);
  }

  Future<void> _continueAsGuest() async {
    final preferences = await ref.read(preferencesServiceProvider.future);
    await preferences.setHasCompletedOnboarding(true);
    await ref.read(authControllerProvider.notifier).continueAsGuest();

    if (!mounted) return;
    context.go('/home');
  }

  void _next(List<OnboardingSlide> slides) {
    if (_index >= slides.length - 1) {
      _markCompleteAndGo('/login');
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final slidesState = ref.watch(onboardingSlidesProvider);
    final slides = slidesState.asData?.value ?? OnboardingSlide.fallbackSlides;
    final isLast = _index >= slides.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                children: [
                  Row(
                    children: [
                      const OmcLogo.full(width: 128, height: 46),
                      const Spacer(),
                      TextButton(
                        onPressed: () => _markCompleteAndGo('/login'),
                        child: const Text('Skip'),
                      ),
                    ],
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      itemCount: slides.length,
                      onPageChanged: (value) {
                        setState(() {
                          _index = value;
                        });
                      },
                      itemBuilder: (context, index) {
                        return _OnboardingSlideView(slide: slides[index]);
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  _PageDots(count: slides.length, index: _index),
                  const SizedBox(height: 18),
                  if (isLast) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _markCompleteAndGo('/login'),
                            icon: const Icon(Icons.login_rounded),
                            label: const Text('Login'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _markCompleteAndGo('/signup'),
                            icon: const Icon(Icons.person_add_alt_1_rounded),
                            label: const Text('Create Account'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextButton.icon(
                      onPressed: _continueAsGuest,
                      icon: const Icon(Icons.explore_outlined),
                      label: const Text('Continue as Guest'),
                    ),
                  ] else
                    ElevatedButton.icon(
                      onPressed: () => _next(slides),
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: const Text('Next'),
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

class _OnboardingSlideView extends StatelessWidget {
  const _OnboardingSlideView({required this.slide});

  final OnboardingSlide slide;

  @override
  Widget build(BuildContext context) {
    final accent = _parseColor(slide.accentColor);

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: PremiumCard(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: _SlideImage(slide: slide, accent: accent),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    slide.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 30,
                      height: 1.08,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    slide.subtitle.isNotEmpty
                        ? slide.subtitle
                        : slide.description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 15.5,
                      height: 1.45,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (slide.description.isNotEmpty &&
                      slide.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      slide.description,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF8491A5),
                        fontSize: 13.5,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (slide.benefits.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final benefit in slide.benefits)
                          _BenefitChip(label: benefit, color: accent),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _parseColor(String value) {
    final hex = value.replaceAll('#', '').trim();
    if (hex.length == 6) {
      final parsed = int.tryParse('FF$hex', radix: 16);
      if (parsed != null) return Color(parsed);
    }
    return AppTheme.primary;
  }
}

class _SlideImage extends StatelessWidget {
  const _SlideImage({required this.slide, required this.accent});

  final OnboardingSlide slide;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final imageUrl = slide.imageUrl;

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 280),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: accent.withValues(alpha: 0.14)),
      ),
      padding: const EdgeInsets.all(24),
      child: imageUrl == null || imageUrl.isEmpty
          ? Image.asset(slide.assetPath, fit: BoxFit.contain)
          : Image.network(
              _absoluteUrl(imageUrl),
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) {
                return Image.asset(slide.assetPath, fit: BoxFit.contain);
              },
            ),
    );
  }

  String _absoluteUrl(String value) {
    if (value.startsWith('http://') || value.startsWith('https://')) {
      return value;
    }
    if (value.startsWith('/')) return '${ApiConfig.currentBaseUrl}$value';
    return '${ApiConfig.currentBaseUrl}/$value';
  }
}

class _BenefitChip extends StatelessWidget {
  const _BenefitChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_rounded, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: i == index ? 28 : 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: i == index ? AppTheme.primary : const Color(0xFFD7DEE8),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
      ],
    );
  }
}
