import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
import '../../../app/providers/core_providers.dart';
import '../../../app/theme.dart';
import '../../../core/config/api_config.dart';
import '../../../core/diagnostics/omc_widget_keys.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/app_button.dart';
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
      duration: AppMotion.reducedMotion(context)
          ? Duration.zero
          : const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final slidesState = ref.watch(onboardingSlidesProvider);
    final slides = slidesState.asData?.value ?? OnboardingSlide.fallbackSlides;
    final isLast = _index >= slides.length - 1;

    return Scaffold(
      key: OmcWidgetKeys.onboardingScreen,
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: AppLayout.formMaxWidth),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppLayout.pageInsetFor(MediaQuery.sizeOf(context).width),
                12,
                AppLayout.pageInsetFor(MediaQuery.sizeOf(context).width),
                20,
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(
                            AppRadius.control,
                          ),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: const OmcLogo.symbol(size: 34, borderRadius: 0),
                      ),
                      const Spacer(),
                      TextButton(
                        key: OmcWidgetKeys.onboardingSkip,
                        onPressed: _isFinishing ? null : _finish,
                        child: const Text('Skip'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
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
                  const SizedBox(height: 10),
                  Semantics(
                    liveRegion: true,
                    label: 'Page ${_index + 1} of ${slides.length}',
                    child: ExcludeSemantics(
                      child: Column(
                        children: [
                          Text(
                            'Page ${_index + 1} of ${slides.length}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (slides.length > 1) ...[
                            const SizedBox(height: 8),
                            _PageDots(count: slides.length, index: _index),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppButton(
                    label: isLast ? 'Get started' : 'Continue',
                    icon: isLast
                        ? Icons.check_rounded
                        : Icons.arrow_forward_rounded,
                    isLoading: _isFinishing,
                    onPressed: _isFinishing ? null : () => _next(slides),
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
        final imageHeight = (constraints.maxHeight * 0.48)
            .clamp(140.0, 300.0)
            .toDouble();
        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: imageHeight,
                    width: double.infinity,
                    child: _SlideImage(slide: slide, accent: accent),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    slide.title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  if (supportingText.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(
                      supportingText,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
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

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppRadius.dialog),
        border: Border.all(color: accent.withValues(alpha: 0.12)),
      ),
      child: imageUrl == null
          ? Image.asset(slide.assetPath, fit: BoxFit.contain)
          : Image.network(
              imageUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) {
                return Image.asset(slide.assetPath, fit: BoxFit.contain);
              },
            ),
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
    final reducedMotion = AppMotion.reducedMotion(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: reducedMotion
                ? Duration.zero
                : const Duration(milliseconds: 180),
            width: i == index ? 24 : 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: i == index ? AppTheme.primary : AppTheme.border,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
      ],
    );
  }
}
