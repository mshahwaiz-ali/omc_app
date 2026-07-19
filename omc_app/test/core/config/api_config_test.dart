import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/core/config/api_config.dart';

void main() {
  test('signup uses canonical access endpoint', () {
    expect(ApiConfig.signUpMethod, 'omc_app.api.access.sign_up');
  });
}
