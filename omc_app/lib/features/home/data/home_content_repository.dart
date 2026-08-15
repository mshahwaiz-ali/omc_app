import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/frappe_client.dart';
import 'home_content.dart';

final homeContentRepositoryProvider = Provider<HomeContentRepository>((ref) {
  return HomeContentRepository(frappeClient: ref.watch(frappeClientProvider));
});

final homeContentProvider = FutureProvider<HomeContent>((ref) async {
  final repository = ref.watch(homeContentRepositoryProvider);
  return repository.fetchHomeContent();
});

class HomeContentRepository {
  const HomeContentRepository({required this.frappeClient});

  static const String _homeContentMethod =
      'omc_app.api.home_content.get_home_content';

  final FrappeClient frappeClient;

  Future<HomeContent> fetchHomeContent() async {
    try {
      final response = await frappeClient.getMethod(_homeContentMethod);
      return _mapResponse(response);
    } on ApiError {
      rethrow;
    } catch (error) {
      throw ApiError(
        message: 'Home content could not be loaded from the server right now.',
        code: 'home_content_unavailable',
        details: error,
      );
    }
  }

  HomeContent _mapResponse(Map<String, dynamic>? response) {
    if (response == null) return const HomeContent.empty();

    final message = response['message'];
    final data = message is Map<String, dynamic> ? message : response;

    return HomeContent(
      audience: _readString(data, const ['audience'], fallback: 'All'),
      featuredBanners: _readList(data, 'featured_banners')
          .map(_mapBanner)
          .where((item) => item.title.isNotEmpty)
          .toList(growable: false),
      taxBusinessUpdates: _readList(data, 'tax_business_updates')
          .map(_mapContentCard)
          .where((item) => item.title.isNotEmpty)
          .toList(growable: false),
      learnGrow: _readList(data, 'learn_grow')
          .map(_mapContentCard)
          .where((item) => item.title.isNotEmpty)
          .toList(growable: false),
    );
  }

  HomeBanner _mapBanner(Map<String, dynamic> json) {
    final actionJson = json['action'] is Map
        ? Map<String, dynamic>.from(json['action'] as Map)
        : const <String, dynamic>{};

    return HomeBanner(
      id: _readString(json, const ['id', 'name']),
      title: _readString(json, const ['title']),
      subtitle: _readString(json, const ['subtitle']),
      badge: _readString(json, const ['badge']),
      contentType: _readString(json, const [
        'content_type',
      ], fallback: 'Featured'),
      imageUrl: ApiConfig.resolveFileUrl(
        _readNullableString(json, const ['image', 'image_url']),
      ),
      action: HomeBannerAction(
        type: _bannerActionType(
          _readString(actionJson, const ['type'], fallback: 'None'),
        ),
        target: _readString(actionJson, const ['target']),
        label: _readString(actionJson, const ['label']),
      ),
      priority: _readInt(json, const ['priority']),
      sortOrder: _readInt(json, const ['sort_order']),
    );
  }

  HomeContentCard _mapContentCard(Map<String, dynamic> json) {
    return HomeContentCard(
      id: _readString(json, const ['id', 'name']),
      title: _readString(json, const ['title']),
      summary: _readString(json, const ['summary', 'subtitle']),
      category: _readString(json, const ['category']),
      contentType: _readString(json, const ['content_type']),
      detailType: _readString(json, const [
        'detail_type',
      ], fallback: 'knowledge'),
      imageUrl: ApiConfig.resolveFileUrl(
        _readNullableString(json, const ['image', 'cover_image']),
      ),
      urgency: _readNullableString(json, const ['urgency']),
      publishedOn: _readNullableString(json, const ['published_on']),
      effectiveDate: _readNullableString(json, const ['effective_date']),
      mobileRoute: _readNullableString(json, const ['mobile_route']),
      isFeatured: _readBool(json, const ['is_featured']),
      priority: _readInt(json, const ['priority']),
      sortOrder: _readInt(json, const ['sort_order']),
      readTimeMinutes: _readInt(json, const ['read_time_minutes']),
    );
  }

  List<Map<String, dynamic>> _readList(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is! List) return const [];

    return value
        .whereType<Map>()
        .map(
          (item) => item.map((key, value) => MapEntry(key.toString(), value)),
        )
        .toList(growable: false);
  }

  HomeBannerActionType _bannerActionType(String value) {
    final normalized = value.trim().toLowerCase().replaceAll('_', ' ');
    return switch (normalized) {
      'route' => HomeBannerActionType.route,
      'knowledge article' ||
      'knowledge' => HomeBannerActionType.knowledgeArticle,
      'service' => HomeBannerActionType.service,
      'external url' || 'url' => HomeBannerActionType.externalUrl,
      _ => HomeBannerActionType.none,
    };
  }
}

String _readString(
  Map<String, dynamic> data,
  List<String> keys, {
  String fallback = '',
}) {
  return _readNullableString(data, keys) ?? fallback;
}

String? _readNullableString(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key]?.toString().trim();
    if (value != null && value.isNotEmpty) return value;
  }
  return null;
}

int _readInt(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    final parsed = int.tryParse(value?.toString().trim() ?? '');
    if (parsed != null) return parsed;
  }
  return 0;
}

bool _readBool(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = value?.toString().trim().toLowerCase();
    if (normalized == '1' || normalized == 'true' || normalized == 'yes') {
      return true;
    }
  }
  return false;
}
