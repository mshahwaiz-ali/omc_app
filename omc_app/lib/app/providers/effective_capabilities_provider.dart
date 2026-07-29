import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/application/auth_state.dart';
import '../../features/profile/data/profile_repository.dart';
import '../../features/profile/data/profile_summary.dart';

final effectiveCapabilitiesProvider = Provider<AuthCapabilities>((ref) {
  final sessionCapabilities = ref.watch(
    authControllerProvider.select((state) => state.capabilities),
  );
  final profileSummary = ref.watch(profileSummaryProvider);

  return resolveEffectiveCapabilities(
    sessionCapabilities: sessionCapabilities,
    profileSummary: profileSummary,
  );
});

AuthCapabilities resolveEffectiveCapabilities({
  required AuthCapabilities sessionCapabilities,
  required AsyncValue<ProfileSummary?> profileSummary,
}) {
  return profileSummary.maybeWhen(
    data: (profile) => profile?.capabilities ?? sessionCapabilities,
    orElse: () => sessionCapabilities,
  );
}
