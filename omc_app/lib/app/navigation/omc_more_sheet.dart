import 'package:flutter/material.dart';

import '../../core/config/api_config.dart';
import '../../core/widgets/omc_premium.dart';
import '../../features/app_config/data/mobile_app_config.dart';
import '../../features/auth/application/auth_state.dart';
import '../theme.dart';
import 'omc_nav_models.dart';

Future<void> showOmcMoreSheet({
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
  required VoidCallback onOpenInternalCases,
  required VoidCallback onOpenCustomers,
  required VoidCallback onOpenLeads,
  required VoidCallback onOpenTasks,
  required VoidCallback onLogout,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Colors.white,
    barrierColor: Colors.black.withValues(alpha: 0.28),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) {
      final actions = _moreActions(
        sheetContext: sheetContext,
        features: features,
        capabilities: capabilities,
        unreadNotifications: unreadNotifications,
        isGuest: isGuest,
        onOpenDashboard: onOpenDashboard,
        onOpenDocuments: onOpenDocuments,
        onOpenPayments: onOpenPayments,
        onOpenNotifications: onOpenNotifications,
        onOpenTaxCalculator: onOpenTaxCalculator,
        onOpenExpenseTracker: onOpenExpenseTracker,
        onOpenBudget: onOpenBudget,
        onOpenKnowledge: onOpenKnowledge,
        onOpenSupport: onOpenSupport,
        onOpenProfile: onOpenProfile,
        onOpenSettings: onOpenSettings,
        onOpenInternalWorkspace: onOpenInternalWorkspace,
        onOpenInternalCases: onOpenInternalCases,
        onOpenCustomers: onOpenCustomers,
        onOpenLeads: onOpenLeads,
        onOpenTasks: onOpenTasks,
        onLogout: onLogout,
      );
      return _MoreSheetContent(
        actions: actions,
        capabilities: capabilities,
        displayName: displayName,
        companyName: companyName,
        customerStatus: customerStatus,
        avatarUrl: avatarUrl,
      );
    },
  );
}

List<OmcSheetAction> _moreActions({
  required BuildContext sheetContext,
  required MobileFeatureConfig features,
  required AuthCapabilities capabilities,
  required int unreadNotifications,
  required bool isGuest,
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
  required VoidCallback onOpenInternalCases,
  required VoidCallback onOpenCustomers,
  required VoidCallback onOpenLeads,
  required VoidCallback onOpenTasks,
  required VoidCallback onLogout,
}) {
  OmcSheetAction action(
    String label,
    IconData icon,
    VoidCallback onTap, {
    int badgeCount = 0,
    bool isDestructive = false,
  }) {
    return OmcSheetAction(
      label: label,
      icon: icon,
      badgeCount: badgeCount,
      isDestructive: isDestructive,
      onTap: () => _closeThen(sheetContext, onTap),
    );
  }

  if (capabilities.canAccessInternalWorkspace || capabilities.isInternal) {
    return [
      action(
        'Workspace',
        Icons.admin_panel_settings_outlined,
        onOpenInternalWorkspace,
      ),
      action('Cases', Icons.fact_check_outlined, onOpenInternalCases),
      action('Customers', Icons.groups_outlined, onOpenCustomers),
      action('Review Docs', Icons.folder_copy_outlined, onOpenDocuments),
      action('Payments', Icons.receipt_long_outlined, onOpenPayments),
      action('Leads', Icons.person_search_outlined, onOpenLeads),
      action('Tasks', Icons.task_alt_outlined, onOpenTasks),
      action(
        'Alerts',
        Icons.notifications_none_rounded,
        onOpenNotifications,
        badgeCount: unreadNotifications,
      ),
      action('Settings', Icons.settings_outlined, onOpenSettings),
      action('Logout', Icons.logout_rounded, onLogout, isDestructive: true),
    ];
  }

  final items = <OmcSheetAction>[];
  if (!capabilities.isGuest) {
    items.add(action('Dashboard', Icons.analytics_outlined, onOpenDashboard));
    items.add(action('Documents', Icons.folder_copy_outlined, onOpenDocuments));
    if (features.paymentsEnabled) {
      items.add(
        action('Payments', Icons.receipt_long_outlined, onOpenPayments),
      );
    }
    items.add(
      action(
        'Alerts',
        Icons.notifications_none_rounded,
        onOpenNotifications,
        badgeCount: unreadNotifications,
      ),
    );
  }
  items.add(action('Tax', Icons.calculate_outlined, onOpenTaxCalculator));
  if (features.expenseTrackerEnabled && !capabilities.isInternal) {
    items.add(
      action(
        'Expense',
        Icons.account_balance_wallet_outlined,
        onOpenExpenseTracker,
      ),
    );
    if (capabilities.isApproved) {
      items.add(action('Budget', Icons.savings_outlined, onOpenBudget));
    }
  }
  if (features.knowledgeEnabled) {
    items.add(action('Knowledge', Icons.menu_book_outlined, onOpenKnowledge));
  }
  if (features.supportEnabled) {
    items.add(action('Support', Icons.support_agent_outlined, onOpenSupport));
  }
  if (!capabilities.isGuest) {
    items.add(action('Profile', Icons.person_outline_rounded, onOpenProfile));
    items.add(action('Settings', Icons.settings_outlined, onOpenSettings));
  }
  items.add(
    action(
      isGuest ? 'Login' : 'Logout',
      isGuest ? Icons.login_rounded : Icons.logout_rounded,
      onLogout,
      isDestructive: !isGuest,
    ),
  );
  return items;
}

void _closeThen(BuildContext context, VoidCallback onTap) {
  Navigator.of(context).pop();
  onTap();
}

class _MoreSheetContent extends StatelessWidget {
  const _MoreSheetContent({
    required this.actions,
    required this.capabilities,
    required this.displayName,
    required this.companyName,
    required this.customerStatus,
    required this.avatarUrl,
  });

  final List<OmcSheetAction> actions;
  final AuthCapabilities capabilities;
  final String? displayName;
  final String? companyName;
  final String? customerStatus;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.72,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _MoreHeader(
              displayName: displayName,
              companyName: companyName,
              customerStatus: customerStatus,
              avatarUrl: avatarUrl,
            ),
            if (capabilities.isGuest ||
                capabilities.isPending ||
                capabilities.isRejected) ...[
              const SizedBox(height: 10),
              _AccessStatusNote(capabilities: capabilities),
            ],
            const SizedBox(height: 14),
            _MoreGroupLabel(
              label:
                  capabilities.canAccessInternalWorkspace ||
                      capabilities.isInternal
                  ? 'Operations'
                  : 'Account & services',
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: actions.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 12,
                crossAxisSpacing: 8,
                childAspectRatio: 0.82,
              ),
              itemBuilder: (context, index) =>
                  _SheetActionButton(action: actions[index]),
            ),
          ],
        ),
      ),
    );
  }
}

class _MoreHeader extends StatelessWidget {
  const _MoreHeader({
    this.displayName,
    this.companyName,
    this.customerStatus,
    this.avatarUrl,
  });

  final String? displayName;
  final String? companyName;
  final String? customerStatus;
  final String? avatarUrl;

  String get _headerSubtitle {
    final company = _cleanLabel(companyName);
    final status = _cleanLabel(customerStatus);
    if (company != null && status != null) return '$company • $status';
    if (company != null) return company;
    if (status != null) return status;
    return 'Profile, services and shortcuts.';
  }

  String? _cleanLabel(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final cleanAvatarUrl = avatarUrl?.trim();
    final resolvedAvatarUrl = cleanAvatarUrl == null || cleanAvatarUrl.isEmpty
        ? null
        : cleanAvatarUrl.startsWith('http')
        ? cleanAvatarUrl
        : '${ApiConfig.baseUrl}${cleanAvatarUrl.startsWith('/') ? '' : '/'}$cleanAvatarUrl';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: OmcPremium.canvas,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.border),
        boxShadow: OmcPremium.softShadow,
      ),
      child: Row(
        children: [
          _MoreHeaderAvatar(
            avatarUrl: resolvedAvatarUrl,
            initials: _initials(displayName),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _cleanLabel(displayName) ?? 'OMC Workspace',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.25,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _headerSubtitle,
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
        ],
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
        'Public tools are available. Protected workspace opens after login.',
      ),
      AccountAccessState.pending => (
        Icons.hourglass_top_rounded,
        'Account under review',
        'Local tools stay available. Sync activates after approval.',
      ),
      AccountAccessState.rejected => (
        Icons.block_rounded,
        'Approval required',
        'Protected services are unavailable. Contact support.',
      ),
      _ => (
        Icons.verified_user_outlined,
        'Approved access',
        'Protected services are enabled.',
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
        children: [
          _IconBadge(icon: icon),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11.5,
                    height: 1.3,
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

class _MoreHeaderAvatar extends StatelessWidget {
  const _MoreHeaderAvatar({required this.avatarUrl, required this.initials});

  final String? avatarUrl;
  final String initials;

  @override
  Widget build(BuildContext context) {
    final cleanAvatarUrl = avatarUrl?.trim();
    final hasAvatar = cleanAvatarUrl != null && cleanAvatarUrl.isNotEmpty;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: OmcPremium.services.withValues(alpha: 0.10),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: hasAvatar
          ? Image.network(
              cleanAvatarUrl,
              width: 48,
              height: 48,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _AvatarFallback(initials: initials),
            )
          : _AvatarFallback(initials: initials),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  const _AvatarFallback({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          color: OmcPremium.services,
          fontSize: 15,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

String _initials(String? name) {
  final parts = (name ?? '')
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList();
  if (parts.isEmpty) return 'OMC';
  if (parts.length == 1) {
    return parts.first.characters.take(2).toString().toUpperCase();
  }
  return '${parts.first.characters.first}${parts.last.characters.first}'
      .toUpperCase();
}

class _SheetActionButton extends StatelessWidget {
  const _SheetActionButton({required this.action});

  final OmcSheetAction action;

  @override
  Widget build(BuildContext context) {
    final color = action.isDestructive
        ? OmcPremium.danger
        : OmcPremium.moduleColor(action.label);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _IconBadge(icon: action.icon, color: color),
                  if (action.badgeCount > 0)
                    Positioned(
                      top: -6,
                      right: -8,
                      child: _CompactBadge(count: action.badgeCount),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                action.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: action.isDestructive
                      ? OmcPremium.danger
                      : AppTheme.textPrimary,
                  fontSize: 10.5,
                  height: 1.08,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, this.color = OmcPremium.services});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: color, size: 20),
    );
  }
}

class _MoreGroupLabel extends StatelessWidget {
  const _MoreGroupLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppTheme.textPrimary,
        fontSize: 13,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _CompactBadge extends StatelessWidget {
  const _CompactBadge({required this.count});

  final int count;
  String get _label => count > 99 ? '99+' : count.toString();

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      height: 18,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppTheme.primaryRed,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Text(
        _label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.w900,
          height: 1,
        ),
      ),
    );
  }
}
