import 'package:flutter/material.dart';

import '../../core/config/api_config.dart';
import '../../core/diagnostics/omc_widget_keys.dart';
import '../../features/app_config/data/mobile_app_config.dart';
import '../../features/auth/application/auth_state.dart';
import '../design_tokens.dart';
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
    barrierColor: Colors.black.withValues(alpha: 0.28),
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
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return ConstrainedBox(
      key: OmcWidgetKeys.moreScreen,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.90,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.md + bottomInset,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              header: true,
              child: Text('More', style: theme.textTheme.titleLarge),
            ),
            const SizedBox(height: AppSpacing.md),
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
              const SizedBox(height: AppSpacing.sm),
              _AccessStatusNote(capabilities: capabilities),
            ],
            const SizedBox(height: AppSpacing.xl),
            for (var index = 0; index < groups.length; index++) ...[
              _NavigationGroup(
                group: groups[index],
                unreadNotifications: unreadNotifications,
                callbackFor: callbackFor,
              ),
              if (index != groups.length - 1)
                const SizedBox(height: AppSpacing.xl),
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
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
          child: Text(
            group.title,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: theme.colorScheme.outlineVariant),
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
                  const Divider(height: 1, indent: 68),
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
    final theme = Theme.of(context);
    final destructive = item.id == OmcNavigationActionId.logout;
    final badge = item.id == OmcNavigationActionId.alerts
        ? unreadNotifications
        : 0;
    final semanticLabel = badge > 0
        ? '${item.label}, $badge unread notifications'
        : item.label;
    final iconInk = destructive
        ? AppTheme.danger
        : theme.colorScheme.onSurfaceVariant;
    final iconBackground = destructive
        ? AppTheme.dangerSoft
        : theme.colorScheme.surfaceContainerHighest;

    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        key: OmcWidgetKeys.moreAction(item.id.name),
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Container(
            constraints: const BoxConstraints(minHeight: 56),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: iconBackground,
                      borderRadius: BorderRadius.circular(AppRadius.control),
                    ),
                    child: Icon(_iconFor(item.id), color: iconInk, size: 24),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    item.label,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: destructive
                          ? AppTheme.danger
                          : AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                if (badge > 0)
                  _Badge(
                    count: badge,
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                  )
                else
                  Icon(
                    destructive
                        ? Icons.logout_rounded
                        : Icons.chevron_right_rounded,
                    color: destructive
                        ? AppTheme.danger
                        : theme.colorScheme.onSurfaceVariant,
                    size: 24,
                  ),
              ],
            ),
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
    final theme = Theme.of(context);
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
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.card),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: AppTouchTarget.minimum,
                height: AppTouchTarget.minimum,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: resolvedAvatarUrl == null
                      ? _MoreAvatarFallback(name: cleanName)
                      : Image.network(
                          resolvedAvatarUrl,
                          width: AppTouchTarget.minimum,
                          height: AppTouchTarget.minimum,
                          fit: BoxFit.cover,
                          webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                          errorBuilder: (_, _, _) =>
                              _MoreAvatarFallback(name: cleanName),
                        ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(cleanName, style: theme.textTheme.titleMedium),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle.isEmpty ? 'Profile and app shortcuts' : subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: AppSpacing.xs),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurfaceVariant,
                  size: 24,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreAvatarFallback extends StatelessWidget {
  const _MoreAvatarFallback({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox.square(
      dimension: AppTouchTarget.minimum,
      child: Center(
        child: Text(
          _initials(name),
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onPrimaryContainer,
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
    final theme = Theme.of(context);
    final (icon, title, message, tone, background) =
        switch (capabilities.accessState) {
          AccountAccessState.guest => (
            Icons.info_outline_rounded,
            'Guest mode',
            'Public tools are available. Sign in for protected OMC services.',
            AppTheme.info,
            AppTheme.infoSoft,
          ),
          AccountAccessState.pending => (
            Icons.hourglass_top_rounded,
            'Account under review',
            'Public tools remain available while OMC reviews your access.',
            AppTheme.warning,
            AppTheme.warningSoft,
          ),
          AccountAccessState.rejected => (
            Icons.error_outline_rounded,
            'Approval required',
            'Protected services are unavailable. Contact OMC support if needed.',
            AppTheme.danger,
            AppTheme.dangerSoft,
          ),
          _ => (
            Icons.verified_outlined,
            'Approved access',
            'Protected OMC services are enabled.',
            AppTheme.success,
            AppTheme.successSoft,
          ),
        };

    return Semantics(
      container: true,
      label: '$title. $message',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: tone.withValues(alpha: 0.20)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: tone, size: 24),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(color: tone),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.count,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  final int count;
  final Color backgroundColor;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: foregroundColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1.2,
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
