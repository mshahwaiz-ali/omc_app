import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/design_tokens.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/app_labeled_field.dart';
import '../../../core/config/api_config.dart';
import '../../../core/diagnostics/omc_widget_keys.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/omc_premium.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_empty_state.dart';
import '../../auth/application/auth_controller.dart';
import '../../support/data/support_repository.dart';
import '../data/profile_repository.dart';
import '../data/profile_summary.dart';

bool _profileV2PhotoUploadInFlight = false;
bool _profileV2SupportSubmissionInFlight = false;
final ValueNotifier<bool> _profileV2PhotoUploading = ValueNotifier<bool>(false);
final Map<String, String> _profileV2SupportDraftsByOwner = <String, String>{};

class ProfileV2Screen extends ConsumerWidget {
  const ProfileV2Screen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileSummaryProvider);

    return Scaffold(
      key: OmcWidgetKeys.profileScreen,
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: RefreshIndicator.adaptive(
          onRefresh: () => _refreshProfile(context, ref, showSuccess: false),
          child: profileAsync.when(
            loading: () => const _ProfileLoadingView(),
            error: (error, _) => _ProfileUnavailableView(
              fallbackProfile: ProfileSummary.fromUserId(
                ref.watch(authControllerProvider).userId,
              ),
              message: _profileErrorMessage(error),
              onRetry: () => ref.invalidate(profileSummaryProvider),
            ),
            data: (profile) {
              if (profile == null) {
                final fallback = ProfileSummary.fromUserId(
                  ref.watch(authControllerProvider).userId,
                );
                return _ProfileUnavailableView(
                  fallbackProfile: fallback,
                  message:
                      'Signed in as ${fallback.email}. Full profile details will appear when the backend profile is available.',
                  onRetry: () => ref.invalidate(profileSummaryProvider),
                );
              }

              return _ProfileContent(profile: profile, ref: ref);
            },
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

Future<void> _refreshProfile(
  BuildContext context,
  WidgetRef ref, {
  required bool showSuccess,
}) async {
  try {
    ref.invalidate(profileSummaryProvider);
    await ref.read(profileSummaryProvider.future);

    if (!context.mounted || !showSuccess) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Profile data refreshed.')));
  } catch (error) {
    if (!context.mounted) return;
    final failure = AppFailureClassifier.classify(
      error,
      fallbackTitle: 'Profile refresh failed',
      fallbackMessage:
          'Profile data could not be refreshed right now. Please try again.',
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(failure.message)));
  }
}

class _ProfileContent extends StatelessWidget {
  const _ProfileContent({required this.profile, required this.ref});

  final ProfileSummary profile;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final isInternal =
        profile.canAccessInternalWorkspace || profile.capabilities.isInternal;
    final typeLabel = profile.customerType?.trim().isNotEmpty == true
        ? profile.customerType!.trim()
        : isInternal
        ? 'Internal account'
        : 'OMC Customer';
    final approvalLabel = isInternal
        ? 'Internal access'
        : profile.approvalStatus?.trim().isNotEmpty == true
        ? profile.approvalStatus!.trim()
        : profile.status?.trim().isNotEmpty == true
        ? profile.status!.trim()
        : 'Account active';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
      children: [
        Text('Profile', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 4),
        Text(
          'Your OMC identity and account information',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 18),
        _IdentityCard(
          profile: profile,
          isInternal: isInternal,
          onChangePhoto: () => _changeProfilePhoto(context, ref),
        ),
        const SizedBox(height: 12),
        _AccountStateCard(
          status: profile.status,
          approvalStatus: approvalLabel,
          typeLabel: typeLabel,
          isInternal: isInternal,
        ),
        const SizedBox(height: 22),
        const _SectionHeading(title: 'Personal & contact'),
        const SizedBox(height: 10),
        _InfoSection(
          rows: [
            _InfoRowData(
              icon: Icons.email_outlined,
              label: 'Email',
              value: profile.email,
            ),
            _InfoRowData(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: _display(profile.phone),
            ),
            if (profile.whatsappNo?.trim().isNotEmpty == true)
              _InfoRowData(
                icon: Icons.chat_outlined,
                label: 'WhatsApp',
                value: profile.whatsappNo!.trim(),
              ),
            if (profile.address?.trim().isNotEmpty == true)
              _InfoRowData(
                icon: Icons.location_on_outlined,
                label: 'Address',
                value: profile.address!.trim(),
              ),
          ],
        ),
        const SizedBox(height: 22),
        _SectionHeading(
          title: isInternal ? 'Internal access' : 'Business & tax',
        ),
        const SizedBox(height: 10),
        _InfoSection(
          rows: isInternal
              ? [
                  _InfoRowData(
                    icon: Icons.admin_panel_settings_outlined,
                    label: 'Internal role',
                    value: typeLabel,
                  ),
                  const _InfoRowData(
                    icon: Icons.business_center_outlined,
                    label: 'Account type',
                    value: 'OMC internal account',
                  ),
                  _InfoRowData(
                    icon: Icons.verified_user_outlined,
                    label: 'Access scope',
                    value: approvalLabel,
                  ),
                ]
              : [
                  _InfoRowData(
                    icon: Icons.person_outline_rounded,
                    label: 'Customer type',
                    value: typeLabel,
                  ),
                  _InfoRowData(
                    icon: Icons.business_outlined,
                    label: 'Company',
                    value: _display(profile.companyName),
                  ),
                  _InfoRowData(
                    icon: Icons.confirmation_number_outlined,
                    label: 'NTN',
                    value: _display(profile.ntn),
                  ),
                  _InfoRowData(
                    icon: Icons.badge_outlined,
                    label: 'CNIC / Tax ID',
                    value: _display(profile.cnic),
                  ),
                ],
        ),
        if (!isInternal) ...[
          const SizedBox(height: 22),
          const _SectionHeading(title: 'Profile actions'),
          const SizedBox(height: 10),
          _ActionSection(
            children: [
              _ActionRow(
                icon: Icons.manage_accounts_outlined,
                title: 'Manage profile',
                supporting:
                    'Update fields allowed by your backend profile policy.',
                onTap: () => context.push('/profile/edit'),
              ),
              const Divider(height: 1),
              _ActionRow(
                icon: Icons.support_agent_outlined,
                title: 'Contact support',
                supporting: 'Get help with your profile, login or account.',
                onTap: () => _showProfileSupportSheet(context, ref, profile),
              ),
            ],
          ),
        ] else ...[
          const SizedBox(height: 22),
          PremiumCard(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.admin_panel_settings_outlined,
                  color: AppTheme.textSecondary,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Customer profile editing is not shown for this internal OMC account.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => _refreshProfile(context, ref, showSuccess: true),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Refresh profile'),
          ),
        ),
      ],
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({
    required this.profile,
    required this.isInternal,
    required this.onChangePhoto,
  });

  final ProfileSummary profile;
  final bool isInternal;
  final VoidCallback onChangePhoto;

  @override
  Widget build(BuildContext context) {
    final imageUrl = _safeProfileImageUrl(profile.avatarUrl);
    final initials = _initials(profile.displayName);
    final textScaler = MediaQuery.textScalerOf(context).scale(1);

    final avatar = Semantics(
      label: imageUrl == null
          ? 'Profile photo placeholder for ${profile.displayName}'
          : 'Profile photo for ${profile.displayName}',
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 88,
            height: 88,
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(28),
            ),
            child: imageUrl == null
                ? Text(
                    initials,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : Image.network(
                    imageUrl,
                    width: 88,
                    height: 88,
                    fit: BoxFit.cover,
                    webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                    errorBuilder: (_, _, _) => Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
          ),
          Positioned(
            right: -8,
            bottom: -8,
            child: Tooltip(
              message: 'Change profile photo',
              child: Material(
                color: AppTheme.textPrimary,
                shape: const CircleBorder(),
                child: ValueListenableBuilder<bool>(
                  valueListenable: _profileV2PhotoUploading,
                  builder: (context, uploading, _) => InkWell(
                    customBorder: const CircleBorder(),
                    onTap: uploading ? null : onChangePhoto,
                    child: SizedBox(
                      width: 48,
                      height: 48,
                      child: uploading
                          ? const Padding(
                              padding: EdgeInsets.all(14),
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.camera_alt_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    final identity = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          profile.displayName,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 5),
        Text(
          profile.email,
          softWrap: true,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Text(
          isInternal ? 'OMC internal identity' : 'OMC customer identity',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );

    return ValueListenableBuilder<bool>(
      valueListenable: _profileV2PhotoUploading,
      builder: (context, uploading, _) {
        final identityArea = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            identity,
            if (uploading) ...[
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                label: 'Uploading profile photo',
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Uploading profile photo…',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );

        return PremiumCard(
          padding: const EdgeInsets.all(20),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final stack = constraints.maxWidth < 360 || textScaler > 1.35;
              if (stack) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [avatar, const SizedBox(height: 20), identityArea],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  avatar,
                  const SizedBox(width: 20),
                  Expanded(child: identityArea),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _AccountStateCard extends StatelessWidget {
  const _AccountStateCard({
    required this.status,
    required this.approvalStatus,
    required this.typeLabel,
    required this.isInternal,
  });

  final String? status;
  final String approvalStatus;
  final String typeLabel;
  final bool isInternal;

  @override
  Widget build(BuildContext context) {
    final statusLabel = status?.trim().isNotEmpty == true
        ? status!.trim()
        : approvalStatus;

    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Account state', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OmcStatusBadge(
                label: approvalStatus,
                color: OmcPremium.statusColor(approvalStatus),
              ),
              if (statusLabel.toLowerCase() != approvalStatus.toLowerCase())
                OmcStatusBadge(
                  label: statusLabel,
                  color: OmcPremium.statusColor(statusLabel),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            isInternal
                ? 'Internal role: $typeLabel. Customer type is not used as an access label on this screen.'
                : 'Customer type: $typeLabel.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleLarge);
  }
}

class _InfoSection extends StatelessWidget {
  const _InfoSection({required this.rows});
  final List<_InfoRowData> rows;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var index = 0; index < rows.length; index++) ...[
            _InfoRow(data: rows[index]),
            if (index != rows.length - 1) const Divider(height: 1),
          ],
        ],
      ),
    );
  }
}

class _InfoRowData {
  const _InfoRowData({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.data});
  final _InfoRowData data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.cardSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(data.icon, color: AppTheme.textSecondary, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 3),
                Text(
                  data.value,
                  softWrap: true,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionSection extends StatelessWidget {
  const _ActionSection({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(children: children),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.supporting,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String supporting;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.cardSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppTheme.textSecondary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        supporting,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textSecondary,
                ),
              ],
            ),
          ),
        ),
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
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
      children: [
        Text('Profile', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 18),
        _FallbackIdentity(profile: fallbackProfile),
        const SizedBox(height: 14),
        PremiumEmptyState(
          icon: Icons.person_search_outlined,
          title: 'Profile details unavailable',
          message: message,
          actionLabel: 'Retry profile sync',
          onAction: onRetry,
        ),
      ],
    );
  }
}

class _FallbackIdentity extends StatelessWidget {
  const _FallbackIdentity({required this.profile});
  final ProfileSummary profile;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              _initials(profile.displayName),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.displayName,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 4),
                Text(
                  profile.email,
                  softWrap: true,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileLoadingView extends StatelessWidget {
  const _ProfileLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
      children: [
        const _SkeletonLine(width: 120, height: 26),
        const SizedBox(height: 18),
        PremiumCard(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: const [
              _SkeletonBox(size: 88),
              SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonLine(height: 20),
                    SizedBox(height: 10),
                    _SkeletonLine(width: 190, height: 14),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (var index = 0; index < 4; index++) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: _SkeletonLine(height: 48),
          ),
          if (index != 3) const Divider(height: 1),
        ],
      ],
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({this.width, required this.height});
  final double? width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? double.infinity,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(28),
      ),
    );
  }
}

Future<void> _changeProfilePhoto(BuildContext context, WidgetRef ref) async {
  if (_profileV2PhotoUploadInFlight) {
    _showPendingSnack(context, 'Profile photo upload is already running.');
    return;
  }

  _profileV2PhotoUploadInFlight = true;
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
    _profileV2PhotoUploading.value = true;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Uploading profile photo...')));

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
    _profileV2PhotoUploading.value = false;
    _profileV2PhotoUploadInFlight = false;
  }
}

Future<void> _showProfileSupportSheet(
  BuildContext context,
  WidgetRef ref,
  ProfileSummary profile,
) async {
  final authUserId = ref.read(authControllerProvider).userId?.trim();
  final ownerKey = authUserId?.isNotEmpty == true
      ? authUserId!
      : profile.email.trim().toLowerCase();
  final controller = TextEditingController(
    text: _profileV2SupportDraftsByOwner[ownerKey] ?? '',
  );
  final message = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => _ProfileSupportSheet(controller: controller),
  );
  controller.dispose();

  final cleanMessage = message?.trim();
  if (cleanMessage == null || cleanMessage.isEmpty || !context.mounted) return;

  _profileV2SupportDraftsByOwner[ownerKey] = cleanMessage;
  if (_profileV2SupportSubmissionInFlight) {
    _showPendingSnack(
      context,
      'A profile request is already being submitted. Your message is retained.',
    );
    return;
  }

  _profileV2SupportSubmissionInFlight = true;
  try {
    await ref
        .read(supportRepositoryProvider)
        .createSupportTicket(
          topic: 'Profile / account support',
          message: cleanMessage,
        );

    _profileV2SupportDraftsByOwner.remove(ownerKey);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Contact OMC support submitted to OMC support.'),
      ),
    );
  } catch (error) {
    _profileV2SupportDraftsByOwner[ownerKey] = cleanMessage;
    if (!context.mounted) return;
    final failure = AppFailureClassifier.classify(
      error,
      fallbackTitle: 'Request not submitted',
      fallbackMessage: 'Could not submit request right now. Please try again.',
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${failure.message} Your message is retained.')),
    );
  } finally {
    _profileV2SupportSubmissionInFlight = false;
  }
}

class _ProfileSupportSheet extends StatefulWidget {
  const _ProfileSupportSheet({required this.controller});
  final TextEditingController controller;

  @override
  State<_ProfileSupportSheet> createState() => _ProfileSupportSheetState();
}

class _ProfileSupportSheetState extends State<_ProfileSupportSheet> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppLayout.formMaxWidth),
          child: Material(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.sheet),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.82,
              ),
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Contact OMC support',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Describe the profile, login or account issue.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 16),
                      AppLabeledField(
                        label: 'How can OMC help?',
                        isRequired: true,
                        child: TextFormField(
                          controller: widget.controller,
                          minLines: 4,
                          maxLines: 7,
                          textInputAction: TextInputAction.newline,
                          decoration: const InputDecoration(
                            hintText:
                                'Example: I need help with my profile, login, or account.',
                          ),
                          validator: (value) {
                            if ((value?.trim().length ?? 0) < 10) {
                              return 'Enter at least 10 characters.';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () {
                          if (_formKey.currentState?.validate() != true) return;
                          Navigator.of(
                            context,
                          ).pop(widget.controller.text.trim());
                        },
                        icon: const Icon(Icons.send_rounded),
                        label: const Text('Submit support request'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _showPendingSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

String? _safeProfileImageUrl(String? value) {
  final clean = value?.trim();
  if (clean == null || clean.isEmpty) return null;

  final resolved = ApiConfig.resolveFileUrl(clean);
  if (resolved == null || resolved.trim().isEmpty) return null;

  final uri = Uri.tryParse(resolved);
  if (uri == null || !uri.hasScheme || uri.host.trim().isEmpty) return null;

  final scheme = uri.scheme.toLowerCase();
  if (scheme != 'https' && scheme != 'http') return null;
  return uri.toString();
}

String _initials(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 'OMC';
  final parts = trimmed.split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
  final initials = parts.take(2).map((part) => part[0].toUpperCase()).join();
  return initials.isEmpty ? 'OMC' : initials;
}

String _display(String? value) {
  final clean = value?.trim();
  return clean == null || clean.isEmpty ? 'Not available' : clean;
}
