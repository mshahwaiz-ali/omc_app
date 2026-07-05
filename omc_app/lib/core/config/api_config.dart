import 'env.dart';

class ApiConfig {
  const ApiConfig._();

  static const String _definedBaseUrl = String.fromEnvironment(
    'OMC_API_BASE_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    if (_definedBaseUrl.trim().isNotEmpty) {
      return _withoutTrailingSlash(_definedBaseUrl);
    }

    switch (Env.current) {
      case AppEnvironment.development:
        return 'https://erp.omchouse.com';
      case AppEnvironment.staging:
        return 'https://erp.omchouse.com';
      case AppEnvironment.production:
        return 'https://erp.omchouse.com';
    }
  }

  static const Duration connectTimeout = Duration(seconds: 20);
  static const Duration receiveTimeout = Duration(seconds: 25);
  static const Duration sendTimeout = Duration(seconds: 25);

  static const String apiMethodPath = '/api/method';
  static const String apiResourcePath = '/api/resource';

  static const String loginMethod = 'lead_app.lead_app.apis.login';
  static const String googleLoginMethod =
      'lead_app.lead_app.apis.google_mobile_login';
  static const String signUpMethod = 'lead_app.lead_app.apis.sign_up';
  static const String createServiceMethod =
      'lead_app.lead_app.apis.create_service';
  static const String createLeadMethod = 'lead_app.lead_app.apis.create_lead';
  static const String dashboardDataMethod =
      'lead_app.lead_app.apis.get_dashboard_data';
  static const String uploadFileMethod = 'upload_file';

  static String _withoutTrailingSlash(String value) {
    return value.trim().replaceFirst(RegExp(r'/+$'), '');
  }
}
