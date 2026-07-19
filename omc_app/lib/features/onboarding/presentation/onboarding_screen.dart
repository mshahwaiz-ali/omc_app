import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/core_providers.dart';
import '../../../app/theme.dart';
import '../../../core/config/api_config.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/omc_logo.dart';
import '../data/onboarding_repository.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _index = 0;
  bool _isFinishing = false;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_isFinishing) return;

    setState(() => _isFinishing = true);
    try {
      final preferences = await ref.read(preferencesServiceProvider.future);
      await preferences.setHasCompletedOnboarding(true);
      if (!mounted) return;
      context.go('/login');
    } catch (error) {
      if (!mounted) return;
      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Could not continue',
        fallbackMessage:
            'Onboarding could not be completed right now. Please try again.',
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
      setState(() => _isFinishing = false);
    }
  }

  void _next(List<OnboardingSlide> slides) {
    if (_index >= slides.length - 1) {
      _finish();
      return;
    }

    _pageController.nextPage(
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final slidesState = ref.watch(onboardingSlidesProvider);
    final slides = slidesState.asData?.value ?? OnboardingSlide.fallbackSlides;
    final isLast = _index >= slides.length - 1;

    return Scaffold(
      backgroundColor: const Color(0xFFFBFCFE),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 22),
              child: Column(
                children: [
                  Row(
                    children: [
                      const OmcLogo.symbol(size: 42, borderRadius: 0),
                      const Spacer(),
                      TextButton(
                        onPressed: _isFinishing ? null : _finish,
                        child: const Text('Skip'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      physics: const BouncingScrollPhysics(),
                      itemCount: slides.length,
                      onPageChanged: (value) => setState(() => _index = value),
                      itemBuilder: (context, index) {
                        return _OnboardingSlideView(slide: slides[index]);
                      },
                    ),
                  ),
                  if (slides.length > 1) ...[
                    const SizedBox(height: 12),
                    _PageDots(count: slides.length, index: _index),
                  ],
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isFinishing ? null : () => _next(slides),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (_isFinishing)
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          else ...[
                            Text(isLast ? 'Get started' : 'Continue'),
                            const SizedBox(width: 10),
                            const Icon(Icons.arrow_forward_rounded, size: 20),
                          ],
                        ],
                      ),
                    ),
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
    final supportingText = slide.subtitle.isNotEmpty
        ? slide.subtitle
        : slide.description;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Column(
          children: [
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
                child: _SlideImage(slide: slide, accent: accent),
              ),
            ),
            Expanded(
              flex: 4,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      Text(
                        slide.title,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 31,
                          height: 1.08,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.7,
                        ),
                      ),
                      if (supportingText.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(
                          supportingText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 15.5,
                            height: 1.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
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
    final imageUrl = _resolvedImageUrl(slide.imageUrl);

    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(36),
              gradient: RadialGradient(
                center: const Alignment(0, -0.1),
                radius: 0.95,
                colors: [
                  accent.withValues(alpha: 0.16),
                  accent.withValues(alpha: 0.035),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(26),
          child: imageUrl == null
              ? Image.asset(slide.assetPath, fit: BoxFit.contain)
              : Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, _, _) {
                    return Image.asset(slide.assetPath, fit: BoxFit.contain);
                  },
                ),
        ),
      ],
    );
  }

  String? _resolvedImageUrl(String? value) {
    final clean = value?.trim();
    if (clean == null || clean.isEmpty) return null;

    final parsed = Uri.tryParse(clean);
    if (parsed != null && parsed.hasScheme) {
      return _isAllowedWebScheme(parsed.scheme) ? parsed.toString() : null;
    }

    final resolved = clean.startsWith('/')
        ? Uri.tryParse('${ApiConfig.currentBaseUrl}$clean')
        : Uri.tryParse('${ApiConfig.currentBaseUrl}/$clean');
    if (resolved == null || !_isAllowedWebScheme(resolved.scheme)) return null;
    return resolved.toString();
  }

  bool _isAllowedWebScheme(String scheme) {
    final normalized = scheme.toLowerCase();
    return normalized == 'https' || normalized == 'http';
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
            width: i == index ? 26 : 8,
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
