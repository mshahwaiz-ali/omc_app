import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/premium_card.dart';
import '../data/knowledge_article.dart';
import '../data/knowledge_repository.dart';

class KnowledgeDetailScreen extends ConsumerWidget {
  const KnowledgeDetailScreen({required this.articleId, super.key});

  final String articleId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final articleState = ref.watch(knowledgeArticleDetailProvider(articleId));

    return Scaffold(
      appBar: AppBar(title: const Text('Knowledge')),
      body: SafeArea(
        child: articleState.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => _KnowledgeDetailUnavailable(
            onRetry: () =>
                ref.invalidate(knowledgeArticleDetailProvider(articleId)),
          ),
          data: (article) {
            if (article == null) {
              return _KnowledgeDetailUnavailable(
                onRetry: () =>
                    ref.invalidate(knowledgeArticleDetailProvider(articleId)),
              );
            }

            return ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                PremiumCard(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ArticleMetaRow(article: article),
                      const SizedBox(height: 16),
                      Text(
                        article.title,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 26,
                          height: 1.12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        article.summary,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 14,
                          height: 1.45,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                PremiumCard(
                  padding: const EdgeInsets.all(22),
                  child: Text(
                    article.body?.trim().isNotEmpty == true
                        ? article.body!.trim()
                        : article.summary,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      height: 1.6,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ArticleMetaRow extends StatelessWidget {
  const _ArticleMetaRow({required this.article});

  final KnowledgeArticle article;

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (article.category != null) article.category!,
      if (article.publishedAtLabel != null) article.publishedAtLabel!,
      if (article.author != null) article.author!,
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _MetaChip(label: _typeLabel(article.type)),
        for (final item in meta) _MetaChip(label: item),
      ],
    );
  }

  String _typeLabel(KnowledgeArticleType type) {
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
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppTheme.primaryRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.primaryRed,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _KnowledgeDetailUnavailable extends StatelessWidget {
  const _KnowledgeDetailUnavailable({required this.onRetry});

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
                  Icons.article_outlined,
                  color: AppTheme.primaryRed,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Article unavailable',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This knowledge item could not be loaded from the backend.',
                textAlign: TextAlign.center,
                style: TextStyle(
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
