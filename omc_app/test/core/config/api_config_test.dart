import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/core/config/api_config.dart';
import 'package:omc_app/core/config/env.dart';

void main() {
  test('signup uses canonical access endpoint', () {
    expect(ApiConfig.signUpMethod, 'omc_app.api.access.sign_up');
  });

  test('release profile accepts only the canonical production origin', () {
    expect(
      () => ApiConfig.validateResolvedBuildProfile(
        isRelease: true,
        environment: AppEnvironment.production,
        apiBaseUrl: ApiConfig.productionOrigin,
        linkBaseUrl: ApiConfig.productionOrigin,
        diagnosticsDsn: 'https://public@example.ingest.sentry.io/1',
      ),
      returnsNormally,
    );
  });

  test('release profile rejects development and non-production endpoints', () {
    for (final configuration in <({AppEnvironment env, String api})>[
      (env: AppEnvironment.development, api: ApiConfig.productionOrigin),
      (env: AppEnvironment.production, api: 'http://erp.omchouse.com'),
      (env: AppEnvironment.production, api: 'https://example.com'),
      (env: AppEnvironment.production, api: 'https://erp.omchouse.com:8443'),
    ]) {
      expect(
        () => ApiConfig.validateResolvedBuildProfile(
          isRelease: true,
          environment: configuration.env,
          apiBaseUrl: configuration.api,
          linkBaseUrl: ApiConfig.productionOrigin,
          diagnosticsDsn: 'https://public@example.ingest.sentry.io/1',
        ),
        throwsStateError,
      );
    }
  });

  test('release profile requires a configured diagnostics DSN', () {
    expect(
      () => ApiConfig.validateResolvedBuildProfile(
        isRelease: true,
        environment: AppEnvironment.production,
        apiBaseUrl: ApiConfig.productionOrigin,
        linkBaseUrl: ApiConfig.productionOrigin,
      ),
      throwsStateError,
    );
  });

  test('debug profile permits an explicit local HTTP endpoint', () {
    expect(
      () => ApiConfig.validateResolvedBuildProfile(
        isRelease: false,
        environment: AppEnvironment.development,
        apiBaseUrl: 'http://100.51.143.221',
        linkBaseUrl: ApiConfig.productionOrigin,
      ),
      returnsNormally,
    );
  });
}
