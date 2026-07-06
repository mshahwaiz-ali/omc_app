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
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(profileSummaryProvider);
            await ref.read(profileSummaryProvider.future);
          },
          child: profileAsync.when(
            data: (profile) {
              if (profile == null) {
                final fallbackProfile = ProfileSummary.fromUserId(
                  ref.watch(authControllerProvider).userId,
                );

                return _ProfileUnavailableView(
                  fallbackProfile: fallbackProfile,
                  message:
                      'Signed in as ${fallbackProfile.email}. Full customer profile will appear when profile details are available.',
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

  return 'Full customer profile is unavailable right now. Please try again.';
}

class _ProfileLoadingView extends StatelessWidget {
  const _ProfileLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: const [
        _ProfileHeroSkeleton(),
        SizedBox(height: 20),
        _ProfileSectionSkeleton(),
      ],
    );
  }
}

class _ProfileHeroSkeleton extends StatelessWidget {
  const _ProfileHeroSkeleton();

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Container(
            width: 74,
            height: 74,
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(26),
            ),
          ),
          const SizedBox(height: 18),
          const _LoadingBar(widthFactor: 0.46, height: 14),
          const SizedBox(height: 10),
          const _LoadingBar(widthFactor: 0.68),
          const SizedBox(height: 18),
          const Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [_LoadingPill(width: 92), _LoadingPill(width: 116)],
          ),
        ],
      ),
    );
  }
}

class _ProfileSectionSkeleton extends StatelessWidget {
  const _ProfileSectionSkeleton();

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: List.generate(4, (index) {
          return Column(
            children: [
              const _LoadingProfileTile(),
              if (index != 3) const _DividerIndent(),
            ],
          );
        }),
      ),
    );
  }
}

class _LoadingProfileTile extends StatelessWidget {
  const _LoadingProfileTile();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Row(
        children: [
          _LoadingIconBox(),
          SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LoadingBar(widthFactor: 0.32),
                SizedBox(height: 9),
                _LoadingBar(widthFactor: 0.72),
              ],
            ),
          ),
        ],
      ),
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
    final initials = _initials(fallbackProfile.displayName);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        _ProfileHeroCard(
          initials: initials,
          displayName: fallbackProfile.displayName,
          email: fallbackProfile.email,
          status: 'Limited profile',
          customerType: fallbackProfile.customerType ?? 'OMC Customer',
          approvalStatus: fallbackProfile.approvalStatus ?? 'Pending sync',
        ),
        const SizedBox(height: 20),
        PremiumCard(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.person_search_outlined,
                  color: AppTheme.primaryRed,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Profile details unavailable',
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
                label: const Text('Retry profile sync'),
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
        _ProfileHeroCard(
          initials: initials,
          displayName: profile.displayName,
          email: profile.email,
          status: profile.status,
          customerType: profile.customerType ?? 'OMC Customer',
          approvalStatus: profile.approvalStatus ?? 'Synced',
        ),
        const SizedBox(height: 20),
        _ProfileSection(
          title: 'Account details',
          subtitle: 'Customer identity and tax information from your account.',
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
              label: 'Customer type',
              value: profile.customerType ?? 'OMC Customer',
            ),
            const _DividerIndent(),
            _ProfileTile(
              icon: Icons.business_outlined,
              label: 'Company',
              value: profile.companyName ?? 'Not available',
            ),
            const _DividerIndent(),
            _ProfileTile(
              icon: Icons.confirmation_number_outlined,
              label: 'NTN',
              value: profile.ntn ?? 'Not available',
            ),
            if (profile.approvalStatus != null) ...[
              const _DividerIndent(),
              _ProfileTile(
                icon: Icons.verified_user_outlined,
                label: 'Approval',
                value: profile.approvalStatus!,
              ),
            ],
          ],
        ),
        const SizedBox(height: 20),
        ProfileActionCard(
          onEditProfile: () => _submitProfileUpdateRequest(context, ref),
          onUpdateContact: () => _submitContactUpdateRequest(context, ref),
          onContactSupport: () => _showBackendPendingSnack(
            context,
            'Open Support to submit a profile or account help request.',
          ),
          onRefresh: () {
            ref.invalidate(profileSummaryProvider);
            _showBackendPendingSnack(context, 'Refreshing profile data...');
          },
        ),
        const SizedBox(height: 20),
        const _ProfileFootnote(),
      ],
    );
  }

  Future<void> _submitProfileUpdateRequest(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final repository = ref.read(profileRepositoryProvider);
    final didSubmit = await repository.requestProfileUpdate({
      'full_name': profile.displayName,
      if (profile.phone != null) 'phone': profile.phone,
      if (profile.cnic != null) 'cnic': profile.cnic,
      if (profile.ntn != null) 'ntn': profile.ntn,
      if (profile.companyName != null) 'company_name': profile.companyName,
    });

    if (!context.mounted) return;

    if (didSubmit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile update request submitted.')),
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
      'email': profile.email,
      'full_name': profile.displayName,
      if (profile.phone != null) 'phone': profile.phone,
      if (profile.phone != null) 'mobile': profile.phone,
      if (profile.cnic != null) 'cnic': profile.cnic,
      if (profile.ntn != null) 'ntn': profile.ntn,
      if (profile.companyName != null) 'company_name': profile.companyName,
    });

    if (!context.mounted) return;

    if (didSubmit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contact update request submitted.')),
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
}

class _ProfileHeroCard extends StatelessWidget {
  const _ProfileHeroCard({
    required this.initials,
    required this.displayName,
    required this.email,
    required this.customerType,
    required this.approvalStatus,
    this.status,
  });

  final String initials;
  final String displayName;
  final String email;
  final String customerType;
  final String approvalStatus;
  final String? status;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              color: AppTheme.primaryRed,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryRed.withValues(alpha: 0.20),
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                ),
              ],
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
            displayName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 23,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            email,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: [
              if (status != null) _StatusPill(label: status!),
              _StatusPill(label: customerType),
              _StatusPill(label: approvalStatus),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.title,
    required this.children,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 5),
          Text(
            subtitle!,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 12),
        PremiumCard(
          padding: EdgeInsets.zero,
          child: Column(children: children),
        ),
      ],
    );
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

class _ProfileFootnote extends StatelessWidget {
  const _ProfileFootnote();

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
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
              'Profile details are loaded from your backend account. Update requests are submitted for review when account services are available.',
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
    );
  }
}

class _LoadingIconBox extends StatelessWidget {
  const _LoadingIconBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AppTheme.primaryRed.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(15),
      ),
    );
  }
}

class _LoadingPill extends StatelessWidget {
  const _LoadingPill({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 28,
      decoration: BoxDecoration(
        color: AppTheme.primaryRed.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _LoadingBar extends StatelessWidget {
  const _LoadingBar({required this.widthFactor, this.height = 9});

  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppTheme.primaryRed.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(999),
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
