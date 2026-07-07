import '../../support/data/support_config_data.dart';

class MobileAppConfig {
  const MobileAppConfig({
    required this.support,
    required this.features,
    required this.branding,
    required this.isFallback,
  });

  final SupportConfigData support;
  final MobileFeatureConfig features;
  final MobileBrandingConfig branding;
  final bool isFallback;

  static MobileAppConfig get fallback {
    return MobileAppConfig(
      support: SupportConfigData.fallback,
      features: const MobileFeatureConfig(),
      branding: const MobileBrandingConfig(
        companyName: 'OMC House',
        tagline: 'Business, tax and compliance support',
      ),
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
        false,
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
  });

  final String companyName;
  final String tagline;

  factory MobileBrandingConfig.fromJson(Map<String, dynamic> json) {
    return MobileBrandingConfig(
      companyName: _stringValue(json['company_name']).isNotEmpty
          ? _stringValue(json['company_name'])
          : 'OMC House',
      tagline: _stringValue(json['tagline']),
    );
  }

  static String _stringValue(dynamic value) => value?.toString().trim() ?? '';
}
