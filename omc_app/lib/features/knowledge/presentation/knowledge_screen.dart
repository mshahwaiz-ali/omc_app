import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/premium_card.dart';
import '../data/knowledge_article.dart';
import '../data/knowledge_repository.dart';

class KnowledgeScreen extends ConsumerWidget {
  const KnowledgeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final articlesState = ref.watch(knowledgeArticlesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Knowledge & News')),
      body: SafeArea(
        child: articlesState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
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
                    'OMC knowledge articles and news will appear here once the backend endpoint is ready.',
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
                  const Text(
                    'Knowledge & News',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tax insights, compliance guides, FBR updates and OMC announcements.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  _FeaturedArticleCard(article: visibleFeatured),
                  const SizedBox(height: 18),
                  const Text(
                    'Latest updates',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
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

  return 'We could not load OMC updates from the backend right now. Please try again.';
}

class _FeaturedArticleCard extends StatelessWidget {
  const _FeaturedArticleCard({required this.article});

  final KnowledgeArticle article;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(22),
      child: InkWell(
        onTap: () =>
            context.push('/knowledge/${Uri.encodeComponent(article.id)}'),
        borderRadius: BorderRadius.circular(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ArticleTypeChip(type: article.type),
            const SizedBox(height: 14),
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
                if (article.publishedAtLabel != null)
                  Expanded(
                    child: Text(
                      article.publishedAtLabel!,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: AppTheme.primaryRed,
                ),
              ],
            ),
          ],
        ),
      ),
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
      child: ListTile(
        onTap: () =>
            context.push('/knowledge/${Uri.encodeComponent(article.id)}'),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 12,
        ),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppTheme.primaryRed.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(
            _iconForType(article.type),
            color: AppTheme.primaryRed,
            size: 22,
          ),
        ),
        title: Text(
          article.title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(
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
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: Colors.grey.shade400,
        ),
      ),
    );
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
