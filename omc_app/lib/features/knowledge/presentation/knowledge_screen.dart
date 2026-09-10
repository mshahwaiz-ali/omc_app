import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
import '../../../app/theme.dart';
import '../../../core/diagnostics/omc_widget_keys.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/app_state.dart';
import '../../../core/widgets/omc_premium.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_list_header.dart';
import '../data/knowledge_article.dart';
import '../data/knowledge_repository.dart';

class KnowledgeScreen extends ConsumerWidget {
  const KnowledgeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final articlesState = ref.watch(knowledgeArticlesProvider);

    return Scaffold(
      key: OmcWidgetKeys.knowledgeScreen,
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final inset = AppLayout.pageInsetFor(constraints.maxWidth);
            final horizontal = constraints.maxWidth >
                    AppLayout.generalMaxWidth + inset * 2
                ? (constraints.maxWidth - AppLayout.generalMaxWidth) / 2
                : inset;

            return articlesState.when(
              loading: () => _KnowledgeLoadingView(horizontal: horizontal),
              error: (error, _) => ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  AppSpacing.lg,
                  horizontal,
                  AppSpacing.xl,
                ),
                children: [
                  AppErrorState.fromError(
                    error: error,
                    fallbackTitle: 'Knowledge is unavailable',
                    fallbackMessage: 'OMC updates could not be loaded right now.',
                    onRetry: () => ref.invalidate(knowledgeArticlesProvider),
                  ),
                ],
              ),
              data: (articles) {
                if (articles.isEmpty) {
                  return _KnowledgeEmptyState(
                    horizontal: horizontal,
                    title: 'No published updates yet',
                    message:
                        'OMC knowledge articles and news will appear here when content is published.',
                    onRetry: () => ref.invalidate(knowledgeArticlesProvider),
                  );
                }

                final featured = articles.firstWhere(
                  (article) => article.isFeatured,
                  orElse: () => articles.first,
                );

                return RefreshIndicator.adaptive(
                  onRefresh: () async => ref.refresh(knowledgeArticlesProvider),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    padding: EdgeInsets.fromLTRB(
                      horizontal,
                      AppSpacing.sm,
                      horizontal,
                      AppSpacing.xxl,
                    ),
                    children: [
                      const PremiumListHeader(
                        icon: Icons.auto_stories_outlined,
                        title: 'Knowledge & news',
                        subtitle:
                            'Tax, FBR, compliance and practical OMC guidance.',
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const _SectionHeader(
                        title: 'Featured',
                        subtitle: 'A highlighted update from the current feed.',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _FeaturedArticleCard(article: featured),
                      const SizedBox(height: AppSpacing.xxl),
                      const _SectionHeader(
                        title: 'Latest updates',
                        subtitle:
                            'Published items remain in the order supplied by the backend.',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      PremiumCard(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xxs,
                        ),
                        child: Column(
                          children: [
                            for (
                              var index = 0;
                              index < articles.length;
                              index++
                            ) ...[
                              _KnowledgeArticleRow(article: articles[index]),
                              if (index != articles.length - 1)
                                const Divider(height: 1),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _FeaturedArticleCard extends StatelessWidget {
  const _FeaturedArticleCard({required this.article});

  final KnowledgeArticle article;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = article.summary.trim();
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.45;
    return PremiumCard(
      padding: EdgeInsets.zero,
      onTap: () =>
          context.push('/knowledge/${Uri.encodeComponent(article.id)}'),
      semanticLabel: 'Featured article, ${article.title}',
      semanticHint: 'Open article',
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                _MetaPill(label: _labelForType(article.type)),
                if (article.publishedAtLabel?.trim().isNotEmpty == true)
                  _MetaPill(label: article.publishedAtLabel!.trim()),
                if (article.category?.trim().isNotEmpty == true)
                  _MetaPill(label: article.category!.trim()),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              article.title,
              softWrap: true,
              style: theme.textTheme.titleLarge?.copyWith(
                color: AppTheme.textPrimary,
              ),
            ),
            if (summary.isNotEmpty && summary != '-') ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                summary,
                maxLines: largeText ? null : 3,
                overflow:
                    largeText ? TextOverflow.visible : TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: [
                Text(
                  'Read article',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: theme.colorScheme.primary,
                  size: 20,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _KnowledgeArticleRow extends StatelessWidget {
  const _KnowledgeArticleRow({required this.article});

  final KnowledgeArticle article;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final summary = article.summary.trim();
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.45;
    final metadata = <String>[
      _labelForType(article.type),
      if (article.publishedAtLabel?.trim().isNotEmpty == true)
        article.publishedAtLabel!.trim(),
    ];

    return InkWell(
      onTap: () =>
          context.push('/knowledge/${Uri.encodeComponent(article.id)}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OmcIconBadge(
              icon: _iconForType(article.type),
              color: AppTheme.textSecondary,
              size: AppTouchTarget.minimum,
              iconSize: 20,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    softWrap: true,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    metadata.join(' · '),
                    softWrap: true,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  if (summary.isNotEmpty && summary != '-') ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      summary,
                      maxLines: largeText ? null : 2,
                      overflow: largeText
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.xs),
              child: Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(title, style: theme.textTheme.titleLarge),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppTheme.processingSoft,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        label,
        softWrap: true,
        style: theme.textTheme.labelMedium?.copyWith(
          color: AppTheme.processing,
        ),
      ),
    );
  }
}

class _KnowledgeLoadingView extends StatelessWidget {
  const _KnowledgeLoadingView({required this.horizontal});

  final double horizontal;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        horizontal,
        AppSpacing.lg,
        horizontal,
        AppSpacing.xxl,
      ),
      children: const [
        AppSkeleton(height: 72, radius: AppRadius.card),
        SizedBox(height: AppSpacing.xl),
        AppSkeleton(height: 190, radius: AppRadius.card),
        SizedBox(height: AppSpacing.xxl),
        AppSkeleton(height: 260, radius: AppRadius.card),
      ],
    );
  }
}

class _KnowledgeEmptyState extends StatelessWidget {
  const _KnowledgeEmptyState({
    required this.horizontal,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final double horizontal;
  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        horizontal,
        AppSpacing.xl,
        horizontal,
        AppSpacing.xl,
      ),
      children: [
        PremiumCard(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            children: [
              const OmcIconBadge(
                icon: Icons.menu_book_outlined,
                color: AppTheme.textSecondary,
                size: AppTouchTarget.minimum,
                iconSize: 24,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

IconData _iconForType(KnowledgeArticleType type) {
  switch (type) {
    case KnowledgeArticleType.news:
      return Icons.newspaper_rounded;
    case KnowledgeArticleType.update:
      return Icons.campaign_outlined;
    case KnowledgeArticleType.guide:
      return Icons.menu_book_outlined;
    case KnowledgeArticleType.article:
      return Icons.article_outlined;
  }
}

String _labelForType(KnowledgeArticleType type) {
  switch (type) {
    case KnowledgeArticleType.news:
      return 'News';
    case KnowledgeArticleType.update:
      return 'Update';
    case KnowledgeArticleType.guide:
      return 'Guide';
    case KnowledgeArticleType.article:
      return 'Article';
  }
}
