enum AppEnvironment {
  development,
  staging,
  production,
}

class Env {
  const Env._();

  static const AppEnvironment current = AppEnvironment.development;

  static bool get isDevelopment => current == AppEnvironment.development;
  static bool get isStaging => current == AppEnvironment.staging;
  static bool get isProduction => current == AppEnvironment.production;
}