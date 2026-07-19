import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme.dart';
import '../../../core/config/api_config.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/omc_premium.dart';
import '../../../core/widgets/premium_card.dart';
import '../../auth/application/auth_controller.dart';
import '../../support/data/support_repository.dart';
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
  return AppFailureClassifier.classify(
    error,
    fallbackTitle: 'Profile unavailable',
    fallbackMessage:
        'Full customer profile is unavailable right now. Please try again.',
  ).message;
}

class _ProfileLoadingView extends StatelessWidget {
  const _ProfileLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 164),
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
              color: AppTheme.primary.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.07),
              ),
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
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 164),
      children: [
        _ProfileHeroCard(
          initials: initials,
          displayName: fallbackProfile.displayName,
          email: fallbackProfile.email,
          status: 'Limited profile',
          customerType: fallbackProfile.customerType ?? 'OMC Customer',
          approvalStatus: fallbackProfile.approvalStatus ?? 'Pending sync',
          avatarUrl: fallbackProfile.avatarUrl,
          onChangePhoto: null,
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
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(21),
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                  ),
                ),
                child: const Icon(
                  Icons.person_search_outlined,
                  color: AppTheme.primary,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Profile details unavailable',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.15,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
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

bool _profilePhotoUploadInFlight = false;
bool _profileRequestSubmissionInFlight = false;

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({required this.profile, required this.ref});

  final ProfileSummary profile;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final initials = _initials(profile.displayName);
    final isInternal =
        profile.canAccessInternalWorkspace || profile.capabilities.isInternal;
    final typeLabel = isInternal
        ? (profile.customerType ?? 'Internal')
        : (profile.customerType ?? 'OMC Customer');
    final approvalLabel = isInternal
        ? 'Internal'
        : (profile.approvalStatus ?? 'Synced');

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 164),
      children: [
        _ProfileHeroCard(
          initials: initials,
          displayName: profile.displayName,
          email: profile.email,
          status: isInternal ? 'Active' : profile.status,
          customerType: typeLabel,
          approvalStatus: approvalLabel,
          avatarUrl: profile.avatarUrl,
          onChangePhoto: () => _changeProfilePhoto(context, ref),
        ),
        const SizedBox(height: 20),
        _ProfileSection(
          title: isInternal ? 'Internal account details' : 'Account details',
          subtitle: isInternal
              ? 'OMC staff identity and internal access from your backend account.'
              : 'Customer identity and tax information from your account.',
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
              icon: isInternal
                  ? Icons.admin_panel_settings_outlined
                  : Icons.workspace_premium_outlined,
              label: isInternal ? 'Internal role' : 'Customer type',
              value: typeLabel,
            ),
            if (!isInternal) ...[
              const _DividerIndent(),
              _ProfileTile(
                icon: Icons.badge_outlined,
                label: 'CNIC / Tax ID',
                value: profile.cnic ?? 'Not available',
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
            ],
            const _DividerIndent(),
            _ProfileTile(
              icon: Icons.verified_user_outlined,
              label: isInternal ? 'Access scope' : 'Approval',
              value: approvalLabel,
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (!isInternal)
          ProfileActionCard(
            onEditProfile: () => _submitProfileUpdateRequest(context, ref),
            onUpdateContact: () => _submitContactUpdateRequest(context, ref),
            onContactSupport: () => _showProfileRequestSheet(
              context,
              ref,
              title: 'Contact OMC support',
              topic: 'Profile / account support',
              label: 'How can OMC help?',
              hint: 'Example: I need help with my profile, login, or account.',
              submitLabel: 'Submit support request',
            ),
            onRefresh: () async {
              ref.invalidate(profileSummaryProvider);
              _showBackendPendingSnack(context, 'Refreshing profile data...');
              await ref.read(profileSummaryProvider.future);
              if (!context.mounted) return;
              _showBackendPendingSnack(context, 'Profile data refreshed.');
            },
          )
        else
          PremiumCard(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_rounded,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Text(
                    'This is an internal OMC account. Customer profile actions are hidden for staff users.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        const _ProfileFootnote(),
      ],
    );
  }

  Future<void> _changeProfilePhoto(BuildContext context, WidgetRef ref) async {
    if (_profilePhotoUploadInFlight) {
      _showBackendPendingSnack(
        context,
        'Profile photo upload is already running.',
      );
      return;
    }

    _profilePhotoUploadInFlight = true;
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 88,
      );

      if (image == null) return;
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading profile photo...')),
      );

      await ref
          .read(profileRepositoryProvider)
          .uploadProfileImage(filePath: image.path, fileName: image.name);

      ref.invalidate(profileSummaryProvider);
      await ref.read(profileSummaryProvider.future);

      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile photo updated.')));
    } catch (error) {
      if (!context.mounted) return;
      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Profile photo not updated',
        fallbackMessage: 'Could not update profile photo. Please try again.',
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
    } finally {
      _profilePhotoUploadInFlight = false;
    }
  }

  Future<void> _submitProfileUpdateRequest(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await _showProfileRequestSheet(
      context,
      ref,
      title: 'Edit profile request',
      topic: 'Profile update request',
      label: 'What profile details should OMC update?',
      hint:
          'Example: Update my company name to ABC Pvt Ltd and NTN to 1234567-8.',
      submitLabel: 'Submit profile request',
      includeProfileSnapshot: true,
    );
  }

  Future<void> _submitContactUpdateRequest(
    BuildContext context,
    WidgetRef ref,
  ) async {
    await _showProfileRequestSheet(
      context,
      ref,
      title: 'Update contact info',
      topic: 'Contact update request',
      label: 'What contact details should OMC update?',
      hint: 'Example: Change my phone number to 03XXXXXXXXX.',
      submitLabel: 'Submit contact request',
      includeProfileSnapshot: true,
    );
  }

  Future<void> _showProfileRequestSheet(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required String topic,
    required String label,
    required String hint,
    required String submitLabel,
    bool includeProfileSnapshot = false,
  }) async {
    final controller = TextEditingController();

    final message = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return _ProfileRequestSheet(
          title: title,
          label: label,
          hint: hint,
          submitLabel: submitLabel,
          controller: controller,
        );
      },
    );

    controller.dispose();

    final cleanMessage = message?.trim();
    if (cleanMessage == null || cleanMessage.isEmpty) return;
    if (!context.mounted) return;

    final profileSnapshot = includeProfileSnapshot
        ? '''

Current account:
Name: ${profile.displayName}
Email: ${profile.email}
Phone: ${profile.phone ?? 'Not available'}
CNIC / Tax ID: ${profile.cnic ?? 'Not available'}
NTN: ${profile.ntn ?? 'Not available'}
Company: ${profile.companyName ?? 'Not available'}'''
        : '';

    if (_profileRequestSubmissionInFlight) {
      _showBackendPendingSnack(
        context,
        'A profile request is already being submitted.',
      );
      return;
    }

    _profileRequestSubmissionInFlight = true;
    try {
      await ref
          .read(supportRepositoryProvider)
          .createSupportTicket(
            topic: topic,
            message: '$cleanMessage$profileSnapshot',
          );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$title submitted to OMC support.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Request not submitted',
        fallbackMessage:
            'Could not submit request right now. Your entered details were not changed.',
      );
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(failure.message)));
    } finally {
      _profileRequestSubmissionInFlight = false;
    }
  }

  void _showBackendPendingSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ProfileRequestSheet extends StatelessWidget {
  const _ProfileRequestSheet({
    required this.title,
    required this.label,
    required this.hint,
    required this.submitLabel,
    required this.controller,
  });

  final String title;
  final String label;
  final String hint;
  final String submitLabel;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset + 16),
      child: PremiumCard(
        padding: const EdgeInsets.all(20),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.edit_note_rounded,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                minLines: 4,
                maxLines: 7,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  labelText: label,
                  hintText: hint,
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    final text = controller.text.trim();
                    if (text.length < 10) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please enter at least 10 characters.'),
                        ),
                      );
                      return;
                    }

                    Navigator.of(context).pop(text);
                  },
                  icon: const Icon(Icons.send_rounded),
                  label: Text(submitLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
    this.avatarUrl,
    this.onChangePhoto,
  });

  final String initials;
  final String displayName;
  final String email;
  final String customerType;
  final String approvalStatus;
  final String? status;
  final String? avatarUrl;
  final VoidCallback? onChangePhoto;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          _ProfileAvatar(
            initials: initials,
            avatarUrl: avatarUrl,
            onChangePhoto: onChangePhoto,
          ),
          const SizedBox(height: 16),
          Text(
            displayName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 23,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.25,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            email,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
              if (_cleanProfileChipLabel(status) != null)
                _ProfileStatusChip(label: _cleanProfileChipLabel(status)!),
              _ProfileStatusChip(label: customerType),
              _ProfileStatusChip(label: approvalStatus),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileStatusChip extends StatelessWidget {
  const _ProfileStatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final style = _profileChipStyle(label);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: style.border),
      ),
      child: Text(
        label.trim(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: style.foreground,
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.05,
        ),
      ),
    );
  }
}

class _ProfileChipStyle {
  const _ProfileChipStyle({
    required this.foreground,
    required this.background,
    required this.border,
  });

  final Color foreground;
  final Color background;
  final Color border;
}

String? _cleanProfileChipLabel(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return null;
  return text;
}

_ProfileChipStyle _profileChipStyle(String rawLabel) {
  final label = rawLabel.trim().toLowerCase();

  if (label.contains('reject') ||
      label.contains('suspend') ||
      label.contains('block') ||
      label.contains('inactive') ||
      label.contains('disabled') ||
      label.contains('failed')) {
    return const _ProfileChipStyle(
      foreground: Color(0xFFB42318),
      background: Color(0xFFFFF1F0),
      border: Color(0xFFFFD5D2),
    );
  }

  if (label.contains('pending') ||
      label.contains('review') ||
      label.contains('sync') ||
      label.contains('draft') ||
      label.contains('waiting') ||
      label.contains('late')) {
    return const _ProfileChipStyle(
      foreground: Color(0xFFB54708),
      background: Color(0xFFFFF7E6),
      border: Color(0xFFFFE1A6),
    );
  }

  if (label.contains('admin') ||
      label.contains('manager') ||
      label.contains('support') ||
      label.contains('internal') ||
      label.contains('staff')) {
    return const _ProfileChipStyle(
      foreground: Color(0xFF53389E),
      background: Color(0xFFF4F0FF),
      border: Color(0xFFD8CCFF),
    );
  }

  if (label.contains('approved') ||
      label.contains('active') ||
      label.contains('verified') ||
      label.contains('complete') ||
      label.contains('success')) {
    return const _ProfileChipStyle(
      foreground: Color(0xFF067647),
      background: Color(0xFFEAF8F0),
      border: Color(0xFFBFE8D0),
    );
  }

  if (label.contains('customer') ||
      label.contains('client') ||
      label.contains('individual')) {
    return const _ProfileChipStyle(
      foreground: Color(0xFF175CD3),
      background: Color(0xFFEFF6FF),
      border: Color(0xFFB8D7FF),
    );
  }

  if (label.contains('company') ||
      label.contains('business') ||
      label.contains('corporate') ||
      label.contains('organization')) {
    return const _ProfileChipStyle(
      foreground: Color(0xFF53389E),
      background: Color(0xFFF4F0FF),
      border: Color(0xFFD8CCFF),
    );
  }

  if (label.contains('guest') || label.contains('unknown')) {
    return const _ProfileChipStyle(
      foreground: Color(0xFF475467),
      background: Color(0xFFF2F4F7),
      border: Color(0xFFD0D5DD),
    );
  }

  return const _ProfileChipStyle(
    foreground: Color(0xFF344054),
    background: Color(0xFFF8FAFC),
    border: Color(0xFFE2E8F0),
  );
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.initials,
    required this.avatarUrl,
    required this.onChangePhoto,
  });

  final String initials;
  final String? avatarUrl;
  final VoidCallback? onChangePhoto;

  @override
  Widget build(BuildContext context) {
    final cleanAvatarUrl = avatarUrl?.trim();
    final hasImage = cleanAvatarUrl != null && cleanAvatarUrl.isNotEmpty;
    final imageUrl = hasImage ? ApiConfig.resolveFileUrl(cleanAvatarUrl) : null;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 86,
          height: 86,
          decoration: BoxDecoration(
            color: AppTheme.primary,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: 0.20),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          alignment: Alignment.center,
          child: imageUrl == null
              ? Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                )
              : Image.network(
                  imageUrl,
                  width: 86,
                  height: 86,
                  fit: BoxFit.cover,
                  webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                  errorBuilder: (context, error, stackTrace) => Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
        ),
        if (onChangePhoto != null)
          Positioned(
            right: -4,
            bottom: -4,
            child: Material(
              color: AppTheme.textPrimary,
              borderRadius: BorderRadius.circular(999),
              child: InkWell(
                onTap: onChangePhoto,
                borderRadius: BorderRadius.circular(999),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: const Icon(
                    Icons.camera_alt_rounded,
                    color: Colors.white,
                    size: 17,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

String _initials(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 'OMC';
  final parts = trimmed.split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
  final initials = parts.take(2).map((part) => part[0].toUpperCase()).join();
  return initials.isEmpty ? 'OMC' : initials;
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
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
    final color = _profileIconColor(icon);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Color _profileIconColor(IconData icon) {
  if (icon == Icons.email_outlined) return OmcPremium.services;
  if (icon == Icons.phone_outlined) return OmcPremium.payments;
  if (icon == Icons.workspace_premium_outlined ||
      icon == Icons.admin_panel_settings_outlined) {
    return OmcPremium.leads;
  }
  if (icon == Icons.badge_outlined) return OmcPremium.documents;
  if (icon == Icons.business_outlined) return OmcPremium.track;
  if (icon == Icons.confirmation_number_outlined) return OmcPremium.tasks;
  if (icon == Icons.verified_user_outlined) return OmcPremium.success;
  return OmcPremium.system;
}

class _DividerIndent extends StatelessWidget {
  const _DividerIndent();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 74,
      endIndent: 18,
      color: AppTheme.border.withValues(alpha: 0.7),
    );
  }
}

class _ProfileFootnote extends StatelessWidget {
  const _ProfileFootnote();

  @override
  Widget build(BuildContext context) {
    return const Text(
      'Profile information is managed by OMC. Some changes may require verification before they appear in your account.',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: AppTheme.textMuted,
        fontSize: 12,
        height: 1.45,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _LoadingBar extends StatelessWidget {
  const _LoadingBar({this.widthFactor = 1, this.height = 11});

  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppTheme.cardSoft,
          borderRadius: BorderRadius.circular(999),
        ),
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
      height: 32,
      decoration: BoxDecoration(
        color: AppTheme.cardSoft,
        borderRadius: BorderRadius.circular(999),
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
        color: AppTheme.cardSoft,
        borderRadius: BorderRadius.circular(15),
      ),
    );
  }
}
