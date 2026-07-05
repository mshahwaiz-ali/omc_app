import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/premium_card.dart';
import '../../auth/application/auth_controller.dart';
import '../data/profile_repository.dart';
import '../data/profile_summary.dart';
import 'widgets/profile_action_card.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileSummaryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(profileSummaryProvider);
            await ref.read(profileSummaryProvider.future);
          },
          child: profileAsync.when(
            data: (profile) {
              if (profile == null) {
                return _ProfileUnavailableView(
                  fallbackProfile: ProfileSummary.fromUserId(
                    ref.watch(authControllerProvider).userId,
                  ),
                  message:
                      'Signed in as ${ProfileSummary.fromUserId(ref.watch(authControllerProvider).userId).email}. Full customer profile will appear when the backend profile endpoint responds.',
                  onRetry: () => ref.invalidate(profileSummaryProvider),
                );
              }

              return _ProfileContent(profile: profile, ref: ref);
            },
            loading: () => const _ProfileLoadingView(),
            error: (error, _) => _ProfileUnavailableView(
              fallbackProfile: ProfileSummary.fromUserId(
                ref.watch(authControllerProvider).userId,
              ),
              message: _profileErrorMessage(error),
              onRetry: () => ref.invalidate(profileSummaryProvider),
            ),
          ),
        ),
      ),
    );
  }
}

String _profileErrorMessage(Object error) {
  if (error is ApiError && error.message.trim().isNotEmpty) {
    return error.message.trim();
  }

  return 'Full customer profile could not be loaded from the backend right now.';
}

class _ProfileLoadingView extends StatelessWidget {
  const _ProfileLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: const [
        PremiumCard(padding: EdgeInsets.all(22), child: SizedBox(height: 176)),
        SizedBox(height: 18),
        PremiumCard(padding: EdgeInsets.all(18), child: SizedBox(height: 210)),
      ],
    );
  }
}

class _ProfileUnavailableView extends StatelessWidget {
  const _ProfileUnavailableView({
    required this.fallbackProfile,
    required this.message,
    required this.onRetry,
  });

  final ProfileSummary fallbackProfile;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        PremiumCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: AppTheme.primaryRed,
                  size: 32,
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Profile unavailable',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({required this.profile, required this.ref});

  final ProfileSummary profile;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(profile.displayName);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        PremiumCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              Container(
                width: 74,
                height: 74,
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed,
                  borderRadius: BorderRadius.circular(26),
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                profile.displayName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                profile.email,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (profile.status != null) ...[
                const SizedBox(height: 14),
                _StatusPill(label: profile.status!),
              ],
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Account Details',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 12),
        PremiumCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _ProfileTile(
                icon: Icons.email_outlined,
                label: 'Email',
                value: profile.email,
              ),
              const _DividerIndent(),
              _ProfileTile(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: profile.phone ?? 'Not available',
              ),
              const _DividerIndent(),
              _ProfileTile(
                icon: Icons.badge_outlined,
                label: 'CNIC / Tax ID',
                value: profile.cnic ?? 'Not available',
              ),
              const _DividerIndent(),
              _ProfileTile(
                icon: Icons.workspace_premium_outlined,
                label: 'Customer Type',
                value: profile.customerType ?? 'OMC Customer',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        ProfileActionCard(
          onEditProfile: () => _submitProfileUpdateRequest(context, ref),
          onUpdateContact: () => _submitContactUpdateRequest(context, ref),
          onContactSupport: () => _showBackendPendingSnack(
            context,
            'For profile help, open Support and submit a backend ticket.',
          ),
          onRefresh: () {
            ref.invalidate(profileSummaryProvider);
            _showBackendPendingSnack(context, 'Refreshing profile data...');
          },
        ),
        const SizedBox(height: 18),
        PremiumCard(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  color: AppTheme.primaryRed,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Text(
                  'Profile details are backend-ready. Full customer data will appear when the OMC profile endpoint is enabled.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _submitProfileUpdateRequest(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final repository = ref.read(profileRepositoryProvider);
    final didSubmit = await repository.requestProfileUpdate({
      'request_type': 'profile_update',
      'display_name': profile.displayName,
      'email': profile.email,
      if (profile.phone != null) 'phone': profile.phone,
      if (profile.cnic != null) 'cnic': profile.cnic,
      if (profile.customerType != null) 'customer_type': profile.customerType,
    });

    if (!context.mounted) return;

    if (didSubmit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile update request submitted to backend.'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not submit profile update request yet.'),
      ),
    );
  }

  Future<void> _submitContactUpdateRequest(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final repository = ref.read(profileRepositoryProvider);
    final didSubmit = await repository.requestContactUpdate({
      'request_type': 'contact_update',
      'email': profile.email,
      if (profile.phone != null) 'phone': profile.phone,
    });

    if (!context.mounted) return;

    if (didSubmit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Contact update request submitted to backend.'),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not submit contact update request yet.'),
      ),
    );
  }

  void _showBackendPendingSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return 'OMC';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.primaryRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text(
          label,
          style: const TextStyle(
            color: AppTheme.primaryRed,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppTheme.primaryRed.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(15),
        ),
        child: Icon(icon, color: AppTheme.primaryRed),
      ),
      title: Text(
        label,
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          value,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _DividerIndent extends StatelessWidget {
  const _DividerIndent();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 76);
  }
}
