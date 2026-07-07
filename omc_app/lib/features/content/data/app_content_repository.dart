import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/frappe_client.dart';

final appContentRepositoryProvider = Provider<AppContentRepository>((ref) {
  return AppContentRepository(frappeClient: ref.watch(frappeClientProvider));
});

final appBannersProvider = FutureProvider<List<AppBannerItem>>((ref) {
  return ref.watch(appContentRepositoryProvider).fetchBanners();
});

final appFaqsProvider = FutureProvider<List<AppFaqItem>>((ref) {
  return ref.watch(appContentRepositoryProvider).fetchFaqs();
});

class AppContentRepository {
  const AppContentRepository({required FrappeClient frappeClient})
    : _frappeClient = frappeClient;

  final FrappeClient _frappeClient;

  Future<List<AppBannerItem>> fetchBanners() async {
    try {
      final response = await _frappeClient.getMethod(ApiConfig.appBannersMethod);
      final rows = _readRows(response, const ['banners', 'items', 'rows']);
      return rows
          .map(AppBannerItem.fromJson)
          .where((item) => item.title.isNotEmpty || item.message.isNotEmpty)
          .toList(growable: false);
    } on ApiError {
      rethrow;
    } catch (error) {
      throw ApiError(
        message: 'OMC app banners could not be loaded right now.',
        code: 'app_banners_unavailable',
        details: error,
      );
    }
  }

  Future<List<AppFaqItem>> fetchFaqs() async {
    try {
      final response = await _frappeClient.getMethod(ApiConfig.faqsMethod);
      final rows = _readRows(response, const ['faqs', 'items', 'rows']);
      return rows
          .map(AppFaqItem.fromJson)
          .where((item) => item.question.isNotEmpty)
          .toList(growable: false);
    } on ApiError {
      rethrow;
    } catch (error) {
      throw ApiError(
        message: 'OMC FAQs could not be loaded right now.',
        code: 'faqs_unavailable',
        details: error,
      );
    }
  }

  List<Map<String, dynamic>> _readRows(
    Map<String, dynamic> response,
    List<String> keys,
  ) {
    final message = response['message'];
    final data = message is Map<String, dynamic> ? message : response;

    for (final key in keys) {
      final value = data[key];
      if (value is List) {
        return value
            .whereType<Map>()
            .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
            .toList(growable: false);
      }
    }

    if (message is List) {
      return message
          .whereType<Map>()
          .map((item) => item.map((key, value) => MapEntry(key.toString(), value)))
          .toList(growable: false);
    }

    return const [];
  }
}

class AppBannerItem {
  const AppBannerItem({
    required this.id,
    required this.title,
    required this.message,
    this.imageUrl,
    this.actionLabel,
    this.actionUrl,
    this.priority = 0,
  });

  final String id;
  final String title;
  final String message;
  final String? imageUrl;
  final String? actionLabel;
  final String? actionUrl;
  final int priority;

  factory AppBannerItem.fromJson(Map<String, dynamic> json) {
    return AppBannerItem(
      id: _readString(json, const ['id', 'name', 'banner_id']),
      title: _readString(json, const ['title', 'heading', 'subject']),
      message: _readString(json, const ['message', 'description', 'subtitle']),
      imageUrl: _readNullableString(json, const ['image_url', 'image', 'banner_image']),
      actionLabel: _readNullableString(json, const ['action_label', 'button_label', 'cta_label']),
      actionUrl: _readNullableString(json, const ['action_url', 'mobile_route', 'route', 'url']),
      priority: _readInt(json, const ['priority', 'sort_order', 'idx']),
    );
  }
}

class AppFaqItem {
  const AppFaqItem({
    required this.id,
    required this.question,
    required this.answer,
    this.category,
    this.sortOrder = 0,
  });

  final String id;
  final String question;
  final String answer;
  final String? category;
  final int sortOrder;

  factory AppFaqItem.fromJson(Map<String, dynamic> json) {
    return AppFaqItem(
      id: _readString(json, const ['id', 'name', 'faq_id']),
      question: _readString(json, const ['question', 'title']),
      answer: _readString(json, const ['answer', 'description', 'content']),
      category: _readNullableString(json, const ['category', 'faq_category']),
      sortOrder: _readInt(json, const ['sort_order', 'idx']),
    );
  }
}

String _readString(Map<String, dynamic> data, List<String> keys) {
  return _readNullableString(data, keys) ?? '';
}

String? _readNullableString(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final text = data[key]?.toString().trim();
    if (text != null && text.isNotEmpty) return text;
  }
  return null;
}

int _readInt(Map<String, dynamic> data, List<String> keys) {
  for (final key in keys) {
    final value = data[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    final parsed = int.tryParse(value?.toString() ?? '');
    if (parsed != null) return parsed;
  }
  return 0;
}
