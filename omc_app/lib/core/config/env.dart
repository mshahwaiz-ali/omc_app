enum AppEnvironment { development, staging, production }

class Env {
  const Env._();

  static const AppEnvironment current = AppEnvironment.development;

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

  static bool get isStaging => current == AppEnvironment.staging;
  static bool get isProduction => current == AppEnvironment.production;
}
