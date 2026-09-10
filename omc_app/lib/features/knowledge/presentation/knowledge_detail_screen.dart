import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/design_tokens.dart';
import '../../../app/theme.dart';
import '../../../core/config/api_config.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/app_back_header.dart';
import '../../../core/widgets/app_skeleton.dart';
import '../../../core/widgets/app_state.dart';
import '../../../core/widgets/omc_premium.dart';
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
      backgroundColor: AppTheme.background,
      appBar: const AppBackHeader(title: 'Knowledge'),
      body: SafeArea(
        child: articleState.when(
          loading: () => const _KnowledgeDetailLoadingView(),
          error: (error, _) => OmcPagePadding(
            topPadding: 24,
            bottomPadding: 28,
            child: AppErrorState.fromError(
              error: error,
              fallbackTitle: 'Article unavailable',
              fallbackMessage:
                  'This knowledge item could not be loaded right now.',
              onRetry: () =>
                  ref.invalidate(knowledgeArticleDetailProvider(articleId)),
            ),
          ),
          data: (article) {
            if (article == null) {
              return const OmcPagePadding(
                topPadding: 24,
                bottomPadding: 28,
                child: AppEmptyState(
                  icon: Icons.article_outlined,
                  title: 'Article unavailable',
                  message:
                      'This article may have been removed or is no longer available.',
                ),
              );
            }

            final externalUri = _resolvedArticleUri(article.externalUrl);
            final body = article.body?.trim().isNotEmpty == true
                ? article.body!.trim()
                : article.summary.trim();
            final summary = article.summary.trim();

            return LayoutBuilder(
              builder: (context, constraints) {
                final inset = AppLayout.pageInsetFor(constraints.maxWidth);
                return ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(inset, 12, inset, 36),
                  children: [
                    Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(
                          maxWidth: AppLayout.readingMaxWidth,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _ArticleMetaRow(article: article),
                            const SizedBox(height: 14),
                            Semantics(
                              header: true,
                              child: Text(
                                article.title,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 28,
                                  height: 1.2,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (summary.isNotEmpty && summary != '-') ...[
                              const SizedBox(height: 14),
                              Text(
                                summary,
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 16,
                                  height: 1.5,
                                ),
                              ),
                            ],
                            const SizedBox(height: 22),
                            if (body.isNotEmpty && body != '-')
                              SelectableText(
                                body,
                                style: const TextStyle(
                                  color: AppTheme.textPrimary,
                                  fontSize: 17,
                                  height: 1.6,
                                  fontWeight: FontWeight.w400,
                                ),
                              )
                            else
                              const PremiumCard(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  'This article does not include additional reading content yet.',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 15,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            if (externalUri != null) ...[
                              const SizedBox(height: 24),
                              FilledButton.icon(
                                onPressed: () =>
                                    _openExternalArticle(context, externalUri),
                                icon: const Icon(Icons.open_in_new_rounded),
                                label: const Text('Open full article'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
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
  if (parsedUri != null && parsedUri.hasScheme) {
    return _isAllowedArticleScheme(parsedUri.scheme) ? parsedUri : null;
  }

  final resolved = cleanValue.startsWith('/')
      ? Uri.tryParse('${ApiConfig.baseUrl}$cleanValue')
      : Uri.tryParse('${ApiConfig.baseUrl}/$cleanValue');

  if (resolved == null || !_isAllowedArticleScheme(resolved.scheme)) {
    return null;
  }
  return resolved;
}

bool _isAllowedArticleScheme(String scheme) {
  final normalized = scheme.toLowerCase();
  return normalized == 'https' || normalized == 'http';
}

Future<void> _openExternalArticle(BuildContext context, Uri uri) async {
  final messenger = ScaffoldMessenger.of(context);

  if (!_isAllowedArticleScheme(uri.scheme)) {
    messenger.showSnackBar(
      const SnackBar(content: Text('This article link is not supported.')),
    );
    return;
  }

  try {
    final canOpen = await canLaunchUrl(uri);
    final opened = canOpen
        ? await launchUrl(uri, mode: LaunchMode.externalApplication)
        : false;

    if (!context.mounted) return;
    if (!opened) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Article link could not be opened right now.'),
        ),
      );
    }
  } catch (error) {
    if (!context.mounted) return;
    final failure = AppFailureClassifier.classify(
      error,
      fallbackTitle: 'Article unavailable',
      fallbackMessage: 'Article link could not be opened right now.',
    );
    messenger.showSnackBar(SnackBar(content: Text(failure.message)));
  }
}

class _ArticleMetaRow extends StatelessWidget {
  const _ArticleMetaRow({required this.article});

  final KnowledgeArticle article;

  @override
  Widget build(BuildContext context) {
    final meta = <String>[
      _typeLabel(article.type),
      if (article.publishedAtLabel?.trim().isNotEmpty == true)
        article.publishedAtLabel!.trim(),
      if (article.category?.trim().isNotEmpty == true) article.category!.trim(),
      if (article.author?.trim().isNotEmpty == true) article.author!.trim(),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [for (final item in meta) _MetaChip(label: item)],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

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

class _KnowledgeDetailLoadingView extends StatelessWidget {
  const _KnowledgeDetailLoadingView();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final inset = AppLayout.pageInsetFor(constraints.maxWidth);
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(inset, 12, inset, 28),
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: AppLayout.readingMaxWidth,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppSkeleton(height: 32, radius: 16),
                    SizedBox(height: 14),
                    AppSkeleton(height: 88, radius: 16),
                    SizedBox(height: 18),
                    AppSkeleton(height: 320, radius: 16),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
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
