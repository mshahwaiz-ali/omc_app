import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/frappe_client.dart';

final onboardingRepositoryProvider = Provider<OnboardingRepository>((ref) {
  return OnboardingRepository(frappeClient: ref.watch(frappeClientProvider));
});

final onboardingSlidesProvider = FutureProvider<List<OnboardingSlide>>((ref) {
  return ref.watch(onboardingRepositoryProvider).fetchSlides();
});

class OnboardingRepository {
  const OnboardingRepository({required this.frappeClient});

  final FrappeClient frappeClient;

  Future<List<OnboardingSlide>> fetchSlides() async {
    try {
      final response = await frappeClient.getMethod(
        ApiConfig.onboardingSlidesMethod,
      );
      final rows = _readRows(response);
      final slides = rows
          .map(OnboardingSlide.fromJson)
          .where((slide) => slide.title.isNotEmpty)
          .toList(growable: false);

      return slides.isEmpty ? OnboardingSlide.fallbackSlides : slides;
    } on ApiError {
      return OnboardingSlide.fallbackSlides;
    } catch (_) {
      return OnboardingSlide.fallbackSlides;
    }
  }

  List<Map<String, dynamic>> _readRows(Map<String, dynamic> response) {
    final message = response['message'];
    final data = message is Map<String, dynamic> ? message : response;

    for (final key in const ['slides', 'items', 'rows']) {
      final value = data[key];
      if (value is List) {
        return value
            .whereType<Map>()
            .map(
              (item) =>
                  item.map((key, value) => MapEntry(key.toString(), value)),
            )
            .toList(growable: false);
      }
    }

    if (message is List) {
      return message
          .whereType<Map>()
          .map(
            (item) => item.map((key, value) => MapEntry(key.toString(), value)),
          )
          .toList(growable: false);
    }

    return const [];
  }
}

class OnboardingSlide {
  const OnboardingSlide({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.assetPath,
    required this.accentColor,
    required this.benefits,
    this.imageUrl,
    this.primaryCtaLabel,
    this.primaryCtaRoute,
    this.secondaryCtaLabel,
    this.secondaryCtaRoute,
  });

  final String id;
  final String title;
  final String subtitle;
  final String description;
  final String assetPath;
  final String accentColor;
  final List<String> benefits;
  final String? imageUrl;
  final String? primaryCtaLabel;
  final String? primaryCtaRoute;
  final String? secondaryCtaLabel;
  final String? secondaryCtaRoute;

  factory OnboardingSlide.fromJson(Map<String, dynamic> json) {
    return OnboardingSlide(
      id: _stringValue(json['id'] ?? json['name'] ?? json['slide_id']),
      title: _stringValue(json['title']),
      subtitle: _stringValue(json['subtitle']),
      description: _stringValue(json['description']),
      imageUrl: _nullableString(json['image_url'] ?? json['image']),
      assetPath: _assetForIcon(_stringValue(json['icon_key'])),
      accentColor: _stringValue(json['accent_color']).isNotEmpty
          ? _stringValue(json['accent_color'])
          : '#C81D32',
      benefits: _benefitsFromJson(json['benefits']),
      primaryCtaLabel: _nullableString(json['primary_cta_label']),
      primaryCtaRoute: _nullableString(json['primary_cta_route']),
      secondaryCtaLabel: _nullableString(json['secondary_cta_label']),
      secondaryCtaRoute: _nullableString(json['secondary_cta_route']),
    );
  }

  static List<OnboardingSlide> get fallbackSlides => const [
    OnboardingSlide(
      id: 'business-services',
      title: 'Start business services with clarity',
      subtitle:
          'Explore company, tax, visa and compliance services in one secure app.',
      description:
          'Find the right OMC service, understand what is required, and begin when your account is ready.',
      assetPath: 'assets/images/customer-service.png',
      accentColor: '#C81D32',
      benefits: ['Service catalogue', 'Clear requirements', 'Guest preview'],
      primaryCtaLabel: 'Create Account',
      primaryCtaRoute: '/signup',
    ),
    OnboardingSlide(
      id: 'track-work',
      title: 'Track cases, documents and payments',
      subtitle: 'Follow progress without chasing updates across messages.',
      description:
          'Customers can see requests, pending documents, invoices and service activity from one workspace.',
      assetPath: 'assets/images/checklist.png',
      accentColor: '#2563EB',
      benefits: ['Live progress', 'Document status', 'Payment updates'],
      primaryCtaLabel: 'Login',
      primaryCtaRoute: '/login',
    ),
    OnboardingSlide(
      id: 'secure-updates',
      title: 'Stay updated with secure notifications',
      subtitle:
          'Important actions and account updates stay visible when they matter.',
      description:
          'Get service, payment, document and support notifications with a clean mobile workflow.',
      assetPath: 'assets/images/cloud-computing.png',
      accentColor: '#0F766E',
      benefits: ['Action reminders', 'Support access', 'Secure account'],
      primaryCtaLabel: 'Get Started',
      primaryCtaRoute: '/login',
    ),
  ];

  static String _stringValue(dynamic value) => value?.toString().trim() ?? '';

  static String? _nullableString(dynamic value) {
    final text = _stringValue(value);
    return text.isEmpty ? null : text;
  }

  static List<String> _benefitsFromJson(dynamic value) {
    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .take(4)
          .toList(growable: false);
    }

    final text = _stringValue(value);
    if (text.isEmpty) return const [];

    return text
        .split(RegExp(r'[\n,;]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .take(4)
        .toList(growable: false);
  }

  static String _assetForIcon(String iconKey) {
    switch (iconKey.trim().toLowerCase()) {
      case 'documents':
      case 'track':
        return 'assets/images/checklist.png';
      case 'payments':
        return 'assets/images/payable.png';
      case 'support':
        return 'assets/images/live-chat.png';
      case 'tax':
        return 'assets/images/tax.png';
      case 'secure':
      case 'notifications':
        return 'assets/images/cloud-computing.png';
      case 'services':
      default:
        return 'assets/images/customer-service.png';
    }
  }
}
