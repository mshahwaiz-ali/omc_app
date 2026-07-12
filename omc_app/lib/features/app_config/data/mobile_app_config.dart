import '../../support/data/support_config_data.dart';

class MobileAppConfig {
  const MobileAppConfig({
    required this.support,
    required this.features,
    required this.branding,
    required this.legal,
    required this.isFallback,
  });

  final SupportConfigData support;
  final MobileFeatureConfig features;
  final MobileBrandingConfig branding;
  final MobileLegalConfig legal;
  final bool isFallback;

  static MobileAppConfig get fallback {
    return MobileAppConfig(
      support: SupportConfigData.fallback,
      features: const MobileFeatureConfig(),
      branding: const MobileBrandingConfig(
        companyName: 'OMC House',
        tagline: 'Business, tax and compliance support',
        accentColor: '#111827',
      ),
      legal: MobileLegalConfig.fallback,
      isFallback: true,
    );
  }

  factory MobileAppConfig.fromApiResponse(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return fallback;

    final message = data['message'];
    final raw = message is Map<String, dynamic> ? message : data;

    final supportRaw = raw['support'];
    final featuresRaw = raw['features'];
    final brandingRaw = raw['branding'];
    final legalRaw = raw['legal'];
    final metaRaw = raw['meta'];

    final fallbackConfig = fallback;

    return MobileAppConfig(
      support: supportRaw is Map<String, dynamic>
          ? SupportConfigData.fromApiResponse(supportRaw)
          : fallbackConfig.support,
      features: featuresRaw is Map<String, dynamic>
          ? MobileFeatureConfig.fromJson(featuresRaw)
          : fallbackConfig.features,
      branding: brandingRaw is Map<String, dynamic>
          ? MobileBrandingConfig.fromJson(brandingRaw)
          : fallbackConfig.branding,
      legal: legalRaw is Map<String, dynamic>
          ? MobileLegalConfig.fromJson(legalRaw)
          : fallbackConfig.legal,
      isFallback:
          raw['fallback'] == true ||
          raw['is_fallback'] == true ||
          (metaRaw is Map<String, dynamic> && metaRaw['fallback'] == true),
    );
  }
}

class MobileFeatureConfig {
  const MobileFeatureConfig({
    this.guestModeEnabled = true,
    this.expenseTrackerEnabled = true,
    this.knowledgeEnabled = true,
    this.paymentsEnabled = true,
    this.paymentGatewayEnabled = false,
    this.taxCalculatorEnabled = true,
    this.supportEnabled = true,
    this.subscriptionsEnabled = false,
    this.internalWorkspaceEnabled = true,
  });

  final bool guestModeEnabled;
  final bool expenseTrackerEnabled;
  final bool knowledgeEnabled;
  final bool paymentsEnabled;
  final bool paymentGatewayEnabled;
  final bool taxCalculatorEnabled;
  final bool supportEnabled;
  final bool subscriptionsEnabled;
  final bool internalWorkspaceEnabled;

  factory MobileFeatureConfig.fromJson(Map<String, dynamic> json) {
    return MobileFeatureConfig(
      guestModeEnabled: _boolValue(json['guest_mode_enabled'], true),
      expenseTrackerEnabled: _boolValue(json['expense_tracker_enabled'], true),
      knowledgeEnabled: _boolValue(json['knowledge_enabled'], true),
      paymentsEnabled: _boolValue(json['payments_enabled'], true),
      paymentGatewayEnabled: _boolValue(json['payment_gateway_enabled'], false),
      taxCalculatorEnabled: _boolValue(json['tax_calculator_enabled'], true),
      supportEnabled: _boolValue(json['support_enabled'], true),
      subscriptionsEnabled: _boolValue(json['subscriptions_enabled'], false),
      internalWorkspaceEnabled: _boolValue(
        json['internal_workspace_enabled'],
        true,
      ),
    );
  }

  static bool _boolValue(dynamic value, bool fallback) {
    if (value is bool) return value;
    if (value is num) return value != 0;

    final text = value?.toString().trim().toLowerCase();
    if (text == 'true' || text == '1' || text == 'yes') return true;
    if (text == 'false' || text == '0' || text == 'no') return false;

    return fallback;
  }
}

class MobileBrandingConfig {
  const MobileBrandingConfig({
    required this.companyName,
    required this.tagline,
    this.accentColor = '#111827',
  });

  final String companyName;
  final String tagline;
  final String accentColor;

  /// Temporary source-compatible alias for older widgets. There is no longer
  /// a separate colour family; this returns the resolved accent hex value.
  String get primaryColorFamily => accentColor;

  factory MobileBrandingConfig.fromJson(Map<String, dynamic> json) {
    return MobileBrandingConfig(
      companyName: _stringValue(json['company_name']).isNotEmpty
          ? _stringValue(json['company_name'])
          : 'OMC House',
      tagline: _stringValue(json['tagline']),
      accentColor: _accentColorValue(
        json['accent_color'] ?? json['accentColor'],
      ),
    );
  }

  static String _stringValue(dynamic value) => value?.toString().trim() ?? '';

  static String _accentColorValue(dynamic value) {
    final color = _stringValue(value).toUpperCase();
    return RegExp(r'^#[0-9A-F]{6}$').hasMatch(color) ? color : '#111827';
  }
}

class MobileLegalConfig {
  const MobileLegalConfig({
    required this.privacyPolicyText,
    required this.termsText,
    this.privacyPolicyUrl,
    this.termsUrl,
  });

  final String? privacyPolicyUrl;
  final String privacyPolicyText;
  final String? termsUrl;
  final String termsText;

  static const fallback = MobileLegalConfig(
    privacyPolicyText:
        'OMC uses customer information to manage service requests, documents, support, notifications and account access.',
    termsText:
        'OMC services are subject to review, approval, document verification and applicable compliance requirements.',
  );

  factory MobileLegalConfig.fromJson(Map<String, dynamic> json) {
    return MobileLegalConfig(
      privacyPolicyUrl: _nullableString(json['privacy_policy_url']),
      privacyPolicyText:
          _nullableString(json['privacy_policy_text']) ??
          fallback.privacyPolicyText,
      termsUrl: _nullableString(json['terms_url']),
      termsText: _nullableString(json['terms_text']) ?? fallback.termsText,
    );
  }

  static String? _nullableString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }
}
