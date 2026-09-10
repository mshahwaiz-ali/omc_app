import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/design_tokens.dart';
import '../../../app/theme.dart';
import '../../../core/config/env.dart';
import '../../../core/forms/dirty_form_controller.dart';
import '../../../core/network/api_error.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/app_back_header.dart';
import '../../../core/widgets/app_labeled_field.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_state.dart';
import '../../../core/widgets/omc_premium.dart';
import '../../../core/widgets/premium_card.dart';
import '../data/profile_repository.dart';
import '../data/profile_summary.dart';

class EditProfileV2Screen extends ConsumerWidget {
  const EditProfileV2Screen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileSummaryProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: const AppBackHeader(
        title: 'Profile details',
        subtitle: 'Manage editable account information',
        fallbackRoute: '/profile',
      ),
      body: SafeArea(
        top: false,
        child: profileAsync.when(
          data: (profile) {
            if (profile == null) {
              return const _ProfileEditorUnavailable();
            }
            return _ProfileEditorOverview(profile: profile);
          },
          loading: () => const _ProfileEditorLoading(),
          error: (error, _) => _ProfileEditorError(
            error: error,
            onRetry: () => ref.invalidate(profileSummaryProvider),
          ),
        ),
      ),
    );
  }
}

class _ProfileEditorOverview extends ConsumerWidget {
  const _ProfileEditorOverview({required this.profile});
  final ProfileSummary profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isInternal =
        profile.capabilities.canAccessInternalWorkspace ||
        profile.capabilities.isInternal;
    final workAddressMapsEnabled = Env.workAddressMapsEnabled;

    return RefreshIndicator.adaptive(
      onRefresh: () async {
        ref.invalidate(profileSummaryProvider);
        await ref.read(profileSummaryProvider.future);
      },
      child: OmcPageListView(
        topPadding: 12,
        bottomPadding: 40,
        children: [
          _ProfileIdentitySummary(profile: profile, isInternal: isInternal),
          const SizedBox(height: 22),
          const _SectionHeading(
            title: 'Personal information',
            supporting:
                'Fields that can be updated directly from your account.',
          ),
          const SizedBox(height: 10),
          _EditableSection(
            icon: Icons.person_outline_rounded,
            title: 'Personal',
            rows: [_ValueRow(label: 'Full name', value: profile.displayName)],
            onEdit: () => _openPersonalSheet(context, ref, profile),
          ),
          const SizedBox(height: 12),
          _EditableSection(
            icon: Icons.contact_phone_outlined,
            title: 'Contact',
            rows: [
              _ValueRow(label: 'Mobile', value: _displayValue(profile.phone)),
              _ValueRow(
                label: 'WhatsApp',
                value: _displayValue(profile.whatsappNo),
              ),
              if (isInternal || !workAddressMapsEnabled)
                _ValueRow(
                  label: 'Address',
                  value: _displayValue(profile.address),
                ),
            ],
            onEdit: () => _openContactSheet(context, ref, profile),
          ),
          const SizedBox(height: 22),
          _SectionHeading(
            title: isInternal
                ? 'Protected account identity'
                : 'Business & tax identity',
            supporting: isInternal
                ? 'Staff identifiers are protected account data.'
                : 'Each field clearly shows whether it can be added, corrected once, or is locked.',
          ),
          const SizedBox(height: 10),
          if (isInternal)
            _InternalAccountCard(profile: profile)
          else
            _IdentityBusinessCard(
              profile: profile,
              onEditField: (fieldName) => _openProtectedProfileFieldSheet(
                context,
                ref,
                profile,
                fieldName,
              ),
            ),
          if (isInternal) ...[
            const SizedBox(height: 22),
            const _SectionHeading(
              title: 'Professional information',
              supporting:
                  'Qualifications and working profile for this internal account.',
            ),
            const SizedBox(height: 10),
            _EditableSection(
              icon: Icons.workspace_premium_outlined,
              title: 'Professional details',
              rows: [
                _ValueRow(
                  label: 'Education',
                  value: _displayValue(profile.education),
                ),
                _ValueRow(
                  label: 'Experience',
                  value: _displayValue(profile.experience),
                ),
                _ValueRow(
                  label: 'Remarks',
                  value: _displayValue(profile.remarks),
                ),
              ],
              onEdit: () => _openProfessionalSheet(context, ref, profile),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            'Changes are applied immediately and recorded in your account history.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ProfileIdentitySummary extends StatelessWidget {
  const _ProfileIdentitySummary({
    required this.profile,
    required this.isInternal,
  });
  final ProfileSummary profile;
  final bool isInternal;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            profile.displayName,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          Text(profile.email, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.info_outline_rounded,
                size: 19,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isInternal
                      ? 'Editable professional/contact information is separate from protected staff identifiers.'
                      : 'Verified identity fields never become editable unless the backend edit policy explicitly allows it.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, required this.supporting});
  final String title;
  final String supporting;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 4),
        Text(supporting, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }
}

class _EditableSection extends StatelessWidget {
  const _EditableSection({
    required this.icon,
    required this.title,
    required this.rows,
    required this.onEdit,
  });

  final IconData icon;
  final String title;
  final List<Widget> rows;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 10, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.cardSoft,
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  ),
                  child: Icon(icon, color: AppTheme.textSecondary, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Column(children: rows),
          ),
        ],
      ),
    );
  }
}

class _ValueRow extends StatelessWidget {
  const _ValueRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.3;
          if (constraints.maxWidth < 330 || largeText) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 3),
                Text(value, style: Theme.of(context).textTheme.bodyLarge),
              ],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 105,
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _InternalAccountCard extends StatelessWidget {
  const _InternalAccountCard({required this.profile});
  final ProfileSummary profile;

  @override
  Widget build(BuildContext context) {
    final rows = <_ValueRow>[
      _ValueRow(label: 'Email', value: profile.email),
      _ValueRow(label: 'Username', value: _displayValue(profile.username)),
      _ValueRow(
        label: 'Account type',
        value: _displayValue(profile.registerAs),
      ),
      if (profile.cnic?.trim().isNotEmpty == true)
        _ValueRow(label: 'CNIC', value: profile.cnic!.trim()),
    ];

    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: () => _showLockedIdentityInfo(context),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    color: AppTheme.textSecondary,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Verified account identifiers',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.info_outline_rounded,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
            child: Column(children: rows),
          ),
        ],
      ),
    );
  }
}

class _IdentityBusinessCard extends StatelessWidget {
  const _IdentityBusinessCard({
    required this.profile,
    required this.onEditField,
  });

  final ProfileSummary profile;
  final ValueChanged<String> onEditField;

  @override
  Widget build(BuildContext context) {
    final policy = profile.profileEditPolicy;
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _IdentityBusinessRow(
            icon: Icons.email_outlined,
            label: 'Email',
            value: profile.email,
            policy: policy.email,
          ),
          const Divider(height: 1),
          _IdentityBusinessRow(
            icon: Icons.badge_outlined,
            label: 'CNIC',
            value: _displayValue(profile.cnic),
            policy: policy.cnic,
            onTap: policy.cnic.canEdit ? () => onEditField('cnic') : null,
          ),
          const Divider(height: 1),
          _IdentityBusinessRow(
            icon: Icons.confirmation_number_outlined,
            label: 'NTN',
            value: _displayValue(profile.ntn),
            policy: policy.ntn,
            onTap: policy.ntn.canEdit ? () => onEditField('ntn') : null,
          ),
          const Divider(height: 1),
          _IdentityBusinessRow(
            icon: Icons.business_outlined,
            label: 'Company name',
            value: _displayValue(profile.companyName),
            policy: policy.companyName,
            onTap: policy.companyName.canEdit
                ? () => onEditField('company_name')
                : null,
          ),
        ],
      ),
    );
  }
}

class _IdentityBusinessRow extends StatelessWidget {
  const _IdentityBusinessRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.policy,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final ProfileFieldEditPolicy policy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final canEdit = policy.canEdit && onTap != null;
    final actionLabel = switch (policy.mode) {
      ProfileEditMode.add => 'Add',
      ProfileEditMode.correct => 'Update once',
      ProfileEditMode.locked => 'Locked',
      ProfileEditMode.unavailable => 'Unavailable',
    };
    final actionIcon = canEdit
        ? Icons.chevron_right_rounded
        : Icons.lock_outline_rounded;

    return Semantics(
      button: canEdit,
      label: '$label, $value, $actionLabel',
      child: InkWell(
        onTap: canEdit ? onTap : null,
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
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  ),
                  child: Icon(icon, color: AppTheme.textSecondary, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 3),
                      Text(
                        value,
                        softWrap: true,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            actionIcon,
                            size: 17,
                            color: canEdit
                                ? Theme.of(context).colorScheme.primary
                                : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              actionLabel,
                              style: TextStyle(
                                color: canEdit
                                    ? Theme.of(context).colorScheme.primary
                                    : AppTheme.textSecondary,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _openPersonalSheet(
  BuildContext context,
  WidgetRef ref,
  ProfileSummary profile,
) async {
  final controller = TextEditingController(text: profile.displayName);

  await _showEditSheet(
    context: context,
    ref: ref,
    title: 'Personal information',
    subtitle: 'Update the name shown across your OMC account.',
    fields: [
      _SheetTextField(
        controller: controller,
        label: 'Full name',
        icon: Icons.person_outline_rounded,
        textCapitalization: TextCapitalization.words,
        validator: (value) {
          final clean = value?.trim() ?? '';
          if (clean.length < 2) {
            return 'Enter your full name.';
          }
          return null;
        },
      ),
    ],
    payloadBuilder: () => {'full_name': controller.text.trim()},
  );

  controller.dispose();
}

Future<void> _openContactSheet(
  BuildContext context,
  WidgetRef ref,
  ProfileSummary profile,
) async {
  final initialPhone = (profile.phone ?? '').trim();
  final initialWhatsapp = (profile.whatsappNo ?? '').trim();
  final phone = TextEditingController(text: initialPhone);
  final whatsapp = TextEditingController(text: initialWhatsapp);
  final isInternal =
      profile.capabilities.canAccessInternalWorkspace ||
      profile.capabilities.isInternal;
  final useLegacyAddress = isInternal || !Env.workAddressMapsEnabled;
  final initialAddress = useLegacyAddress
      ? (profile.address ?? '').trim()
      : null;
  final address = initialAddress == null
      ? null
      : TextEditingController(text: initialAddress);

  await _showEditSheet(
    context: context,
    ref: ref,
    title: 'Contact information',
    subtitle:
        'Update only the details you need. Unchanged fields will stay as they are.',
    fields: [
      _SheetTextField(
        controller: phone,
        label: 'Mobile number',
        icon: Icons.phone_outlined,
        keyboardType: TextInputType.phone,
      ),
      _SheetTextField(
        controller: whatsapp,
        label: 'WhatsApp number',
        icon: Icons.chat_outlined,
        keyboardType: TextInputType.phone,
      ),
      if (address != null)
        _SheetTextField(
          controller: address,
          label: 'Address',
          icon: Icons.location_on_outlined,
          textCapitalization: TextCapitalization.sentences,
          minLines: 2,
          maxLines: 4,
        ),
    ],
    payloadBuilder: () {
      final payload = <String, dynamic>{};
      final nextPhone = phone.text.trim();
      final nextWhatsapp = whatsapp.text.trim();

      if (nextPhone != initialPhone) {
        payload['phone'] = nextPhone;
      }
      if (nextWhatsapp != initialWhatsapp) {
        payload['whatsapp_no'] = nextWhatsapp;
      }
      if (address != null) {
        final nextAddress = address.text.trim();
        if (nextAddress != initialAddress) {
          payload['address'] = nextAddress;
        }
      }
      return payload;
    },
  );

  phone.dispose();
  whatsapp.dispose();
  address?.dispose();
}

Future<void> _openProfessionalSheet(
  BuildContext context,
  WidgetRef ref,
  ProfileSummary profile,
) async {
  final initialEducation = (profile.education ?? '').trim();
  final initialExperience = (profile.experience ?? '').trim();
  final initialRemarks = (profile.remarks ?? '').trim();
  final education = TextEditingController(text: initialEducation);
  final experience = TextEditingController(text: initialExperience);
  final remarks = TextEditingController(text: initialRemarks);

  await _showEditSheet(
    context: context,
    ref: ref,
    title: 'Professional information',
    subtitle:
        'Update only the details you need. Unchanged fields will stay as they are.',
    fields: [
      _SheetTextField(
        controller: education,
        label: 'Education',
        icon: Icons.school_outlined,
        textCapitalization: TextCapitalization.sentences,
        minLines: 2,
        maxLines: 4,
      ),
      _SheetTextField(
        controller: experience,
        label: 'Experience',
        icon: Icons.timeline_outlined,
        textCapitalization: TextCapitalization.sentences,
        minLines: 2,
        maxLines: 5,
      ),
      _SheetTextField(
        controller: remarks,
        label: 'Remarks',
        icon: Icons.notes_outlined,
        textCapitalization: TextCapitalization.sentences,
        minLines: 2,
        maxLines: 5,
      ),
    ],
    payloadBuilder: () {
      final payload = <String, dynamic>{};
      final nextEducation = education.text.trim();
      final nextExperience = experience.text.trim();
      final nextRemarks = remarks.text.trim();

      if (nextEducation != initialEducation) {
        payload['education'] = nextEducation;
      }
      if (nextExperience != initialExperience) {
        payload['experience'] = nextExperience;
      }
      if (nextRemarks != initialRemarks) {
        payload['remarks'] = nextRemarks;
      }
      return payload;
    },
  );

  education.dispose();
  experience.dispose();
  remarks.dispose();
}

Future<void> _openProtectedProfileFieldSheet(
  BuildContext context,
  WidgetRef ref,
  ProfileSummary profile,
  String fieldName,
) async {
  final policy = switch (fieldName) {
    'cnic' => profile.profileEditPolicy.cnic,
    'ntn' => profile.profileEditPolicy.ntn,
    'company_name' => profile.profileEditPolicy.companyName,
    _ => const ProfileFieldEditPolicy.unavailable(),
  };

  if (!policy.canEdit) {
    return;
  }

  final currentValue = switch (fieldName) {
    'cnic' => profile.cnic ?? '',
    'ntn' => profile.ntn ?? '',
    'company_name' => profile.companyName ?? '',
    _ => '',
  };
  final label = switch (fieldName) {
    'cnic' => 'CNIC',
    'ntn' => 'NTN',
    'company_name' => 'Company name',
    _ => 'Profile detail',
  };
  final icon = switch (fieldName) {
    'cnic' => Icons.badge_outlined,
    'ntn' => Icons.confirmation_number_outlined,
    'company_name' => Icons.business_outlined,
    _ => Icons.edit_outlined,
  };
  final controller = TextEditingController(text: currentValue);

  String? validator(String? value) {
    final clean = value?.trim() ?? '';
    if (clean.isEmpty) {
      return '$label is required.';
    }
    if (fieldName == 'cnic') {
      final digits = clean.replaceAll(RegExp(r'\D'), '');
      if (digits.length != 13) {
        return 'CNIC must contain exactly 13 digits.';
      }
    }
    if (fieldName == 'ntn') {
      final digits = clean.replaceAll(RegExp(r'\D'), '');
      if (digits.length < 7 || digits.length > 9) {
        return 'NTN must contain 7 to 9 digits.';
      }
    }
    if (fieldName == 'company_name' && clean.length < 2) {
      return 'Enter a valid company name.';
    }
    return null;
  }

  final isAdd = policy.mode == ProfileEditMode.add;
  try {
    await _showEditSheet(
      context: context,
      ref: ref,
      title: isAdd ? 'Add $label' : 'Update $label',
      subtitle:
          'Enter this detail carefully. After you confirm and save it, it will be locked for self-service changes.',
      fields: [
        _SheetTextField(
          controller: controller,
          label: label,
          icon: icon,
          keyboardType: fieldName == 'cnic'
              ? TextInputType.number
              : TextInputType.text,
          textCapitalization: fieldName == 'company_name'
              ? TextCapitalization.words
              : TextCapitalization.none,
          validator: validator,
        ),
      ],
      payloadBuilder: () => {fieldName: controller.text.trim()},
      confirmationTitle: 'Confirm $label',
      confirmationMessage:
          'Please verify your $label carefully. Once saved, you will not be able to change it from the app.',
    );
  } finally {
    controller.dispose();
  }
}

Future<void> _showEditSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String title,
  required String subtitle,
  required List<Widget> fields,
  required Map<String, dynamic> Function() payloadBuilder,
  String? confirmationTitle,
  String? confirmationMessage,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => _ProfileEditSheet(
      title: title,
      subtitle: subtitle,
      fields: fields,
      payloadBuilder: payloadBuilder,
      confirmationTitle: confirmationTitle,
      confirmationMessage: confirmationMessage,
      ref: ref,
    ),
  );
}

class _ProfileEditSheet extends StatefulWidget {
  const _ProfileEditSheet({
    required this.title,
    required this.subtitle,
    required this.fields,
    required this.payloadBuilder,
    required this.ref,
    this.confirmationTitle,
    this.confirmationMessage,
  });

  final String title;
  final String subtitle;
  final List<Widget> fields;
  final Map<String, dynamic> Function() payloadBuilder;
  final WidgetRef ref;
  final String? confirmationTitle;
  final String? confirmationMessage;

  @override
  State<_ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends State<_ProfileEditSheet> {
  final _formKey = GlobalKey<FormState>();
  final _dirtyFormController = DirtyFormController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _dirtyFormController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();

    final confirmationMessage = widget.confirmationMessage?.trim() ?? '';
    if (confirmationMessage.isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.lock_outline_rounded),
          title: Text(widget.confirmationTitle ?? 'Confirm details'),
          content: Text(confirmationMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Review'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Confirm & save'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) {
        return;
      }
    }

    _dirtyFormController.beginSubmitting();
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final updated = await widget.ref
          .read(profileRepositoryProvider)
          .saveProfileDetails(widget.payloadBuilder());

      widget.ref.invalidate(profileSummaryProvider);
      await widget.ref.read(profileSummaryProvider.future);

      if (!mounted) {
        return;
      }
      _dirtyFormController.submissionSucceeded();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updated
                ? 'Profile updated successfully.'
                : 'No profile details changed.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Profile not updated',
        fallbackMessage: 'Your profile details could not be updated right now.',
      );
      final errorMessage =
          error is ApiError &&
              failure.type == AppFailureType.validation &&
              error.message.trim().isNotEmpty
          ? error.message.trim()
          : failure.message;
      _dirtyFormController.submissionFailed();
      setState(() => _error = errorMessage);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return UnsavedChangesGuard(
      controller: _dirtyFormController,
      child: Padding(
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
              clipBehavior: Clip.antiAlias,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
                child: Form(
                  key: _formKey,
                  onChanged: _dirtyFormController.markDirty,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        widget.title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        widget.subtitle,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      ..._withSpacing(widget.fields),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.dangerSoft,
                            borderRadius: BorderRadius.circular(
                              AppRadius.control,
                            ),
                          ),
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              color: AppTheme.danger,
                              fontSize: 14,
                              height: 1.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      AppButton(
                        label: 'Save',
                        icon: Icons.check_rounded,
                        isLoading: _saving,
                        onPressed: _saving ? null : _save,
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
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

class _SheetTextField extends StatelessWidget {
  const _SheetTextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.minLines = 1,
    this.maxLines = 1,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final int minLines;
  final int maxLines;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return AppLabeledField(
      label: label,
      isRequired: validator != null,
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        textCapitalization: textCapitalization,
        minLines: minLines,
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(
          prefixIcon: Icon(icon),
          alignLabelWithHint: maxLines > 1,
        ),
      ),
    );
  }
}

class _ProfileEditorLoading extends StatelessWidget {
  const _ProfileEditorLoading();

  @override
  Widget build(BuildContext context) {
    return OmcPageListView(
      topPadding: 12,
      bottomPadding: 40,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        PremiumCard(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _SkeletonLine(width: 180, height: 20),
              SizedBox(height: 10),
              _SkeletonLine(width: 230, height: 14),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (var index = 0; index < 3; index++) ...[
          PremiumCard(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _SkeletonLine(width: 140, height: 17),
                SizedBox(height: 12),
                _SkeletonLine(height: 15),
                SizedBox(height: 8),
                _SkeletonLine(width: 200, height: 15),
              ],
            ),
          ),
          if (index != 2) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _ProfileEditorUnavailable extends StatelessWidget {
  const _ProfileEditorUnavailable();

  @override
  Widget build(BuildContext context) {
    return const OmcPagePadding(
      topPadding: 20,
      bottomPadding: 20,
      child: AppEmptyState(
        icon: Icons.person_off_outlined,
        title: 'Profile details unavailable',
        message: 'Profile details are unavailable for editing right now.',
      ),
    );
  }
}

class _ProfileEditorError extends StatelessWidget {
  const _ProfileEditorError({required this.error, required this.onRetry});
  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return OmcPagePadding(
      topPadding: 20,
      bottomPadding: 20,
      child: AppErrorState.fromError(
        error: error,
        fallbackTitle: 'Profile unavailable',
        fallbackMessage: 'Profile details could not be loaded right now.',
        onRetry: onRetry,
      ),
    );
  }
}

void _showLockedIdentityInfo(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Verified account identifiers',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'Staff account identifiers are managed as protected account data. Contact OMC support if a verified administrative correction is required.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: () => Navigator.of(sheetContext).pop(),
            child: const Text('Understood'),
          ),
        ],
      ),
    ),
  );
}

List<Widget> _withSpacing(List<Widget> fields) {
  final result = <Widget>[];
  for (var index = 0; index < fields.length; index++) {
    result.add(fields[index]);
    if (index != fields.length - 1) {
      result.add(const SizedBox(height: 14));
    }
  }
  return result;
}

String _displayValue(String? value) {
  final clean = value?.trim();
  return clean == null || clean.isEmpty ? 'Not added' : clean;
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
