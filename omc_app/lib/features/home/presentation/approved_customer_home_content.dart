part of 'approved_customer_home_view.dart';

class _CustomerHomeContentSections extends StatelessWidget {
  const _CustomerHomeContentSections({
    required this.contentAsync,
    required this.onBannerTap,
    required this.onContentTap,
    required this.onRetry,
  });

  final AsyncValue<HomeContent> contentAsync;
  final ValueChanged<HomeBanner> onBannerTap;
  final ValueChanged<HomeContentCard> onContentTap;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return contentAsync.when(
      loading: () => const _HomeContentLoading(),
      error: (_, _) => _HomeContentError(onRetry: onRetry),
      data: (content) {
        final hasContent =
            content.featuredBanners.isNotEmpty ||
            content.taxBusinessUpdates.isNotEmpty ||
            content.learnGrow.isNotEmpty;

        if (!hasContent) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (content.featuredBanners.isNotEmpty) ...[
              const SizedBox(height: 26),
              const OmcSectionHeader(
                title: 'Featured for you',
                subtitle: 'Important OMC updates and highlights.',
              ),
              const SizedBox(height: 12),
              HomeFeaturedCarousel(
                banners: content.featuredBanners,
                onBannerTap: onBannerTap,
              ),
            ],
            if (content.taxBusinessUpdates.isNotEmpty) ...[
              const SizedBox(height: 26),
              const OmcSectionHeader(
                title: 'Tax & business updates',
                subtitle: 'Useful changes, alerts and OMC announcements.',
              ),
              const SizedBox(height: 12),
              HomeContentRail(
                items: content.taxBusinessUpdates,
                padding: EdgeInsets.zero,
                onTap: onContentTap,
              ),
            ],
            if (content.learnGrow.isNotEmpty) ...[
              const SizedBox(height: 26),
              const OmcSectionHeader(
                title: 'Learn & grow',
                subtitle: 'Short guides to help you make better decisions.',
              ),
              const SizedBox(height: 12),
              HomeContentRail(
                items: content.learnGrow,
                padding: EdgeInsets.zero,
                onTap: onContentTap,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _HomeContentLoading extends StatelessWidget {
  const _HomeContentLoading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 26),
        OmcSectionHeader(
          title: 'Latest from OMC',
          subtitle: 'Loading useful updates for you.',
        ),
        SizedBox(height: 12),
        AppSkeleton(height: 148, radius: 22),
      ],
    );
  }
}

class _HomeContentError extends StatelessWidget {
  const _HomeContentError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 26),
        PremiumCard(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              const OmcIconBadge(
                icon: Icons.wifi_off_rounded,
                color: OmcPremium.system,
                size: 42,
                iconSize: 20,
                radius: 13,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Updates unavailable',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Your service dashboard is still available. You can retry OMC updates separately.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11.5,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        ),
      ],
    );
  }
}
