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

  /// Local-only auth bypass for UI/module testing.
  ///
  /// Enable only with:
  /// flutter run --dart-define=OMC_USE_MOCK_AUTH=true
  ///
  /// Do not enable this flag in production builds.
  static const bool useMockAuth = bool.fromEnvironment(
    'OMC_USE_MOCK_AUTH',
    defaultValue: false,
  );

  /// Local-only service tracking sample data for UI/module testing.
  ///
  /// Enable only with:
  /// flutter run --dart-define=OMC_USE_SERVICE_PREVIEW=true
  ///
  /// Normal development/staging/production should use backend data.
  static const bool useServicePreview = bool.fromEnvironment(
    'OMC_USE_SERVICE_PREVIEW',
    defaultValue: false,
  );

  /// Optional backend catalogue source for future Frappe service catalogue API.
  ///
  /// Keep disabled until the backend method and response contract are confirmed.
  static const bool useBackendServiceCatalogue = bool.fromEnvironment(
    'OMC_USE_BACKEND_SERVICE_CATALOGUE',
    defaultValue: false,
  );

  static bool get isStaging => current == AppEnvironment.staging;
  static bool get isProduction => current == AppEnvironment.production;
}
