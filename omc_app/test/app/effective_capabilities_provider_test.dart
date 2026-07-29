import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/app/providers/effective_capabilities_provider.dart';
import 'package:omc_app/features/auth/application/auth_state.dart';
import 'package:omc_app/features/profile/data/profile_summary.dart';

void main() {
  const sessionCapabilities = AuthCapabilities(
    accessState: AccountAccessState.approved,
    canTrackRequests: true,
  );

  const profileCapabilities = AuthCapabilities(
    accessState: AccountAccessState.internal,
    canAccessInternalWorkspace: true,
    canViewAssignedServiceCases: true,
  );

  const profile = ProfileSummary(
    displayName: 'Internal User',
    email: 'internal@example.com',
    capabilities: profileCapabilities,
  );

  group('resolveEffectiveCapabilities', () {
    test('prefers loaded profile capabilities', () {
      final resolved = resolveEffectiveCapabilities(
        sessionCapabilities: sessionCapabilities,
        profileSummary: const AsyncData(profile),
      );

      expect(resolved, profileCapabilities);
    });

    test('uses session capabilities while profile is loading', () {
      final resolved = resolveEffectiveCapabilities(
        sessionCapabilities: sessionCapabilities,
        profileSummary: const AsyncLoading(),
      );

      expect(resolved, sessionCapabilities);
    });

    test('uses session capabilities when profile loading fails', () {
      final resolved = resolveEffectiveCapabilities(
        sessionCapabilities: sessionCapabilities,
        profileSummary: AsyncError(
          StateError('profile unavailable'),
          StackTrace.empty,
        ),
      );

      expect(resolved, sessionCapabilities);
    });

    test('uses session capabilities when profile result is null', () {
      final resolved = resolveEffectiveCapabilities(
        sessionCapabilities: sessionCapabilities,
        profileSummary: const AsyncData(null),
      );

      expect(resolved, sessionCapabilities);
    });
  });
}
