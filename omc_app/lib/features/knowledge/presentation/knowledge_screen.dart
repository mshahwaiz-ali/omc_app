import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/network/api_error.dart';
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
      body: SafeArea(
        child: articlesState.when(
          loading: () => const _KnowledgeLoadingView(),
          error: (error, _) => _KnowledgeEmptyState(
            title: 'Knowledge is unavailable',
            message: _knowledgeErrorMessage(error),
            onRetry: () => ref.invalidate(knowledgeArticlesProvider),
          ),
          data: (articles) {
            if (articles.isEmpty) {
              return _KnowledgeEmptyState(
                title: 'No updates yet',
                message:
                    'OMC knowledge articles and news will appear here when content is available.',
                onRetry: () => ref.invalidate(knowledgeArticlesProvider),
              );
            }

            final featuredArticles = articles
                .where((article) => article.isFeatured)
                .toList(growable: false);
            final visibleFeatured = featuredArticles.isNotEmpty
                ? featuredArticles.first
                : articles.first;

            return RefreshIndicator(
              onRefresh: () async => ref.refresh(knowledgeArticlesProvider),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                children: [
                  PremiumListHeader(
                    icon: Icons.auto_stories_outlined,
                    title: 'Knowledge & News',
                    subtitle:
                        'Tax insights, compliance guides, FBR updates and OMC announcements.',
                    metaLabel: '${articles.length} items',
                  ),
                  const SizedBox(height: 18),
                  _KnowledgeHeroCard(
                    article: visibleFeatured,
                    totalArticles: articles.length,
                    featuredCount: featuredArticles.length,
                  ),
                  const SizedBox(height: 18),
                  const _SectionHeader(
                    title: 'Latest updates',
                    subtitle:
                        'Fresh guides, tax updates and compliance notes from OMC.',
                  ),
                  const SizedBox(height: 12),
                  for (final article in articles) ...[
                    _KnowledgeArticleTile(article: article),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

String _knowledgeErrorMessage(Object error) {
  if (error is ApiError && error.message.trim().isNotEmpty) {
    return error.message.trim();
  }

  return 'OMC updates could not be loaded right now. Please try again.';
}

class _KnowledgeHeroCard extends StatelessWidget {
  const _KnowledgeHeroCard({
    required this.article,
    required this.totalArticles,
    required this.featuredCount,
  });

  final KnowledgeArticle article;
  final int totalArticles;
  final int featuredCount;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () =>
            context.push('/knowledge/${Uri.encodeComponent(article.id)}'),
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryRed.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(19),
                    ),
                    child: Icon(
                      _iconForType(article.type),
                      color: AppTheme.primaryRed,
                      size: 28,
                    ),
                  ),
                  const Spacer(),
                  _ArticleTypeChip(type: article.type),
                ],
              ),
              const SizedBox(height: 18),
              const Text(
                'Featured insight',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                article.title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 23,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                article.summary,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _KnowledgeStatPill(
                          icon: Icons.library_books_outlined,
                          label: '$totalArticles items',
                        ),
                        if (featuredCount > 0)
                          _KnowledgeStatPill(
                            icon: Icons.star_outline_rounded,
                            label: '$featuredCount featured',
                          ),
                        if (article.publishedAtLabel != null)
                          _KnowledgeStatPill(
                            icon: Icons.schedule_rounded,
                            label: article.publishedAtLabel!,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: AppTheme.primaryRed,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KnowledgeStatPill extends StatelessWidget {
  const _KnowledgeStatPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppTheme.textSecondary, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
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
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppTheme.primaryRed.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.auto_stories_outlined,
            color: AppTheme.primaryRed,
            size: 20,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _KnowledgeLoadingView extends StatelessWidget {
  const _KnowledgeLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        Container(
          height: 28,
          width: 210,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 14,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(height: 18),
        PremiumCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(19),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                height: 18,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                height: 12,
                width: 240,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ...List.generate(
          4,
          (index) => Padding(
            padding: EdgeInsets.only(bottom: index == 3 ? 0 : 12),
            child: PremiumCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          height: 12,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 10,
                          width: 170,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _KnowledgeArticleTile extends StatelessWidget {
  const _KnowledgeArticleTile({required this.article});

  final KnowledgeArticle article;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        onTap: () =>
            context.push('/knowledge/${Uri.encodeComponent(article.id)}'),
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  _iconForType(article.type),
                  color: AppTheme.primaryRed,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        height: 1.25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      article.summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (article.publishedAtLabel != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        article.publishedAtLabel!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.primaryRed,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textSecondary,
              ),
            ],
          ),
        ),
      ),
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

class _ArticleTypeChip extends StatelessWidget {
  const _ArticleTypeChip({required this.type});

  final KnowledgeArticleType type;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.primaryRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _labelForType(type),
        style: const TextStyle(
          color: AppTheme.primaryRed,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  String _labelForType(KnowledgeArticleType type) {
    switch (type) {
      case KnowledgeArticleType.news:
        return 'NEWS';
      case KnowledgeArticleType.update:
        return 'UPDATE';
      case KnowledgeArticleType.guide:
        return 'GUIDE';
      case KnowledgeArticleType.article:
        return 'ARTICLE';
    }
  }
}

class _KnowledgeEmptyState extends StatelessWidget {
  const _KnowledgeEmptyState({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      children: [
        PremiumCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.menu_book_outlined,
                  color: AppTheme.primaryRed,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
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
