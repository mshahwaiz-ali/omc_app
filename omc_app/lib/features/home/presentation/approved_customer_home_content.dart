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
              const SizedBox(height: AppSpacing.xxl),
              const OmcSectionHeader(
                title: 'Featured for you',
                subtitle: 'Important OMC updates and highlights.',
              ),
              const SizedBox(height: AppSpacing.sm),
              HomeFeaturedCarousel(
                banners: content.featuredBanners,
                onBannerTap: onBannerTap,
              ),
            ],
            if (content.taxBusinessUpdates.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xxl),
              const OmcSectionHeader(
                title: 'Tax & business updates',
                subtitle: 'Useful changes, alerts and OMC announcements.',
              ),
              const SizedBox(height: AppSpacing.sm),
              HomeContentRail(
                items: content.taxBusinessUpdates,
                padding: EdgeInsets.zero,
                onTap: onContentTap,
              ),
            ],
            if (content.learnGrow.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xxl),
              const OmcSectionHeader(
                title: 'Learn & grow',
                subtitle: 'Short guides to help you make better decisions.',
              ),
              const SizedBox(height: AppSpacing.sm),
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
        SizedBox(height: AppSpacing.xxl),
        OmcSectionHeader(
          title: 'Latest from OMC',
          subtitle: 'Loading useful updates for you.',
        ),
        SizedBox(height: AppSpacing.sm),
        AppSkeleton(height: 148, radius: AppRadius.card),
      ],
    );
  }
}

class _HomeContentError extends StatelessWidget {
  const _HomeContentError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final stackAction = textScale >= 1.45;

    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Updates unavailable',
          style: theme.textTheme.titleMedium?.copyWith(
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          'Your service dashboard is still available. You can retry OMC updates separately.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.xxl),
        PremiumCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: stackAction
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const OmcIconBadge(
                          icon: Icons.wifi_off_rounded,
                          color: OmcPremium.system,
                          size: 48,
                          iconSize: 20,
                          radius: AppRadius.control,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(child: copy),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    OutlinedButton(
                      onPressed: onRetry,
                      child: const Text('Retry'),
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const OmcIconBadge(
                      icon: Icons.wifi_off_rounded,
                      color: OmcPremium.system,
                      size: 48,
                      iconSize: 20,
                      radius: AppRadius.control,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: copy),
                    const SizedBox(width: AppSpacing.xs),
                    TextButton(onPressed: onRetry, child: const Text('Retry')),
                  ],
                ),
        ),
      ],
    );
  }
}
