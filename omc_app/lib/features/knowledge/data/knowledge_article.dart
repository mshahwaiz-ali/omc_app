enum KnowledgeArticleType { article, news, update, guide }

class KnowledgeArticle {
  const KnowledgeArticle({
    required this.id,
    required this.title,
    required this.summary,
    required this.type,
    this.body,
    this.category,
    this.publishedAtLabel,
    this.author,
    this.externalUrl,
    this.isFeatured = false,
  });

  final String id;
  final String title;
  final String summary;
  final String? body;
  final KnowledgeArticleType type;
  final String? category;
  final String? publishedAtLabel;
  final String? author;
  final String? externalUrl;
  final bool isFeatured;
}
