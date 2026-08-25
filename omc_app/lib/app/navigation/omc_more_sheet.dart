import 'package:flutter/material.dart';

import '../../core/config/api_config.dart';
import '../../core/widgets/omc_premium.dart';
import '../../features/app_config/data/mobile_app_config.dart';
import '../../features/auth/application/auth_state.dart';
import '../theme.dart';
import 'omc_navigation_ia.dart';

Future<bool> showOmcMoreSheet({
  required BuildContext context,
  required MobileFeatureConfig features,
  required AuthCapabilities capabilities,
  required int unreadNotifications,
  required bool isGuest,
  required String? displayName,
  required String? companyName,
  required String? customerStatus,
  required String? avatarUrl,
  required VoidCallback onOpenDashboard,
  required VoidCallback onOpenDocuments,
  required VoidCallback onOpenPayments,
  required VoidCallback onOpenNotifications,
  required VoidCallback onOpenTaxCalculator,
  required VoidCallback onOpenExpenseTracker,
  required VoidCallback onOpenBudget,
  required VoidCallback onOpenKnowledge,
  required VoidCallback onOpenSupport,
  required VoidCallback onOpenProfile,
  required VoidCallback onOpenSettings,
  required VoidCallback onOpenInternalWorkspace,
  required VoidCallback onOpenCustomers,
  required VoidCallback onOpenMyReferrals,
  required VoidCallback onOpenMyCommissions,
  required VoidCallback onOpenCommissionOperations,
  required VoidCallback onOpenLeads,
  required VoidCallback onOpenTasks,
  required VoidCallback onLogout,
}) async {
  final groups = buildOmcMoreNavigation(
    capabilities: capabilities,
    features: OmcNavigationFeatureFlags(
      paymentsEnabled: features.paymentsEnabled,
      expenseTrackerEnabled: features.expenseTrackerEnabled,
      knowledgeEnabled: features.knowledgeEnabled,
      supportEnabled: features.supportEnabled,
    ),
    isGuest: isGuest,
  );

  VoidCallback callbackFor(OmcNavigationActionId id) {
    return switch (id) {
      OmcNavigationActionId.workspace => onOpenInternalWorkspace,
      OmcNavigationActionId.customers => onOpenCustomers,
      OmcNavigationActionId.referrals => onOpenMyReferrals,
      OmcNavigationActionId.commissions => onOpenMyCommissions,
      OmcNavigationActionId.commissionOperations => onOpenCommissionOperations,
      OmcNavigationActionId.documents => onOpenDocuments,
      OmcNavigationActionId.payments => onOpenPayments,
      OmcNavigationActionId.leads => onOpenLeads,
      OmcNavigationActionId.tasks => onOpenTasks,
      OmcNavigationActionId.support => onOpenSupport,
      OmcNavigationActionId.alerts => onOpenNotifications,
      OmcNavigationActionId.tax => onOpenTaxCalculator,
      OmcNavigationActionId.expense => onOpenExpenseTracker,
      OmcNavigationActionId.budget => onOpenBudget,
      OmcNavigationActionId.knowledge => onOpenKnowledge,
      OmcNavigationActionId.profile => onOpenProfile,
      OmcNavigationActionId.settings => onOpenSettings,
      OmcNavigationActionId.login || OmcNavigationActionId.logout => onLogout,
      OmcNavigationActionId.apply ||
      OmcNavigationActionId.createLead ||
      OmcNavigationActionId.startRequest ||
      OmcNavigationActionId.reviewPayments ||
      OmcNavigationActionId.reviewDocuments ||
      OmcNavigationActionId.supportQueue => onOpenInternalWorkspace,
    };
  }

  final selectedAction = await showModalBottomSheet<VoidCallback>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => _MoreSheetContent(
      groups: groups,
      capabilities: capabilities,
      unreadNotifications: unreadNotifications,
      displayName: displayName,
      companyName: companyName,
      customerStatus: customerStatus,
      avatarUrl: avatarUrl,
      onOpenProfile: isGuest
          ? null
          : () => Navigator.of(sheetContext).pop(onOpenProfile),
      callbackFor: callbackFor,
    ),
  );

  if (selectedAction == null) return false;
  if (!context.mounted) return true;
  selectedAction();
  return true;
}

class _MoreSheetContent extends StatelessWidget {
  const _MoreSheetContent({
    required this.groups,
    required this.capabilities,
    required this.unreadNotifications,
    required this.displayName,
    required this.companyName,
    required this.customerStatus,
    required this.avatarUrl,
    required this.onOpenProfile,
    required this.callbackFor,
  });

  final List<OmcNavigationGroup> groups;
  final AuthCapabilities capabilities;
  final int unreadNotifications;
  final String? displayName;
  final String? companyName;
  final String? customerStatus;
  final String? avatarUrl;
  final VoidCallback? onOpenProfile;
  final VoidCallback Function(OmcNavigationActionId id) callbackFor;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.82,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(18, 2, 18, bottomInset + 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _MoreHeader(
              displayName: displayName,
              companyName: companyName,
              customerStatus: customerStatus,
              avatarUrl: avatarUrl,
              onTap: onOpenProfile,
            ),
            if (capabilities.isGuest ||
                capabilities.isPending ||
                capabilities.isRejected) ...[
              const SizedBox(height: 12),
              _AccessStatusNote(capabilities: capabilities),
            ],
            const SizedBox(height: 18),
            for (var index = 0; index < groups.length; index++) ...[
              _NavigationGroup(
                group: groups[index],
                unreadNotifications: unreadNotifications,
                callbackFor: callbackFor,
              ),
              if (index != groups.length - 1) const SizedBox(height: 18),
            ],
          ],
        ),
      ),
    );
  }
}

class _NavigationGroup extends StatelessWidget {
  const _NavigationGroup({
    required this.group,
    required this.unreadNotifications,
    required this.callbackFor,
  });

  final OmcNavigationGroup group;
  final int unreadNotifications;
  final VoidCallback Function(OmcNavigationActionId id) callbackFor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            group.title,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.2,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.border),
          ),
          child: Column(
            children: [
              for (var index = 0; index < group.items.length; index++) ...[
                _NavigationRow(
                  item: group.items[index],
                  unreadNotifications: unreadNotifications,
                  onTap: () => Navigator.of(
                    context,
                  ).pop(callbackFor(group.items[index].id)),
                ),
                if (index != group.items.length - 1)
                  const Divider(height: 1, indent: 58),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _NavigationRow extends StatelessWidget {
  const _NavigationRow({
    required this.item,
    required this.unreadNotifications,
    required this.onTap,
  });

  final OmcNavigationItem item;
  final int unreadNotifications;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final destructive = item.id == OmcNavigationActionId.logout;
    final color = destructive
        ? OmcPremium.danger
        : OmcPremium.moduleColor(item.label);
    final badge = item.id == OmcNavigationActionId.alerts
        ? unreadNotifications
        : 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(_iconFor(item.id), color: color, size: 19),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: destructive
                        ? OmcPremium.danger
                        : AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (badge > 0)
                _Badge(count: badge)
              else
                Icon(
                  destructive
                      ? Icons.logout_rounded
                      : Icons.chevron_right_rounded,
                  color: destructive ? OmcPremium.danger : AppTheme.textMuted,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _iconFor(OmcNavigationActionId id) {
  return switch (id) {
    OmcNavigationActionId.workspace => Icons.dashboard_customize_outlined,
    OmcNavigationActionId.customers => Icons.groups_outlined,
    OmcNavigationActionId.referrals => Icons.hub_outlined,
    OmcNavigationActionId.commissions => Icons.payments_outlined,
    OmcNavigationActionId.commissionOperations =>
      Icons.account_balance_outlined,
    OmcNavigationActionId.documents => Icons.folder_copy_outlined,
    OmcNavigationActionId.payments => Icons.receipt_long_outlined,
    OmcNavigationActionId.leads => Icons.person_search_outlined,
    OmcNavigationActionId.tasks => Icons.task_alt_outlined,
    OmcNavigationActionId.support ||
    OmcNavigationActionId.supportQueue => Icons.support_agent_outlined,
    OmcNavigationActionId.alerts => Icons.notifications_none_rounded,
    OmcNavigationActionId.tax => Icons.calculate_outlined,
    OmcNavigationActionId.expense => Icons.account_balance_wallet_outlined,
    OmcNavigationActionId.budget => Icons.savings_outlined,
    OmcNavigationActionId.knowledge => Icons.menu_book_outlined,
    OmcNavigationActionId.profile => Icons.person_outline_rounded,
    OmcNavigationActionId.settings => Icons.settings_outlined,
    OmcNavigationActionId.login => Icons.login_rounded,
    OmcNavigationActionId.logout => Icons.logout_rounded,
    OmcNavigationActionId.apply ||
    OmcNavigationActionId.startRequest => Icons.add_business_outlined,
    OmcNavigationActionId.createLead => Icons.person_add_alt_1_rounded,
    OmcNavigationActionId.reviewPayments => Icons.receipt_long_outlined,
    OmcNavigationActionId.reviewDocuments => Icons.fact_check_outlined,
  };
}

class _MoreHeader extends StatelessWidget {
  const _MoreHeader({
    this.displayName,
    this.companyName,
    this.customerStatus,
    this.avatarUrl,
    this.onTap,
  });

  final String? displayName;
  final String? companyName;
  final String? customerStatus;
  final String? avatarUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cleanName = _clean(displayName) ?? 'OMC';
    final company = _clean(companyName);
    final status = _clean(customerStatus);
    final subtitle = [company, status].whereType<String>().join(' • ');
    final cleanAvatarUrl = _clean(avatarUrl);
    final resolvedAvatarUrl = cleanAvatarUrl == null
        ? null
        : cleanAvatarUrl.startsWith('http')
        ? cleanAvatarUrl
        : '${ApiConfig.baseUrl}${cleanAvatarUrl.startsWith('/') ? '' : '/'}$cleanAvatarUrl';

    return Material(
      color: OmcPremium.canvas,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.border),
            boxShadow: OmcPremium.softShadow,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: AppTheme.primarySoft,
                backgroundImage: resolvedAvatarUrl == null
                    ? null
                    : NetworkImage(resolvedAvatarUrl),
                child: resolvedAvatarUrl == null
                    ? Text(
                        _initials(cleanName),
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w900,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cleanName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle.isEmpty ? 'Profile and app shortcuts' : subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AccessStatusNote extends StatelessWidget {
  const _AccessStatusNote({required this.capabilities});

  final AuthCapabilities capabilities;

  @override
  Widget build(BuildContext context) {
    final (icon, title, message) = switch (capabilities.accessState) {
      AccountAccessState.guest => (
        Icons.explore_outlined,
        'Guest mode',
        'Public tools are available. Sign in for protected OMC services.',
      ),
      AccountAccessState.pending => (
        Icons.hourglass_top_rounded,
        'Account under review',
        'Public tools remain available while OMC reviews your access.',
      ),
      AccountAccessState.rejected => (
        Icons.block_rounded,
        'Approval required',
        'Protected services are unavailable. Contact OMC support if needed.',
      ),
      _ => (
        Icons.verified_user_outlined,
        'Approved access',
        'Protected OMC services are enabled.',
      ),
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11.5,
                    height: 1.35,
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

class _Badge extends StatelessWidget {
  const _Badge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 24),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primarySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppTheme.primary,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

String? _clean(String? value) {
  final text = value?.trim();
  return text == null || text.isEmpty ? null : text;
}

String _initials(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((item) => item.isNotEmpty)
      .take(2)
      .toList(growable: false);
  if (parts.isEmpty) return 'OM';
  return parts.map((item) => item.substring(0, 1).toUpperCase()).join();
}
