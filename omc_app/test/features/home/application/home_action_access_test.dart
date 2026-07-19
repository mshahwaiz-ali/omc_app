import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/features/auth/application/auth_state.dart';
import 'package:omc_app/features/home/application/home_action_access.dart';

void main() {
  group('canUseHomeActionCapability', () {
    test('allows an unspecified customer action when configured', () {
      expect(canUseHomeActionCapability(null, AuthCapabilities.guest), isTrue);
    });

    test('denies an unspecified internal action when configured', () {
      const capabilities = AuthCapabilities(
        accessState: AccountAccessState.internal,
        canAccessInternalWorkspace: true,
      );

      expect(
        canUseHomeActionCapability(
          null,
          capabilities,
          allowWithoutRequirement: false,
        ),
        isFalse,
      );
    });

    test('uses canonical document route access', () {
      const denied = AuthCapabilities(
        accessState: AccountAccessState.approved,
        canViewDocuments: false,
        canReviewDocuments: false,
      );
      const reviewer = AuthCapabilities(
        accessState: AccountAccessState.internal,
        canReviewDocuments: true,
      );

      expect(canUseHomeActionCapability('can_view_documents', denied), isFalse);
      expect(
        canUseHomeActionCapability('can_view_documents', reviewer),
        isTrue,
      );
    });

    test('does not let workspace access imply management access', () {
      const workspaceOnly = AuthCapabilities(
        accessState: AccountAccessState.internal,
        canAccessInternalWorkspace: true,
      );

      expect(
        canUseHomeActionCapability('can_manage_customers', workspaceOnly),
        isFalse,
      );
      expect(
        canUseHomeActionCapability('can_manage_leads', workspaceOnly),
        isFalse,
      );
      expect(
        canUseHomeActionCapability('can_manage_tasks', workspaceOnly),
        isFalse,
      );
    });

    test('denies unknown capability keys', () {
      const internal = AuthCapabilities(
        accessState: AccountAccessState.internal,
        canAccessInternalWorkspace: true,
      );

      expect(
        canUseHomeActionCapability('future_unknown_capability', internal),
        isFalse,
      );
    });
  });
}
