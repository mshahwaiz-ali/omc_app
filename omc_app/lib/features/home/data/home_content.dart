enum HomeBannerActionType { none, route, knowledgeArticle, service, externalUrl }

class HomeContent {
  const HomeContent({
    required this.audience,
    required this.featuredBanners,
    required this.taxBusinessUpdates,
    required this.learnGrow,
  });

  const HomeContent.empty()
      : audience = 'All',
        featuredBanners = const [],
        taxBusinessUpdates = const [],
        learnGrow = const [];

  final String audience;
  final List<HomeBanner> featuredBanners;
  final List<HomeContentCard> taxBusinessUpdates;
  final List<HomeContentCard> learnGrow;
}

class HomeBannerAction {
  const HomeBannerAction({
    required this.type,
    required this.target,
    required this.label,
  });

  const HomeBannerAction.none()
      : type = HomeBannerActionType.none,
        target = '',
        label = '';

  final HomeBannerActionType type;
  final String target;
  final String label;
}

class HomeBanner {
  const HomeBanner({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.contentType,
    required this.action,
    this.imageUrl,
    this.priority = 0,
    this.sortOrder = 0,
  });

  final String id;
  final String title;
  final String subtitle;
  final String badge;
  final String contentType;
  final String? imageUrl;
  final HomeBannerAction action;
  final int priority;
  final int sortOrder;
}

class HomeContentCard {
  const HomeContentCard({
    required this.id,
    required this.title,
    required this.summary,
    required this.category,
    required this.contentType,
    required this.detailType,
    this.imageUrl,
    this.urgency,
    this.publishedOn,
    this.effectiveDate,
    this.mobileRoute,
    this.isFeatured = false,
    this.priority = 0,
    this.sortOrder = 0,
    this.readTimeMinutes = 0,
  });

  final String id;
  final String title;
  final String summary;
  final String category;
  final String contentType;
  final String detailType;
  final String? imageUrl;
  final String? urgency;
  final String? publishedOn;
  final String? effectiveDate;
  final String? mobileRoute;
  final bool isFeatured;
  final int priority;
  final int sortOrder;
  final int readTimeMinutes;
}
