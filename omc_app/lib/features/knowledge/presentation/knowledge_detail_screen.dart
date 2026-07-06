import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/api_error.dart';
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
          loading: () => const _KnowledgeDetailLoadingView(),
          error: (error, _) => _KnowledgeDetailUnavailable(
            message: _knowledgeDetailErrorMessage(error),
            onRetry: () =>
                ref.invalidate(knowledgeArticleDetailProvider(articleId)),
          ),
          data: (article) {
            if (article == null) {
              return _KnowledgeDetailUnavailable(
                message: 'This knowledge item could not be loaded right now.',
                onRetry: () =>
                    ref.invalidate(knowledgeArticleDetailProvider(articleId)),
              );
            }

            final externalUri = _resolvedArticleUri(article.externalUrl);

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Details',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
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
                    ],
                  ),
                ),
                if (externalUri != null) ...[
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () =>
                          _openExternalArticle(context, externalUri),
                      icon: const Icon(Icons.open_in_new_rounded),
                      label: const Text('Open full article'),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

Uri? _resolvedArticleUri(String? value) {
  final cleanValue = value?.trim();
  if (cleanValue == null || cleanValue.isEmpty) return null;

  final parsedUri = Uri.tryParse(cleanValue);
  if (parsedUri != null && parsedUri.hasScheme) return parsedUri;

  if (cleanValue.startsWith('/')) {
    return Uri.tryParse('${ApiConfig.baseUrl}$cleanValue');
  }

  return Uri.tryParse('${ApiConfig.baseUrl}/$cleanValue');
}

Future<void> _openExternalArticle(BuildContext context, Uri uri) async {
  final canOpen = await canLaunchUrl(uri);
  final opened = canOpen
      ? await launchUrl(uri, mode: LaunchMode.externalApplication)
      : false;

  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Article link could not be opened right now.'),
      ),
    );
  }
}

String _knowledgeDetailErrorMessage(Object error) {
  if (error is ApiError && error.message.trim().isNotEmpty) {
    return error.message.trim();
  }

  return 'This knowledge item could not be loaded right now.';
}

class _KnowledgeDetailLoadingView extends StatelessWidget {
  const _KnowledgeDetailLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        PremiumCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                children: List.generate(
                  3,
                  (index) => Container(
                    height: 28,
                    width: 74,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                height: 22,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                height: 14,
                width: 240,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        PremiumCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: List.generate(
              7,
              (index) => Container(
                margin: EdgeInsets.only(bottom: index == 6 ? 0 : 12),
                height: 12,
                width: index == 6 ? 180 : double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ),
        ),
      ],
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
  const _KnowledgeDetailUnavailable({
    required this.message,
    required this.onRetry,
  });

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
