import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers/effective_capabilities_provider.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/premium_card.dart';
import '../data/admin_control_repository.dart';

class AdminControlScreen extends ConsumerWidget {
  const AdminControlScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final capabilities = ref.watch(effectiveCapabilitiesProvider);
    final overview = ref.watch(adminOverviewProvider);
    final settings = capabilities.canManageBusinessSettings
        ? ref.watch(adminBusinessSettingsProvider)
        : null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Control Center'),
        actions: [
          if (capabilities.canManageStaff)
            IconButton(
              tooltip: 'Invite staff',
              icon: const Icon(Icons.person_add_alt_1_rounded),
              onPressed: () => _inviteStaff(context, ref, overview.value),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(adminOverviewProvider);
          ref.invalidate(adminBusinessSettingsProvider);
          await ref.read(adminOverviewProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          children: [
            const Text(
              'Routine administration',
              style: TextStyle(fontSize: 25, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              'Review registrations, manage operational roles and control OMC business settings.',
            ),
            const SizedBox(height: 20),
            if (capabilities.canReassignServiceCases ||
                capabilities.canRetrySync ||
                capabilities.canManageBusinessSettings) ...[
              PremiumCard(
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.tune_rounded),
                  title: const Text('Operational controls'),
                  subtitle: const Text(
                    'Reassign cases, retry exhausted ERP sync and review discounts.',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => context.push('/admin-control/operations'),
                ),
              ),
              const SizedBox(height: 16),
            ],
            overview.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => _ErrorCard(
                message: AppFailureClassifier.classify(
                  error,
                  fallbackTitle: 'Admin data unavailable',
                  fallbackMessage: 'Could not load administration data.',
                ).message,
                onRetry: () => ref.invalidate(adminOverviewProvider),
              ),
              data: (data) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ApplicationsCard(data: data),
                  const SizedBox(height: 16),
                  _StaffCard(data: data),
                ],
              ),
            ),
            if (settings != null) ...[
              const SizedBox(height: 16),
              settings.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (data) => _BusinessSettingsCard(settings: data),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _inviteStaff(
    BuildContext context,
    WidgetRef ref,
    AdminOverview? overview,
  ) async {
    if (overview == null || overview.availableRoles.isEmpty) return;
    final name = TextEditingController();
    final email = TextEditingController();
    final selectedRoles = <String>{overview.availableRoles.first};
    final submit = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Invite staff member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Full name'),
              ),
              TextField(
                controller: email,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('Operational roles'),
              ),
              for (final item in overview.availableRoles)
                CheckboxListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: selectedRoles.contains(item),
                  title: Text(item),
                  onChanged: (value) => setState(() {
                    if (value == true) {
                      selectedRoles.add(item);
                    } else {
                      selectedRoles.remove(item);
                    }
                  }),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selectedRoles.isEmpty
                  ? null
                  : () => Navigator.pop(dialogContext, true),
              child: const Text('Send invite'),
            ),
          ],
        ),
      ),
    );
    if (submit == true && context.mounted) {
      try {
        await ref
            .read(adminControlRepositoryProvider)
            .inviteStaff(
              fullName: name.text.trim(),
              email: email.text.trim(),
              roles: selectedRoles.toList(growable: false),
            );
        ref.invalidate(adminOverviewProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Staff invitation created.')),
          );
        }
      } catch (error) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppFailureClassifier.classify(
                  error,
                  fallbackTitle: 'Invite failed',
                  fallbackMessage: 'Could not invite staff.',
                ).message,
              ),
            ),
          );
        }
      }
    }
    name.dispose();
    email.dispose();
  }
}

class _ApplicationsCard extends ConsumerWidget {
  const _ApplicationsCard({required this.data});
  final AdminOverview data;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PremiumCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pending registrations (${data.applications.length})',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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
                  ? 'Customer application'
                  : application.requestedRole,
            ),
            trailing: Wrap(
              children: [
                IconButton(
                  tooltip: 'Reject',
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => _review(context, ref, application, false),
                ),
                IconButton(
                  tooltip: 'Approve',
                  icon: const Icon(Icons.check_rounded, color: Colors.green),
                  onPressed: () => _review(context, ref, application, true),
                ),
              ],
            ),
          ),
      ],
    ),
  );

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
      ref.invalidate(adminOverviewProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              approve ? 'Registration approved.' : 'Registration rejected.',
            ),
          ),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppFailureClassifier.classify(
                error,
                fallbackTitle: 'Review failed',
                fallbackMessage: 'Could not review registration.',
              ).message,
            ),
          ),
        );
      }
    }
  }
}

class _StaffCard extends ConsumerWidget {
  const _StaffCard({required this.data});
  final AdminOverview data;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PremiumCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Operational staff (${data.staff.length})',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        for (final staff in data.staff)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(staff.fullName),
            subtitle: Text(staff.roles.join(' • ')),
            leading: Switch(
              value: staff.enabled,
              onChanged: (value) => _update(context, ref, staff, value),
            ),
            trailing: IconButton(
              tooltip: 'Edit roles',
              icon: const Icon(Icons.manage_accounts_rounded),
              onPressed: () => _editRoles(context, ref, staff),
            ),
          ),
      ],
    ),
  );

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
      ref.invalidate(adminOverviewProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppFailureClassifier.classify(
                error,
                fallbackTitle: 'Staff not updated',
                fallbackMessage: 'Could not update staff account.',
              ).message,
            ),
          ),
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
    final roles = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Roles for ${staff.fullName}'),
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
                    onChanged: (value) => setState(() {
                      if (value == true) {
                        selected.add(role);
                      } else {
                        selected.remove(role);
                      }
                    }),
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
                  : () => Navigator.pop(dialogContext, selected.toList()),
              child: const Text('Save roles'),
            ),
          ],
        ),
      ),
    );
    if (roles != null && context.mounted) {
      await _update(context, ref, staff, staff.enabled, roles: roles);
    }
  }
}

class _BusinessSettingsCard extends ConsumerWidget {
  const _BusinessSettingsCard({required this.settings});
  final Map<String, dynamic> settings;

  @override
  Widget build(BuildContext context, WidgetRef ref) => PremiumCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Business settings',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        for (final key in const [
          'guest_mode_enabled',
          'payments_enabled',
          'support_enabled',
          'maintenance_mode',
        ])
          if (settings.containsKey(key))
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(key.replaceAll('_', ' ')),
              value: settings[key] == true || settings[key] == 1,
              onChanged: (value) async {
                await ref
                    .read(adminControlRepositoryProvider)
                    .updateBusinessSettings({key: value ? 1 : 0});
                ref.invalidate(adminBusinessSettingsProvider);
              },
            ),
        if (settings.containsKey('discount_auto_approval_percent'))
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto-approved discount'),
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

  Future<void> _editNumber(
    BuildContext context,
    WidgetRef ref, {
    required String key,
    required String title,
    required Object? currentValue,
  }) async {
    final controller = TextEditingController(text: '$currentValue');
    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Value'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              dialogContext,
              double.tryParse(controller.text.trim()),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || !context.mounted) return;
    await ref.read(adminControlRepositoryProvider).updateBusinessSettings({
      key: value,
    });
    ref.invalidate(adminBusinessSettingsProvider);
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => PremiumCard(
    child: Column(
      children: [
        Text(message),
        TextButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    ),
  );
}
