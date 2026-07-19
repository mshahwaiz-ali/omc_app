import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/features/auth/application/auth_state.dart';

void main() {
  group('AuthCapabilities.fromJson', () {
    test('does not grant customer service requests to internal users', () {
      final capabilities = AuthCapabilities.fromJson({
        'access_state': 'internal',
        'can_access_internal_workspace': true,
        'can_create_service_request': false,
      });

      expect(capabilities.isInternal, isTrue);
      expect(capabilities.canAccessInternalWorkspace, isTrue);
      expect(capabilities.canCreateServiceRequest, isFalse);
    });

    test('preserves approved-customer fallback for missing capability key', () {
      final capabilities = AuthCapabilities.fromJson({
        'access_state': 'approved',
      });

      expect(capabilities.isApproved, isTrue);
      expect(capabilities.canCreateServiceRequest, isTrue);
    });

    test('honors an explicit approved-customer denial', () {
      final capabilities = AuthCapabilities.fromJson({
        'access_state': 'approved',
        'can_create_service_request': false,
      });

      expect(capabilities.isApproved, isTrue);
      expect(capabilities.canCreateServiceRequest, isFalse);
    });
  });
}
