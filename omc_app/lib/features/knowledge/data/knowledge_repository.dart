import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/frappe_client.dart';
import 'knowledge_article.dart';

final knowledgeRepositoryProvider = Provider<KnowledgeRepository>((ref) {
  final frappeClient = ref.watch(frappeClientProvider);

  return KnowledgeRepository(frappeClient: frappeClient);
});

final knowledgeArticlesProvider = FutureProvider<List<KnowledgeArticle>>((
  ref,
) async {
  final repository = ref.watch(knowledgeRepositoryProvider);
  return repository.fetchArticles();
});

final knowledgeArticleDetailProvider =
    FutureProvider.family<KnowledgeArticle?, String>((ref, articleId) {
      final repository = ref.watch(knowledgeRepositoryProvider);

      return repository.fetchArticleDetail(articleId);
    });

class KnowledgeRepository {
  const KnowledgeRepository({required this.frappeClient});

  final FrappeClient frappeClient;

  Future<List<KnowledgeArticle>> fetchArticles() async {
    try {
      final response = await frappeClient.getMethod(ApiConfig.knowledgeMethod);
      return _mapArticlesResponse(response);
    } on ApiError {
      return const [];
    } catch (_) {
      return const [];
    }
  }

  Future<KnowledgeArticle?> fetchArticleDetail(String articleId) async {
    final cleanArticleId = articleId.trim();
    if (cleanArticleId.isEmpty) return null;

    try {
      final response = await frappeClient.getMethod(
        ApiConfig.knowledgeDetailMethod,
        queryParameters: {'article_id': cleanArticleId, 'name': cleanArticleId},
      );

      return _mapArticleDetailResponse(response);
    } on ApiError {
      return null;
    } catch (_) {
      return null;
    }
  }

  List<KnowledgeArticle> _mapArticlesResponse(Map<String, dynamic>? data) {
    if (data == null) return const [];

    final message = data['message'];
    final rawArticles = message is List
        ? message
        : message is Map<String, dynamic>
        ? message['articles'] ?? message['knowledge'] ?? message['news']
        : data['articles'] ?? data['knowledge'] ?? data['news'];

    if (rawArticles is! List) return const [];

    return rawArticles
        .whereType<Map<String, dynamic>>()
        .map(_mapArticle)
        .toList(growable: false);
  }

  KnowledgeArticle? _mapArticleDetailResponse(Map<String, dynamic>? data) {
    if (data == null) return null;

    final message = data['message'];
    final rawArticle = message is Map<String, dynamic>
        ? message['article'] ?? message['data'] ?? message['item'] ?? message
        : data['article'] ?? data['data'] ?? data['item'];

    if (rawArticle is! Map<String, dynamic>) return null;

    return _mapArticle(rawArticle);
  }

  KnowledgeArticle _mapArticle(Map<String, dynamic> json) {
    final title = _stringValue(
      json['title'] ?? json['subject'] ?? json['name'],
    );

    return KnowledgeArticle(
      id: _stringValue(json['id'] ?? json['name'] ?? json['article_id']),
      title: title,
      summary: _stringValue(
        json['summary'] ??
            json['excerpt'] ??
            json['description'] ??
            json['intro'] ??
            title,
      ),
      body: _nullableString(
        json['body'] ?? json['content'] ?? json['details'] ?? json['article'],
      ),
      type: _typeFromValue(json['type'] ?? json['article_type']),
      category: _nullableString(json['category'] ?? json['topic']),
      publishedAtLabel: _nullableString(
        json['published_at_label'] ??
            json['published_on'] ??
            json['creation'] ??
            json['created_at'],
      ),
      author: _nullableString(json['author'] ?? json['owner']),
      externalUrl: _nullableString(json['external_url'] ?? json['url']),
      isFeatured: json['is_featured'] == true || json['featured'] == true,
    );
  }

  KnowledgeArticleType _typeFromValue(dynamic value) {
    final type = value?.toString().trim().toLowerCase() ?? '';

    if (type.contains('news')) return KnowledgeArticleType.news;
    if (type.contains('update')) return KnowledgeArticleType.update;
    if (type.contains('guide') || type.contains('help')) {
      return KnowledgeArticleType.guide;
    }

    return KnowledgeArticleType.article;
  }

  String _stringValue(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? '-' : text;
  }

  String? _nullableString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }
}
