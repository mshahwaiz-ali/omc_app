import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
import '../../../app/providers/effective_capabilities_provider.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/app_labeled_field.dart';
import '../../../core/forms/dirty_form_controller.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/premium_card.dart';
import '../data/admin_control_repository.dart';
import '../data/admin_overview_repository.dart';

class AdminControlScreen extends ConsumerWidget {
  const AdminControlScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capabilities = ref.watch(effectiveCapabilitiesProvider);
    final needsOverview =
        capabilities.canManageStaff || capabilities.canReviewRegistrations;
    final overview = needsOverview
        ? ref.watch(scopedAdminOverviewProvider)
        : null;
    final settings = capabilities.canManageBusinessSettings
        ? ref.watch(adminBusinessSettingsProvider)
        : null;

    Future<void> refresh() async {
      if (needsOverview) ref.invalidate(scopedAdminOverviewProvider);
      if (settings != null) ref.invalidate(adminBusinessSettingsProvider);
      if (needsOverview) {
        await ref.read(scopedAdminOverviewProvider.future);
      } else if (settings != null) {
        await ref.read(adminBusinessSettingsProvider.future);
      }
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Administration'),
        actions: [
          if (capabilities.canManageStaff)
            IconButton(
              tooltip: 'Grant OMC staff access',
              icon: const Icon(Icons.person_add_alt_1_rounded),
              onPressed: () => _grantStaffAccess(context, ref),
            ),
        ],
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: refresh,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final inset = AppLayout.pageInsetFor(constraints.maxWidth);
            final horizontal =
                constraints.maxWidth > AppLayout.generalMaxWidth + inset * 2
                ? (constraints.maxWidth - AppLayout.generalMaxWidth) / 2
                : inset;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                horizontal,
                16,
                horizontal,
                AppSpacing.xl,
              ),
              children: [
                Text(
                  'OMC administration',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  _adminScopeDescription(capabilities),
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                if (overview != null) ...[
                  const SizedBox(height: AppSpacing.xl),
                  overview.when(
                    loading: () => const _LoadingCard(),
                    error: (error, _) => _ErrorCard(
                      message: AppFailureClassifier.classify(
                        error,
                        fallbackTitle: 'Administration data unavailable',
                        fallbackMessage:
                            'Could not load the administration sections assigned to your account.',
                      ).message,
                      onRetry: () =>
                          ref.invalidate(scopedAdminOverviewProvider),
                    ),
                    data: (data) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (capabilities.canReviewRegistrations)
                          _ApplicationsCard(data: data),
                        if (capabilities.canReviewRegistrations &&
                            capabilities.canManageStaff)
                          const SizedBox(height: AppSpacing.lg),
                        if (capabilities.canManageStaff) _StaffCard(data: data),
                      ],
                    ),
                  ),
                ],
                if (settings != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  settings.when(
                    loading: () => const _LoadingCard(),
                    error: (error, _) => _ErrorCard(
                      message: AppFailureClassifier.classify(
                        error,
                        fallbackTitle: 'Business settings unavailable',
                        fallbackMessage:
                            'Could not load OMC business settings.',
                      ).message,
                      onRetry: () =>
                          ref.invalidate(adminBusinessSettingsProvider),
                    ),
                    data: (data) => _BusinessSettingsCard(settings: data),
                  ),
                ],
                if (capabilities.canReassignServiceCases ||
                    capabilities.canRetrySync ||
                    capabilities.canManageBusinessSettings) ...[
                  const SizedBox(height: AppSpacing.lg),
                  PremiumCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    onTap: () => context.push('/admin-control/operations'),
                    semanticLabel:
                        'Operational controls. Reassignment, processing recovery and reviewed pricing operations.',
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.tune_rounded, size: 22),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Operational controls',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: AppSpacing.xxs),
                              Text(
                                'Reassignment, processing recovery and reviewed pricing operations.',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        const Icon(Icons.chevron_right_rounded),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _grantStaffAccess(BuildContext context, WidgetRef ref) async {
    AdminOverview overview;
    try {
      overview = await ref.read(scopedAdminOverviewProvider.future);
    } catch (error) {
      if (!context.mounted) return;
      _showFailure(
        context,
        error,
        fallback: 'Staff access options could not be loaded.',
      );
      return;
    }
    if (!context.mounted || overview.availableRoles.isEmpty) return;

    final name = TextEditingController();
    final email = TextEditingController();
    final dirty = DirtyFormController();
    final selectedRoles = <String>{overview.availableRoles.first};
    void markDirty() => dirty.markDirty();
    name.addListener(markDirty);
    email.addListener(markDirty);

    final submit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => UnsavedChangesGuard(
          controller: dirty,
          child: AlertDialog(
            title: const Text('Grant OMC staff access'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _DialogNotice(
                    icon: Icons.verified_user_outlined,
                    message:
                        'This does not create a login. The person must already have an enabled staff login in the core OMC system; this grants OMC app access to that same identity.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  AppLabeledField(
                    label: 'Existing staff full name',
                    isRequired: true,
                    child: TextField(
                      controller: name,
                      decoration: const InputDecoration(),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppLabeledField(
                    label: 'Existing staff login email',
                    isRequired: true,
                    child: TextField(
                      controller: email,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'OMC access profile',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  for (final role in overview.availableRoles)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: selectedRoles.contains(role),
                      title: Text(role),
                      onChanged: (value) {
                        dirty.markDirty();
                        setDialogState(() {
                          value == true
                              ? selectedRoles.add(role)
                              : selectedRoles.remove(role);
                        });
                      },
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed:
                    name.text.trim().isEmpty ||
                        email.text.trim().isEmpty ||
                        selectedRoles.isEmpty
                    ? null
                    : () {
                        dirty.submissionSucceeded();
                        Navigator.pop(dialogContext, true);
                      },
                child: const Text('Grant access'),
              ),
            ],
          ),
        ),
      ),
    );

    name.removeListener(markDirty);
    email.removeListener(markDirty);
    dirty.dispose();

    if (submit == true && context.mounted) {
      try {
        await ref
            .read(adminControlRepositoryProvider)
            .inviteStaff(
              fullName: name.text.trim(),
              email: email.text.trim(),
              roles: selectedRoles.toList(growable: false),
            );
        ref.invalidate(scopedAdminOverviewProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('OMC staff access granted.')),
          );
        }
      } catch (error) {
        if (context.mounted) {
          _showFailure(
            context,
            error,
            fallback: 'Could not grant OMC staff access.',
          );
        }
      }
    }

    name.dispose();
    email.dispose();
  }
}

String _adminScopeDescription(dynamic capabilities) {
  final scopes = <String>[
    if (capabilities.canReviewRegistrations) 'registration review',
    if (capabilities.canManageStaff) 'staff access',
    if (capabilities.canManageBusinessSettings) 'business settings',
  ];
  if (scopes.isEmpty) return 'No administration sections are assigned.';
  return 'Your administrative scope: ${scopes.join(', ')}.';
}

class _ApplicationsCard extends ConsumerWidget {
  const _ApplicationsCard({required this.data});

  final AdminOverview data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pending decisions (${data.applications.length})',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Customer registrations and staff access applications awaiting an authorized OMC decision. Staff applications require a matching enabled staff login first.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (data.applications.isEmpty)
            Text(
              'No registrations are awaiting review.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          for (var index = 0; index < data.applications.length; index++) ...[
            _ApplicationRow(
              application: data.applications[index],
              onReview: (approve) =>
                  _review(context, ref, data.applications[index], approve),
            ),
            if (index != data.applications.length - 1)
              const Divider(height: AppSpacing.lg),
          ],
        ],
      ),
    );
  }

  Future<void> _review(
    BuildContext context,
    WidgetRef ref,
    AdminApplication application,
    bool approve,
  ) async {
    final identity = application.fullName.trim().isEmpty
        ? application.email
        : application.fullName;
    final isStaff = application.requestedRole.isNotEmpty;
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(
              approve
                  ? isStaff
                        ? 'Approve staff access?'
                        : 'Approve customer registration?'
                  : isStaff
                  ? 'Reject staff access?'
                  : 'Reject customer registration?',
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    identity,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (application.email.trim().isNotEmpty &&
                      application.email != identity) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(application.email),
                  ],
                  if (isStaff) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text('Requested OMC profile: ${application.requestedRole}'),
                    const SizedBox(height: AppSpacing.sm),
                    const _DialogNotice(
                      icon: Icons.verified_user_outlined,
                      message:
                          'Approving staff access does not create a core login; the matching enabled staff login remains required.',
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(approve ? 'Approve' : 'Reject'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !context.mounted) return;

    try {
      await ref
          .read(adminControlRepositoryProvider)
          .reviewRegistration(
            profileId: application.profileId,
            approve: approve,
            roles: application.requestedRole.isEmpty
                ? const []
                : [application.requestedRole],
          );
      ref.invalidate(scopedAdminOverviewProvider);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve
                ? isStaff
                      ? 'OMC staff access approved.'
                      : 'Customer registration approved.'
                : isStaff
                ? 'Staff access application rejected.'
                : 'Customer registration rejected.',
          ),
        ),
      );
    } catch (error) {
      if (context.mounted) {
        _showFailure(
          context,
          error,
          fallback: 'Could not review this application.',
        );
      }
    }
  }
}

class _ApplicationRow extends StatelessWidget {
  const _ApplicationRow({required this.application, required this.onReview});

  final AdminApplication application;
  final ValueChanged<bool> onReview;

  @override
  Widget build(BuildContext context) {
    final name = application.fullName.isEmpty
        ? application.email
        : application.fullName;
    final type = application.requestedRole.isEmpty
        ? 'Customer registration'
        : 'Staff access application · ${application.requestedRole}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            type,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              OutlinedButton.icon(
                onPressed: () => onReview(false),
                icon: const Icon(Icons.close_rounded),
                label: const Text('Reject'),
              ),
              FilledButton.icon(
                onPressed: () => onReview(true),
                icon: const Icon(Icons.check_rounded),
                label: Text(
                  application.requestedRole.isEmpty
                      ? 'Approve customer'
                      : 'Approve staff access',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StaffCard extends ConsumerWidget {
  const _StaffCard({required this.data});

  final AdminOverview data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'OMC staff access (${data.staff.length})',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Enable, suspend or change OMC capability profiles. This does not change the person’s core system login or core roles.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (data.staff.isEmpty)
            Text(
              'No OMC staff access records found.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          for (var index = 0; index < data.staff.length; index++) ...[
            _StaffRow(
              staff: data.staff[index],
              onEnabledChanged: (value) =>
                  _update(context, ref, data.staff[index], value),
              onEditRoles: () => _editRoles(context, ref, data.staff[index]),
            ),
            if (index != data.staff.length - 1)
              const Divider(height: AppSpacing.lg),
          ],
        ],
      ),
    );
  }

  Future<void> _update(
    BuildContext context,
    WidgetRef ref,
    AdminStaff staff,
    bool enabled, {
    List<String>? roles,
  }) async {
    try {
      await ref
          .read(adminControlRepositoryProvider)
          .updateStaff(
            staff: staff,
            enabled: enabled,
            roles: roles ?? staff.roles,
          );
      ref.invalidate(scopedAdminOverviewProvider);
    } catch (error) {
      if (context.mounted) {
        _showFailure(
          context,
          error,
          fallback: 'Could not update staff access.',
        );
      }
    }
  }

  Future<void> _editRoles(
    BuildContext context,
    WidgetRef ref,
    AdminStaff staff,
  ) async {
    final selected = staff.roles.toSet();
    final dirty = DirtyFormController();
    final roles = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => UnsavedChangesGuard(
          controller: dirty,
          child: AlertDialog(
            title: Text('Access profile for ${staff.fullName}'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    staff.userId,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  const _DialogNotice(
                    icon: Icons.security_rounded,
                    message:
                        'Only the OMC access profile changes here. Available choices come from the backend.',
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  for (final role in data.availableRoles)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: selected.contains(role),
                      title: Text(role),
                      onChanged: (value) {
                        dirty.markDirty();
                        setDialogState(() {
                          value == true
                              ? selected.add(role)
                              : selected.remove(role);
                        });
                      },
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: selected.isEmpty
                    ? null
                    : () {
                        dirty.submissionSucceeded();
                        Navigator.pop(
                          dialogContext,
                          selected.toList(growable: false),
                        );
                      },
                child: const Text('Save access'),
              ),
            ],
          ),
        ),
      ),
    );
    dirty.dispose();
    if (roles != null && context.mounted) {
      await _update(context, ref, staff, staff.enabled, roles: roles);
    }
  }
}

class _StaffRow extends StatelessWidget {
  const _StaffRow({
    required this.staff,
    required this.onEnabledChanged,
    required this.onEditRoles,
  });

  final AdminStaff staff;
  final ValueChanged<bool> onEnabledChanged;
  final VoidCallback onEditRoles;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = constraints.maxWidth < 360 || textScale >= 1.5;
        final identity = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              staff.fullName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              staff.roles.isEmpty ? staff.userId : staff.roles.join(' · '),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
            ),
          ],
        );
        final actions = Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(value: staff.enabled, onChanged: onEnabledChanged),
                const SizedBox(width: AppSpacing.xxs),
                Text(staff.enabled ? 'Enabled' : 'Suspended'),
              ],
            ),
            OutlinedButton.icon(
              onPressed: onEditRoles,
              icon: const Icon(Icons.manage_accounts_rounded),
              label: const Text('Edit access'),
            ),
          ],
        );
        if (stack) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                identity,
                const SizedBox(height: AppSpacing.sm),
                actions,
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: identity),
              const SizedBox(width: AppSpacing.sm),
              Flexible(child: actions),
            ],
          ),
        );
      },
    );
  }
}

class _BusinessSettingsCard extends ConsumerWidget {
  const _BusinessSettingsCard({required this.settings});

  final Map<String, dynamic> settings;

  static const _toggleLabels = <String, String>{
    'guest_mode_enabled': 'Guest mode',
    'payments_enabled': 'Payments',
    'support_enabled': 'Support',
    'knowledge_enabled': 'Knowledge',
    'tax_calculator_enabled': 'Tax calculator',
    'expense_tracker_enabled': 'Expense tracker',
    'internal_workspace_enabled': 'Internal workspace',
    'maintenance_mode': 'Maintenance mode',
    'force_update': 'Force app update',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Business configuration',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Mobile availability and reviewed business rules. Changes apply to the live OMC app configuration.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final entry in _toggleLabels.entries)
            if (settings.containsKey(entry.key))
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(entry.value),
                value: settings[entry.key] == true || settings[entry.key] == 1,
                onChanged: (value) =>
                    _updateSetting(context, ref, entry.key, value ? 1 : 0),
              ),
          if (settings.containsKey('discount_auto_approval_percent'))
            _SettingRow(
              title: 'Auto-approved discount',
              subtitle: 'Maximum percentage allowed without review',
              value: '${settings['discount_auto_approval_percent']}%',
              onTap: () => _editNumber(
                context,
                ref,
                key: 'discount_auto_approval_percent',
                title: 'Auto-approved discount percent',
                currentValue: settings['discount_auto_approval_percent'],
                unit: '%',
              ),
            ),
          if (settings.containsKey('minimum_service_price'))
            _SettingRow(
              title: 'Minimum service price',
              value: 'PKR ${settings['minimum_service_price']}',
              onTap: () => _editNumber(
                context,
                ref,
                key: 'minimum_service_price',
                title: 'Minimum service price',
                currentValue: settings['minimum_service_price'],
                unit: 'PKR',
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _updateSetting(
    BuildContext context,
    WidgetRef ref,
    String key,
    Object value,
  ) async {
    try {
      await ref.read(adminControlRepositoryProvider).updateBusinessSettings({
        key: value,
      });
      ref.invalidate(adminBusinessSettingsProvider);
    } catch (error) {
      if (context.mounted) {
        _showFailure(
          context,
          error,
          fallback: 'Could not update business settings.',
        );
      }
    }
  }

  Future<void> _editNumber(
    BuildContext context,
    WidgetRef ref, {
    required String key,
    required String title,
    required Object? currentValue,
    required String unit,
  }) async {
    final controller = TextEditingController(text: '$currentValue');
    final dirty = DirtyFormController();
    void markDirty() => dirty.markDirty();
    controller.addListener(markDirty);

    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => UnsavedChangesGuard(
          controller: dirty,
          child: AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    unit == '%'
                        ? 'Current value: $currentValue%'
                        : 'Current value: $unit $currentValue',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppLabeledField(
                    label: 'Value',
                    isRequired: true,
                    child: TextField(
                      controller: controller,
                      autofocus: true,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        prefixText: unit == '%' ? null : '$unit ',
                        suffixText: unit == '%' ? '%' : null,
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: double.tryParse(controller.text.trim()) == null
                    ? null
                    : () {
                        dirty.submissionSucceeded();
                        Navigator.pop(
                          dialogContext,
                          double.parse(controller.text.trim()),
                        );
                      },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );

    controller.removeListener(markDirty);
    dirty.dispose();
    controller.dispose();
    if (value == null || !context.mounted) return;
    await _updateSetting(context, ref, key, value);
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.title,
    required this.value,
    required this.onTap,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.bodyLarge),
                  if (subtitle != null) ...[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogNotice extends StatelessWidget {
  const _DialogNotice({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppTheme.cardSoft,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppTheme.textSecondary),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const PremiumCard(
      padding: EdgeInsets.all(AppSpacing.lg),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Section unavailable',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: AppSpacing.sm),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

void _showFailure(
  BuildContext context,
  Object error, {
  required String fallback,
}) {
  final failure = AppFailureClassifier.classify(
    error,
    fallbackMessage: fallback,
  );
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(failure.message)));
}
