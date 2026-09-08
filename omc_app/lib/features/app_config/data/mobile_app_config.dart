import '../../support/data/support_config_data.dart';
import 'mobile_release_controls.dart';

enum MobileConfigAvailability { current, stale, unavailable }

class MobileAppConfig {
  const MobileAppConfig({
    required this.support,
    required this.features,
    required this.branding,
    required this.legal,
    required this.isFallback,
    this.controls = MobileReleaseControls.unavailable,
    this.availability = MobileConfigAvailability.unavailable,
    this.validUntil,
  });

  final SupportConfigData support;
  final MobileFeatureConfig features;
  final MobileBrandingConfig branding;
  final MobileLegalConfig legal;
  final bool isFallback;
  final MobileReleaseControls controls;
  final MobileConfigAvailability availability;
  final DateTime? validUntil;

  bool isCurrentAt(DateTime now) =>
      availability == MobileConfigAvailability.current &&
      controls.valid &&
      validUntil != null &&
      now.isBefore(validUntil!);

  static MobileAppConfig get fallback => MobileAppConfig(
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

  MobileAppConfig asStale() => MobileAppConfig(
    support: support,
    // Last-known branding and blocked controls survive; stale features do not
    // become permission to start a business workflow.
    features: const MobileFeatureConfig(),
    branding: branding,
    legal: legal,
    isFallback: true,
    controls: controls,
    availability: MobileConfigAvailability.stale,
  );

  factory MobileAppConfig.fromApiResponse(
    Map<String, dynamic>? data, {
    DateTime? fetchedAt,
  }) {
    if (data == null || data.isEmpty) {
      throw const FormatException('Mobile configuration is empty.');
    }
    final message = data['message'];
    final raw = message is Map<String, dynamic> ? message : data;
    final featureData = raw['features'];
    final meta = raw['meta'];
    if (featureData is! Map<String, dynamic> || meta is! Map<String, dynamic>) {
      throw const FormatException('Mobile configuration is incomplete.');
    }
    final controls = MobileReleaseControls.fromJson(meta);
    final defaults = fallback;
    final support = raw['support'];
    final branding = raw['branding'];
    final legal = raw['legal'];
    // Legacy meta.fallback describes default support contacts, not the validity
    // of the feature/control payload. Required controls are validated above.
    return MobileAppConfig(
      support: support is Map<String, dynamic>
          ? SupportConfigData.fromApiResponse(support)
          : defaults.support,
      features: MobileFeatureConfig.fromJson(featureData),
      branding: branding is Map<String, dynamic>
          ? MobileBrandingConfig.fromJson(branding)
          : defaults.branding,
      legal: legal is Map<String, dynamic>
          ? MobileLegalConfig.fromJson(legal)
          : defaults.legal,
      isFallback:
          raw['fallback'] == true ||
          raw['is_fallback'] == true ||
          meta['fallback'] == true,
      controls: controls,
      availability: MobileConfigAvailability.current,
      validUntil: (fetchedAt ?? DateTime.now()).add(const Duration(minutes: 5)),
    );
  }
}

class MobileFeatureConfig {
  const MobileFeatureConfig({
    this.guestModeEnabled = false,
    this.expenseTrackerEnabled = false,
    this.knowledgeEnabled = false,
    this.paymentsEnabled = false,
    this.paymentGatewayEnabled = false,
    this.taxCalculatorEnabled = false,
    this.supportEnabled = false,
    this.subscriptionsEnabled = false,
    this.internalWorkspaceEnabled = false,
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

  factory MobileFeatureConfig.fromJson(Map<String, dynamic> json) =>
      MobileFeatureConfig(
        guestModeEnabled: _enabled(json['guest_mode_enabled']),
        expenseTrackerEnabled: _enabled(json['expense_tracker_enabled']),
        knowledgeEnabled: _enabled(json['knowledge_enabled']),
        paymentsEnabled: _enabled(json['payments_enabled']),
        paymentGatewayEnabled: _enabled(json['payment_gateway_enabled']),
        taxCalculatorEnabled: _enabled(json['tax_calculator_enabled']),
        supportEnabled: _enabled(json['support_enabled']),
        subscriptionsEnabled: _enabled(json['subscriptions_enabled']),
        internalWorkspaceEnabled: _enabled(json['internal_workspace_enabled']),
      );

  static bool _enabled(Object? value) =>
      value == true || value == 1 || value == '1' || value == 'true';
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
    privacyPolicyUrl: 'https://omchouse.com/privacy-policy/',
    privacyPolicyText:
        'OMC House uses customer information to provide account access, service requests, document handling, payments, support and service notifications. For the complete policy, open the OMC House privacy policy.',
    termsText:
        'By using the OMC House app, you agree to provide accurate account and service information and to use the app only for lawful business, tax and compliance purposes. Service fees, timelines and outcomes may depend on document completeness, payment status, OMC review, government or third-party systems and applicable legal requirements. OMC may request additional information, decline or pause a request where verification, security, fraud-prevention or compliance checks require it. Payments, cancellations and refunds are handled according to the confirmed service terms and applicable law. You are responsible for protecting your account credentials and for activity performed through your account. OMC may send service, security and account notices using the contact details you provide. Nothing in these terms limits rights that cannot lawfully be excluded under applicable law.',
  );

  factory MobileLegalConfig.fromJson(Map<String, dynamic> json) {
    return MobileLegalConfig(
      privacyPolicyUrl:
          _nullableString(json['privacy_policy_url']) ??
          fallback.privacyPolicyUrl,
      privacyPolicyText:
          _nullableString(json['privacy_policy_text']) ??
          fallback.privacyPolicyText,
      termsUrl: _nullableString(json['terms_url']) ?? fallback.termsUrl,
      termsText: _nullableString(json['terms_text']) ?? fallback.termsText,
    );
  }

  static String? _nullableString(dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }
}
