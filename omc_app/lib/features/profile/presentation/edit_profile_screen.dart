import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/premium_card.dart';
import '../data/profile_repository.dart';
import '../data/profile_summary.dart';

class EditProfileScreen extends ConsumerWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileSummaryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile details'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: () => context.pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: profileAsync.when(
        data: (profile) {
          if (profile == null) {
            return const _ProfileEditorUnavailable();
          }

          return _ProfileEditorOverview(profile: profile);
        },
        loading: () => const _ProfileEditorLoading(),
        error: (error, _) => _ProfileEditorError(error: error),
      ),
    );
  }
}

class _ProfileEditorOverview extends ConsumerWidget {
  const _ProfileEditorOverview({required this.profile});

  final ProfileSummary profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completion = _profileCompletion(profile);
    final isInternal =
        profile.capabilities.canAccessInternalWorkspace ||
        profile.capabilities.isInternal;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(profileSummaryProvider);
        await ref.read(profileSummaryProvider.future);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
        children: [
          _CompletionCard(profile: profile, completion: completion),
          const SizedBox(height: 18),
          _ProfileEditSectionCard(
            icon: Icons.person_outline_rounded,
            title: 'Personal information',
            subtitle: 'Your display name across the OMC app.',
            rows: [
              _ProfileValueRow(label: 'Full name', value: profile.displayName),
            ],
            onEdit: () => _openPersonalSheet(context, ref, profile),
          ),
          const SizedBox(height: 14),
          _ProfileEditSectionCard(
            icon: Icons.contact_phone_outlined,
            title: 'Contact information',
            subtitle: isInternal
                ? 'Your staff account contact number.'
                : 'How OMC can reach you about services and documents.',
            rows: [
              _ProfileValueRow(
                label: 'Mobile',
                value: _displayValue(profile.phone),
              ),
              _ProfileValueRow(
                label: 'WhatsApp',
                value: _displayValue(profile.whatsappNo),
              ),
              _ProfileValueRow(
                label: 'Address',
                value: _displayValue(profile.address),
                maxLines: 2,
              ),
            ],
            onEdit: () => _openContactSheet(context, ref, profile),
          ),
          const SizedBox(height: 14),
          if (isInternal) ...[
            _ProfileEditSectionCard(
              icon: Icons.workspace_premium_outlined,
              title: 'Professional information',
              subtitle: 'Your qualifications and working profile.',
              rows: [
                _ProfileValueRow(
                  label: 'Education',
                  value: _displayValue(profile.education),
                  maxLines: 2,
                ),
                _ProfileValueRow(
                  label: 'Experience',
                  value: _displayValue(profile.experience),
                  maxLines: 3,
                ),
                _ProfileValueRow(
                  label: 'Remarks',
                  value: _displayValue(profile.remarks),
                  maxLines: 3,
                ),
              ],
              onEdit: () => _openProfessionalSheet(context, ref, profile),
            ),
            const SizedBox(height: 14),
            _InternalAccountCard(profile: profile),
          ] else ...[
            _ProfileEditSectionCard(
              icon: Icons.business_center_outlined,
              title: 'Business & tax details',
              subtitle: 'Company details and your protected tax identifier.',
              rows: [
                _ProfileValueRow(
                  label: 'Company',
                  value: _displayValue(profile.companyName),
                ),
                _ProfileValueRow(
                  label: 'NTN',
                  value: _displayValue(profile.ntn),
                ),
              ],
              onEdit: () => _openBusinessSheet(context, ref, profile),
            ),
            const SizedBox(height: 14),
            _LockedIdentityCard(profile: profile),
          ],
          const SizedBox(height: 18),
          Text(
            'Changes are applied immediately and recorded in your account history.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textMuted,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletionCard extends StatelessWidget {
  const _CompletionCard({required this.profile, required this.completion});

  final ProfileSummary profile;
  final int completion;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.account_circle_outlined,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$completion% profile complete',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: completion / 100,
              backgroundColor: const Color(0xFFE8ECF2),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileEditSectionCard extends StatelessWidget {
  const _ProfileEditSectionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.rows,
    required this.onEdit,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> rows;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F5F8),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: AppTheme.textPrimary, size: 21),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton(onPressed: onEdit, child: const Text('Edit')),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
            child: Column(children: rows),
          ),
        ],
      ),
    );
  }
}

class _ProfileValueRow extends StatelessWidget {
  const _ProfileValueRow({
    required this.label,
    required this.value,
    this.maxLines = 1,
  });

  final String label;
  final String value;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InternalAccountCard extends StatelessWidget {
  const _InternalAccountCard({required this.profile});

  final ProfileSummary profile;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.admin_panel_settings_outlined),
            title: const Text(
              'Account identity',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: const Text('Protected staff account details'),
            trailing: const Icon(Icons.lock_outline_rounded, size: 20),
            onTap: () => _showLockedIdentityInfo(context),
          ),
          const Divider(height: 1),
          _LockedValueTile(label: 'Email', value: profile.email),
          const Divider(height: 1),
          _LockedValueTile(
            label: 'Username',
            value: _displayValue(profile.username),
          ),
          const Divider(height: 1),
          _LockedValueTile(
            label: 'Account type',
            value: _displayValue(profile.registerAs),
          ),
          if ((profile.cnic?.trim() ?? '').isNotEmpty) ...[
            const Divider(height: 1),
            _LockedValueTile(label: 'CNIC', value: profile.cnic!),
          ],
        ],
      ),
    );
  }
}

class _LockedIdentityCard extends StatelessWidget {
  const _LockedIdentityCard({required this.profile});

  final ProfileSummary profile;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.verified_user_outlined),
            title: const Text(
              'Verified identity',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: const Text(
              'Protected identifiers cannot be changed from the app.',
            ),
            trailing: const Icon(Icons.lock_outline_rounded, size: 20),
            onTap: () => _showLockedIdentityInfo(context),
          ),
          const Divider(height: 1),
          _LockedValueTile(label: 'Email', value: profile.email),
          const Divider(height: 1),
          _LockedValueTile(
            label: 'CNIC',
            value: profile.cnic ?? 'Not available',
          ),
          if ((profile.ntn?.trim() ?? '').isNotEmpty) ...[
            const Divider(height: 1),
            _LockedValueTile(label: 'NTN', value: profile.ntn!),
          ],
        ],
      ),
    );
  }
}

class _LockedValueTile extends StatelessWidget {
  const _LockedValueTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(
        label,
        style: const TextStyle(
          color: AppTheme.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.w800,
        ),
      ),
      trailing: const Icon(Icons.lock_outline_rounded, size: 18),
      onTap: () => _showLockedIdentityInfo(context),
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
          if (clean.length < 2) return 'Enter your full name.';
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
  final phone = TextEditingController(text: profile.phone ?? '');
  final whatsapp = TextEditingController(text: profile.whatsappNo ?? '');
  final address = TextEditingController(text: profile.address ?? '');

  await _showEditSheet(
    context: context,
    ref: ref,
    title: 'Contact information',
    subtitle: 'Keep your service and document contact details current.',
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
      _SheetTextField(
        controller: address,
        label: 'Address',
        icon: Icons.location_on_outlined,
        textCapitalization: TextCapitalization.sentences,
        minLines: 2,
        maxLines: 4,
      ),
    ],
    payloadBuilder: () => {
      'phone': phone.text.trim(),
      'whatsapp_no': whatsapp.text.trim(),
      'address': address.text.trim(),
    },
  );

  phone.dispose();
  whatsapp.dispose();
  address.dispose();
}

Future<void> _openProfessionalSheet(
  BuildContext context,
  WidgetRef ref,
  ProfileSummary profile,
) async {
  final education = TextEditingController(text: profile.education ?? '');
  final experience = TextEditingController(text: profile.experience ?? '');
  final remarks = TextEditingController(text: profile.remarks ?? '');

  await _showEditSheet(
    context: context,
    ref: ref,
    title: 'Professional information',
    subtitle: 'Keep your qualifications and working profile up to date.',
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
    payloadBuilder: () => {
      'education': education.text.trim(),
      'experience': experience.text.trim(),
      'remarks': remarks.text.trim(),
    },
  );

  education.dispose();
  experience.dispose();
  remarks.dispose();
}

Future<void> _openBusinessSheet(
  BuildContext context,
  WidgetRef ref,
  ProfileSummary profile,
) async {
  final company = TextEditingController(text: profile.companyName ?? '');
  final currentNtn = profile.ntn?.trim() ?? '';
  final ntn = TextEditingController();

  final fields = <Widget>[
    _SheetTextField(
      controller: company,
      label: 'Company name',
      icon: Icons.business_outlined,
      textCapitalization: TextCapitalization.words,
    ),
  ];

  if (currentNtn.isEmpty) {
    fields.add(
      _SheetTextField(
        controller: ntn,
        label: 'NTN — can only be added once',
        icon: Icons.confirmation_number_outlined,
      ),
    );
  } else {
    fields.add(
      _ProtectedFieldNotice(
        label: 'NTN',
        value: currentNtn,
        message:
            'Your NTN is verified and locked. Contact OMC support for a legal correction.',
      ),
    );
  }

  await _showEditSheet(
    context: context,
    ref: ref,
    title: 'Business & tax details',
    subtitle: currentNtn.isEmpty
        ? 'Add your NTN carefully. It will be locked after the first save.'
        : 'Update your company details. Your verified NTN is protected.',
    fields: fields,
    payloadBuilder: () {
      final payload = <String, dynamic>{'company_name': company.text.trim()};
      if (currentNtn.isEmpty && ntn.text.trim().isNotEmpty) {
        payload['ntn'] = ntn.text.trim();
      }
      return payload;
    },
  );

  company.dispose();
  ntn.dispose();
}

Future<void> _showEditSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String title,
  required String subtitle,
  required List<Widget> fields,
  required Map<String, dynamic> Function() payloadBuilder,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => _ProfileEditSheet(
      title: title,
      subtitle: subtitle,
      fields: fields,
      payloadBuilder: payloadBuilder,
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
  });

  final String title;
  final String subtitle;
  final List<Widget> fields;
  final Map<String, dynamic> Function() payloadBuilder;
  final WidgetRef ref;

  @override
  State<_ProfileEditSheet> createState() => _ProfileEditSheetState();
}

class _ProfileEditSheetState extends State<_ProfileEditSheet> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (_saving || !(_formKey.currentState?.validate() ?? false)) return;

    FocusScope.of(context).unfocus();
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

      if (!mounted) return;
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
      if (!mounted) return;

      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Profile not updated',
        fallbackMessage: 'Your profile details could not be updated right now.',
      );
      setState(() => _error = failure.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, bottomInset + 12),
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD7DCE4),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  widget.subtitle,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                ..._withSpacing(widget.fields),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AppButton(
                        label: 'Save',
                        icon: Icons.check_rounded,
                        isLoading: _saving,
                        onPressed: _saving ? null : _save,
                      ),
                    ),
                  ],
                ),
              ],
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
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      minLines: minLines,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        alignLabelWithHint: maxLines > 1,
      ),
    );
  }
}

class _ProtectedFieldNotice extends StatelessWidget {
  const _ProtectedFieldNotice({
    required this.label,
    required this.value,
    required this.message,
  });

  final String label;
  final String value;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE3E8EF)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.lock_outline_rounded, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$label: $value',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
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

class _ProfileEditorLoading extends StatelessWidget {
  const _ProfileEditorLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

class _ProfileEditorUnavailable extends StatelessWidget {
  const _ProfileEditorUnavailable();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Profile details are unavailable.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _ProfileEditorError extends StatelessWidget {
  const _ProfileEditorError({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          AppFailureClassifier.classify(
            error,
            fallbackTitle: 'Profile unavailable',
            fallbackMessage: 'Profile details could not be loaded right now.',
          ).message,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

void _showLockedIdentityInfo(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Verified account identifiers',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Email and CNIC are protected account identifiers. NTN becomes protected after it is added once because it is used for verified tax records. Contact OMC support if a verified legal correction is required.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13.5,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: const Text('Understood'),
              ),
            ),
          ],
        ),
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

int _profileCompletion(ProfileSummary profile) {
  final isInternal =
      profile.capabilities.canAccessInternalWorkspace ||
      profile.capabilities.isInternal;
  final values = isInternal
      ? [
          profile.displayName,
          profile.phone,
          profile.whatsappNo,
          profile.address,
          profile.education,
          profile.experience,
          profile.remarks,
        ]
      : [
          profile.displayName,
          profile.phone,
          profile.whatsappNo,
          profile.address,
          profile.companyName,
        ];

  final completed = values.where((value) {
    final clean = value?.trim() ?? '';
    return clean.isNotEmpty && clean != 'Not available';
  }).length;

  return ((completed / values.length) * 100).round();
}
