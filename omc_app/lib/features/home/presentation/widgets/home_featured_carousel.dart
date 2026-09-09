import 'package:flutter/material.dart';

import '../../../../app/design_tokens.dart';
import '../../data/home_content.dart';

class HomeFeaturedCarousel extends StatefulWidget {
  const HomeFeaturedCarousel({
    required this.banners,
    required this.onBannerTap,
    super.key,
  });

  final List<HomeBanner> banners;
  final ValueChanged<HomeBanner> onBannerTap;

  @override
  State<HomeFeaturedCarousel> createState() => _HomeFeaturedCarouselState();
}

class _HomeFeaturedCarouselState extends State<HomeFeaturedCarousel> {
  late final PageController _controller;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 0.94);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.banners.isEmpty) return const SizedBox.shrink();

    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final indicatorDuration = AppMotion.durationFor(context, AppMotion.quick);

    if (textScale >= 1.5) {
      return Column(
        children: [
          for (var index = 0; index < widget.banners.length; index++) ...[
            _FeaturedBannerCard(
              banner: widget.banners[index],
              onTap: () => widget.onBannerTap(widget.banners[index]),
            ),
            if (index != widget.banners.length - 1)
              const SizedBox(height: AppSpacing.sm),
          ],
        ],
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 254,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.banners.length,
            onPageChanged: (value) => setState(() => _page = value),
            itemBuilder: (context, index) {
              final banner = widget.banners[index];
              return Padding(
                padding: EdgeInsets.only(
                  right: index == widget.banners.length - 1 ? 0 : AppSpacing.xs,
                ),
                child: _FeaturedBannerCard(
                  banner: banner,
                  onTap: () => widget.onBannerTap(banner),
                ),
              );
            },
          ),
        ),
        if (widget.banners.length > 1) ...[
          const SizedBox(height: AppSpacing.sm),
          Semantics(
            label: 'Featured item ${_page + 1} of ${widget.banners.length}',
            child: ExcludeSemantics(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.banners.length,
                  (index) => AnimatedContainer(
                    duration: indicatorDuration,
                    width: index == _page ? 24 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xxs,
                    ),
                    decoration: BoxDecoration(
                      color: index == _page
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(AppRadius.pill),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _FeaturedBannerCard extends StatelessWidget {
  const _FeaturedBannerCard({required this.banner, required this.onTap});

  final HomeBanner banner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasAction =
        banner.action.type != HomeBannerActionType.none &&
        banner.action.target.trim().isNotEmpty;
    final actionLabel = banner.action.label.trim().isEmpty
        ? 'Learn more'
        : banner.action.label.trim();
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final largeText = textScale >= 1.5;

    final image = banner.imageUrl != null
        ? Image.network(
            banner.imageUrl!,
            width: double.infinity,
            height: double.infinity,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                const _BannerImageFallback(),
          )
        : const _BannerImageFallback();

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (banner.badge.trim().isNotEmpty) ...[
          _BannerBadge(label: banner.badge.trim()),
          const SizedBox(height: AppSpacing.sm),
        ],
        Text(
          banner.title,
          softWrap: true,
          style: theme.textTheme.headlineSmall?.copyWith(
            color: Colors.white,
            height: 1.15,
          ),
        ),
        if (banner.subtitle.trim().isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            banner.subtitle.trim(),
            maxLines: largeText ? null : 3,
            overflow: largeText ? TextOverflow.visible : TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
        ],
        if (hasAction) ...[
          const SizedBox(height: AppSpacing.md),
          Container(
            constraints: const BoxConstraints(
              minHeight: AppTouchTarget.minimum,
            ),
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: AppSpacing.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  actionLabel,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ],
            ),
          ),
        ],
      ],
    );

    final cardBody = largeText
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 160, child: image),
              Container(
                color: const Color(0xFF111827),
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: content,
              ),
            ],
          )
        : Stack(
            fit: StackFit.expand,
            children: [
              image,
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      const Color(0xFF111827).withValues(alpha: 0.98),
                      const Color(0xFF111827).withValues(alpha: 0.84),
                      const Color(0xFF111827).withValues(alpha: 0.48),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: content,
                  ),
                ),
              ),
            ],
          );

    return Semantics(
      button: hasAction,
      label: banner.title,
      hint: hasAction ? actionLabel : null,
      child: Material(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(AppRadius.card),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: hasAction ? onTap : null,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: cardBody,
        ),
      ),
    );
  }
}

class _BannerBadge extends StatelessWidget {
  const _BannerBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BannerImageFallback extends StatelessWidget {
  const _BannerImageFallback();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
      ),
      child: const Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Icon(Icons.campaign_outlined, color: Colors.white54, size: 64),
        ),
      ),
    );
  }
}
