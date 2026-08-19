import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/effective_capabilities_provider.dart';
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
      body: RefreshIndicator(
        onRefresh: refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          children: [
            const Text(
              'OMC administration',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            Text(
              _adminScopeDescription(capabilities),
              style: const TextStyle(height: 1.4),
            ),
            if (capabilities.canReassignServiceCases ||
                capabilities.canRetrySync ||
                capabilities.canManageBusinessSettings) ...[
              const SizedBox(height: 20),
              PremiumCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.tune_rounded),
                  title: const Text(
                    'Operational controls',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text(
                    'Reassignment, sync recovery and reviewed pricing operations.',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/admin-control/operations'),
                ),
              ),
            ],
            if (overview != null) ...[
              const SizedBox(height: 16),
              overview.when(
                loading: () => const _LoadingCard(),
                error: (error, _) => _ErrorCard(
                  message: AppFailureClassifier.classify(
                    error,
                    fallbackTitle: 'Administration data unavailable',
                    fallbackMessage:
                        'Could not load the administration sections assigned to your account.',
                  ).message,
                  onRetry: () => ref.invalidate(scopedAdminOverviewProvider),
                ),
                data: (data) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (capabilities.canReviewRegistrations)
                      _ApplicationsCard(data: data),
                    if (capabilities.canReviewRegistrations &&
                        capabilities.canManageStaff)
                      const SizedBox(height: 16),
                    if (capabilities.canManageStaff) _StaffCard(data: data),
                  ],
                ),
              ),
            ],
            if (settings != null) ...[
              const SizedBox(height: 16),
              settings.when(
                loading: () => const _LoadingCard(),
                error: (error, _) => _ErrorCard(
                  message: AppFailureClassifier.classify(
                    error,
                    fallbackTitle: 'Business settings unavailable',
                    fallbackMessage: 'Could not load OMC business settings.',
                  ).message,
                  onRetry: () => ref.invalidate(adminBusinessSettingsProvider),
                ),
                data: (data) => _BusinessSettingsCard(settings: data),
              ),
            ],
          ],
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
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'This does not create a login. Create or convert the person to an enabled System User in Frappe Desk first, then grant OMC access to that same identity.',
                      style: TextStyle(fontSize: 12.5, height: 1.4),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: name,
                    decoration: const InputDecoration(
                      labelText: 'System User full name',
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'System User email',
                    ),
                    onChanged: (_) => setDialogState(() {}),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'OMC access profile',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  for (final role in overview.availableRoles)
                    CheckboxListTile(
                      dense: true,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pending registrations (${data.applications.length})',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Customer registrations and staff access applications awaiting an OMC decision. Staff applications require the matching enabled System User in Frappe Desk first.',
            style: TextStyle(fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 10),
          if (data.applications.isEmpty)
            const Text('No registrations are awaiting review.'),
          for (final application in data.applications)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                application.fullName.isEmpty
                    ? application.email
                    : application.fullName,
              ),
              subtitle: Text(
                application.requestedRole.isEmpty
                    ? 'Customer registration'
                    : 'Staff access application • ${application.requestedRole}',
              ),
              trailing: Wrap(
                children: [
                  IconButton(
                    tooltip: 'Reject',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => _review(context, ref, application, false),
                  ),
                  IconButton(
                    tooltip: application.requestedRole.isEmpty
                        ? 'Approve customer'
                        : 'Approve staff access',
                    icon: const Icon(Icons.check_rounded, color: Colors.green),
                    onPressed: () => _review(context, ref, application, true),
                  ),
                ],
              ),
            ),
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
      final isStaff = application.requestedRole.isNotEmpty;
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
        _showFailure(context, error, fallback: 'Could not review this application.');
      }
    }
  }
}

class _StaffCard extends ConsumerWidget {
  const _StaffCard({required this.data});

  final AdminOverview data;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'OMC staff access (${data.staff.length})',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Enable, suspend or change OMC capability profiles. This does not modify ERPNext roles.',
            style: TextStyle(fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 10),
          if (data.staff.isEmpty) const Text('No OMC staff access records found.'),
          for (final staff in data.staff)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(staff.fullName),
              subtitle: Text(
                staff.roles.isEmpty ? staff.userId : staff.roles.join(' • '),
              ),
              leading: Switch(
                value: staff.enabled,
                onChanged: (value) => _update(context, ref, staff, value),
              ),
              trailing: IconButton(
                tooltip: 'Edit access profile',
                icon: const Icon(Icons.manage_accounts_rounded),
                onPressed: () => _editRoles(context, ref, staff),
              ),
            ),
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
        _showFailure(context, error, fallback: 'Could not update staff access.');
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
                children: [
                  for (final role in data.availableRoles)
                    CheckboxListTile(
                      dense: true,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Business settings',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Mobile availability and reviewed business rules. Changes apply through the backend configuration contract.',
            style: TextStyle(fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 10),
          for (final entry in _toggleLabels.entries)
            if (settings.containsKey(entry.key))
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(entry.value),
                value: settings[entry.key] == true || settings[entry.key] == 1,
                onChanged: (value) => _updateSetting(
                  context,
                  ref,
                  entry.key,
                  value ? 1 : 0,
                ),
              ),
          if (settings.containsKey('discount_auto_approval_percent'))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Auto-approved discount'),
              subtitle: const Text('Maximum percentage allowed without review'),
              trailing: Text('${settings['discount_auto_approval_percent']}%'),
              onTap: () => _editNumber(
                context,
                ref,
                key: 'discount_auto_approval_percent',
                title: 'Auto-approved discount percent',
                currentValue: settings['discount_auto_approval_percent'],
              ),
            ),
          if (settings.containsKey('minimum_service_price'))
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Minimum service price'),
              trailing: Text('PKR ${settings['minimum_service_price']}'),
              onTap: () => _editNumber(
                context,
                ref,
                key: 'minimum_service_price',
                title: 'Minimum service price',
                currentValue: settings['minimum_service_price'],
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
      await ref
          .read(adminControlRepositoryProvider)
          .updateBusinessSettings({key: value});
      ref.invalidate(adminBusinessSettingsProvider);
    } catch (error) {
      if (context.mounted) {
        _showFailure(context, error, fallback: 'Could not update business settings.');
      }
    }
  }

  Future<void> _editNumber(
    BuildContext context,
    WidgetRef ref, {
    required String key,
    required String title,
    required Object? currentValue,
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
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Value'),
              onChanged: (_) => setDialogState(() {}),
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

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const PremiumCard(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(),
        ),
      ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Section unavailable',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(message),
          const SizedBox(height: 8),
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
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(failure.message)),
  );
}
