enum AppEnvironment { development, staging, production }

class Env {
  const Env._();

  static const String _definedEnvironment = String.fromEnvironment(
    'OMC_ENV',
    defaultValue: 'development',
  );

  static AppEnvironment get current {
    switch (_definedEnvironment.trim().toLowerCase()) {
      case 'prod':
      case 'production':
        return AppEnvironment.production;
      case 'stage':
      case 'staging':
        return AppEnvironment.staging;
      case 'dev':
      case 'development':
      default:
        return AppEnvironment.development;
    }
  }

  static bool get isDevelopment => current == AppEnvironment.development;
  static bool get isStaging => current == AppEnvironment.staging;
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

  /// Explicit local service preview mode for UI/module testing.
  ///
  /// Enable only with:
  /// flutter run --dart-define=OMC_USE_SERVICE_PREVIEW=true
  ///
  /// Production builds always force this off. When this is false, the service
  /// catalogue must come from the backend in every environment.
  static const bool _useServicePreviewFlag = bool.fromEnvironment(
    'OMC_USE_SERVICE_PREVIEW',
    defaultValue: false,
  );

  static bool get useServicePreview => !isProduction && _useServicePreviewFlag;

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
