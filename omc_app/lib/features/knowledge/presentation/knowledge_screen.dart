import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
        child: articlesState.when(
          loading: () => const _KnowledgeLoadingView(),
          error: (error, _) => Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
            child: AppErrorState.fromError(
              error: error,
              fallbackTitle: 'Knowledge is unavailable',
              fallbackMessage: 'OMC updates could not be loaded right now.',
              onRetry: () => ref.invalidate(knowledgeArticlesProvider),
            ),
          ),
          data: (articles) {
            if (articles.isEmpty) {
              return _KnowledgeEmptyState(
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
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  const PremiumListHeader(
                    icon: Icons.auto_stories_outlined,
                    title: 'Knowledge & news',
                    subtitle:
                        'Tax, FBR, compliance and practical OMC guidance.',
                  ),
                  const SizedBox(height: 22),
                  const _SectionHeader(
                    title: 'Featured',
                    subtitle: 'A highlighted update from the current feed.',
                  ),
                  const SizedBox(height: 10),
                  _FeaturedArticleCard(article: featured),
                  const SizedBox(height: 26),
                  const _SectionHeader(
                    title: 'Latest updates',
                    subtitle:
                        'Published items remain in the order supplied by the backend.',
                  ),
                  const SizedBox(height: 10),
                  PremiumCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Column(
                      children: [
                        for (var index = 0; index < articles.length; index++) ...[
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
    final summary = article.summary.trim();
    return PremiumCard(
      padding: EdgeInsets.zero,
      onTap: () =>
          context.push('/knowledge/${Uri.encodeComponent(article.id)}'),
      semanticLabel: 'Featured article, ${article.title}',
      semanticHint: 'Open article',
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _MetaPill(label: _labelForType(article.type)),
                if (article.publishedAtLabel?.trim().isNotEmpty == true)
                  _MetaPill(label: article.publishedAtLabel!.trim()),
                if (article.category?.trim().isNotEmpty == true)
                  _MetaPill(label: article.category!.trim()),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              article.title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 21,
                height: 1.25,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (summary.isNotEmpty && summary != '-') ...[
              const SizedBox(height: 8),
              Text(
                summary,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 15,
                  height: 1.4,
                ),
              ),
            ],
            const SizedBox(height: 14),
            const Row(
              children: [
                Text(
                  'Read article',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(width: 6),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: AppTheme.textSecondary,
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
    final summary = article.summary.trim();
    final metadata = <String>[
      _labelForType(article.type),
      if (article.publishedAtLabel?.trim().isNotEmpty == true)
        article.publishedAtLabel!.trim(),
    ];

    return InkWell(
      onTap: () =>
          context.push('/knowledge/${Uri.encodeComponent(article.id)}'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OmcIconBadge(
              icon: _iconForType(article.type),
              color: AppTheme.textSecondary,
              size: 40,
              iconSize: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 17,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    metadata.join(' · '),
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                  if (summary.isNotEmpty && summary != '-') ...[
                    const SizedBox(height: 5),
                    Text(
                      summary,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Padding(
              padding: EdgeInsets.only(top: 8),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 21,
              height: 1.25,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 15,
            height: 1.4,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.processingSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.processing,
          fontSize: 13,
          height: 1.35,
        ),
      ),
    );
  }
}

class _KnowledgeLoadingView extends StatelessWidget {
  const _KnowledgeLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
      children: const [
        AppSkeleton(height: 72, radius: 16),
        SizedBox(height: 22),
        AppSkeleton(height: 190, radius: 16),
        SizedBox(height: 26),
        AppSkeleton(height: 260, radius: 16),
      ],
    );
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
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
      children: [
        PremiumCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const OmcIconBadge(
                icon: Icons.menu_book_outlined,
                color: AppTheme.textSecondary,
                size: 48,
                iconSize: 24,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 21,
                  height: 1.25,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 15,
                  height: 1.4,
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
