import 'package:flutter/foundation.dart';

enum AppEnvironment { development, production }

class Env {
  const Env._();

  static const String _definedEnvironment = String.fromEnvironment(
    'OMC_ENV',
    defaultValue: '',
  );

  static String get definedEnvironment => _definedEnvironment.trim();

  static AppEnvironment get current {
    switch (_definedEnvironment.trim().toLowerCase()) {
      case '':
        return kReleaseMode
            ? AppEnvironment.production
            : AppEnvironment.development;
      case 'prod':
      case 'production':
        return AppEnvironment.production;
      case 'dev':
      case 'development':
        return AppEnvironment.development;
      default:
        throw StateError('Invalid OMC_ENV. Use development or production.');
    }
  }

  static bool get isDevelopment => current == AppEnvironment.development;
  static bool get isProduction => current == AppEnvironment.production;

  /// Local-only auth bypass for UI/module testing.
  ///
  /// Enable only with:
  /// flutter run --dart-define=OMC_USE_MOCK_AUTH=true
  ///
  /// Production builds always force this off.
  static const bool _useMockAuthFlag = bool.fromEnvironment(
    'OMC_USE_MOCK_AUTH',
    defaultValue: false,
  );

  static bool get useMockAuth => !isProduction && _useMockAuthFlag;

  /// Explicit local service preview mode for development UI/module testing.
  ///
  /// Enable only with:
  /// flutter run --dart-define=OMC_USE_SERVICE_PREVIEW=true
  ///
  /// Production builds always force this off. When this is false, the service
  /// catalogue must come from the backend.
  static const bool _useServicePreviewFlag = bool.fromEnvironment(
    'OMC_USE_SERVICE_PREVIEW',
    defaultValue: false,
  );

  static bool get useServicePreview => isDevelopment && _useServicePreviewFlag;

  /// Development-only fallback for backend catalogue outages.
  ///
  /// Enable only with:
  /// flutter run --dart-define=OMC_ALLOW_SERVICE_CATALOGUE_FALLBACK=true
  ///
  /// Production builds always force this off. Empty backend catalogues should
  /// still render an empty state instead of fake data.
  static const bool _allowServiceCatalogueFallbackFlag = bool.fromEnvironment(
    'OMC_ALLOW_SERVICE_CATALOGUE_FALLBACK',
    defaultValue: false,
  );

  static bool get allowServiceCatalogueFallback =>
      isDevelopment && _allowServiceCatalogueFallbackFlag;

  /// Explicit local-only preview data for support channels and topics.
  static const bool _allowSupportPreviewFlag = bool.fromEnvironment(
    'OMC_ALLOW_SUPPORT_PREVIEW',
    defaultValue: false,
  );

  static bool get allowSupportPreview =>
      isDevelopment && _allowSupportPreviewFlag;

  /// Backend service catalogue is the normal source of truth.
  ///
  /// This getter is kept for older call sites, but no longer gates backend
  /// catalogue loading. Use `useServicePreview` for explicit local/mock data.
  static bool get useBackendServiceCatalogue => true;

  /// Optional Google login entry point.
  ///
  /// Keep disabled until the backend validates Google ID tokens server-side.
  /// Production builds force this off unless Google login is intentionally
  /// implemented and this guard is updated.
  static const bool _googleLoginFlag = bool.fromEnvironment(
    'OMC_ENABLE_GOOGLE_LOGIN',
    defaultValue: false,
  );

  static bool get googleLoginEnabled => !isProduction && _googleLoginFlag;
}
