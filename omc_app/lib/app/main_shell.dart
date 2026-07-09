import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/config/api_config.dart';
import '../core/widgets/premium_card.dart';
import '../features/app_config/data/mobile_app_config.dart';
import '../features/app_config/data/mobile_app_config_repository.dart';
import '../features/auth/application/auth_controller.dart';
import '../features/auth/application/auth_state.dart';
import '../features/documents/presentation/documents_screen.dart';
import '../features/documents/presentation/internal_document_review_screen.dart';
import '../features/home/data/home_dashboard_repository.dart';
import '../features/home/presentation/home_screen.dart';
import '../features/profile/data/profile_repository.dart';
import '../features/service_catalogue/presentation/service_catalogue_screen.dart';
import '../features/service_requests/presentation/my_services_screen.dart';
import 'theme.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({this.initialIndex = 0, super.key});

  final int initialIndex;

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  static const List<_ShellNavItem> _navItems = [
    _ShellNavItem(label: 'Home', icon: Icons.home_outlined, activeIcon: Icons.home_rounded),
    _ShellNavItem(label: 'Services', icon: Icons.grid_view_outlined, activeIcon: Icons.grid_view_rounded),
    _ShellNavItem(label: 'Track', icon: Icons.timeline_outlined, activeIcon: Icons.timeline_rounded),
    _ShellNavItem(label: 'Docs', icon: Icons.folder_copy_outlined, activeIcon: Icons.folder_copy_rounded),
    _ShellNavItem(label: 'More', icon: Icons.more_horiz_outlined, activeIcon: Icons.more_horiz_rounded),
  ];

  void _selectTab(int index) {
    final capabilities = _currentCapabilities();
    if (index == 2 && !_canOpenTrack(capabilities)) {
      _showLockedSnack(capabilities);
      return;
    }
    if (index == 3 && !_canOpenDocuments(capabilities)) {
      _showLockedSnack(capabilities);
      return;
    }
    setState(() => _currentIndex = index);
  }

  AuthCapabilities _currentCapabilities() {
    final profile = ref.read(profileSummaryProvider).maybeWhen(
          data: (profile) => profile,
          orElse: () => null,
        );
    return profile?.capabilities ?? ref.read(authControllerProvider).capabilities;
  }

  bool _canOpenTrack(AuthCapabilities capabilities) {
    return capabilities.canTrackRequests ||
        capabilities.canViewCustomerDashboard ||
        capabilities.canAccessCustomerDashboard ||
        capabilities.isApproved ||
        capabilities.canAccessInternalWorkspace;
  }

  bool _canOpenDocuments(AuthCapabilities capabilities) {
    return capabilities.canViewDocuments ||
        capabilities.canReviewDocuments ||
        capabilities.isApproved ||
        capabilities.isInternal ||
        capabilities.canAccessInternalWorkspace;
  }

  void _openWhenAllowed({
    required bool allowed,
    required String path,
    required AuthCapabilities capabilities,
  }) {
    if (!allowed) {
      _showLockedSnack(capabilities);
      return;
    }
    context.push(path);
  }

  void _showLockedSnack(AuthCapabilities capabilities) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(_lockedAccessMessage(capabilities)), behavior: SnackBarBehavior.floating),
      );
  }

  String _lockedAccessMessage(AuthCapabilities capabilities) {
    if (capabilities.isGuest) return 'Please sign in or create an account to use this service.';
    if (capabilities.isPending) return 'Your account is under review. OMC team will verify your profile before enabling service access.';
    if (capabilities.isRejected) return 'This account is not approved for this action. Please contact OMC support.';
    return 'This account does not have access to that area.';
  }

  Future<void> _logout() async {
    await ref.read(authControllerProvider.notifier).logout();
    ref.invalidate(profileSummaryProvider);
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final profileSummary = ref.watch(profileSummaryProvider);
    final mobileConfig = ref.watch(mobileAppConfigProvider).value ?? MobileAppConfig.fallback;
    final profile = profileSummary.maybeWhen(data: (profile) => profile, orElse: () => null);
    final capabilities = profile?.capabilities ?? authState.capabilities;
    final unreadNotifications = ref.watch(homeDashboardSummaryProvider).value?.unreadNotifications ?? 0;
    final canUseInternalDocs = capabilities.canReviewDocuments || capabilities.canAccessInternalWorkspace || capabilities.isInternal;

    final screens = [
      HomeScreen(
        onOpenServices: () => _selectTab(1),
        onOpenCalculator: () => context.push('/tax-calculator'),
        onOpenSupport: () => context.push('/support'),
        onOpenNotifications: () => context.push('/notifications'),
      ),
      const ServiceCatalogueScreen(),
      const MyServicesScreen(),
      canUseInternalDocs ? const InternalDocumentReviewScreen() : const DocumentsScreen(),
      _MoreScreen(
        onOpenDashboard: () => _openWhenAllowed(
          allowed: capabilities.canViewCustomerDashboard || capabilities.canAccessInternalWorkspace,
          path: '/dashboard',
          capabilities: capabilities,
        ),
        onOpenPayments: () => _openWhenAllowed(
          allowed: capabilities.canViewPayments || capabilities.canReviewPayments || capabilities.isApproved || capabilities.isInternal,
          path: '/payments',
          capabilities: capabilities,
        ),
        onOpenTaxCalculator: () => context.push('/tax-calculator'),
        onOpenSupport: () => context.push('/support'),
        onOpenProfile: () => _openWhenAllowed(allowed: !capabilities.isGuest, path: '/profile', capabilities: capabilities),
        onOpenSettings: () => _openWhenAllowed(allowed: !capabilities.isGuest, path: '/settings', capabilities: capabilities),
        onOpenNotifications: () => _openWhenAllowed(
          allowed: capabilities.canViewCustomerNotifications || capabilities.isApproved || capabilities.isInternal || capabilities.canAccessInternalWorkspace,
          path: '/notifications',
          capabilities: capabilities,
        ),
        onOpenKnowledge: () => context.push('/knowledge'),
        onOpenExpenseTracker: () => context.push('/expense-tracker'),
        features: mobileConfig.features,
        displayName: profile?.displayName ?? authState.displayName,
        companyName: profile?.companyName ?? authState.companyName,
        customerStatus: profile?.status ?? authState.customerStatus,
        avatarUrl: profile?.avatarUrl,
        capabilities: capabilities,
        unreadNotifications: unreadNotifications,
        isGuest: authState.status == AuthStatus.guest,
        canAccessInternalWorkspace: capabilities.canAccessInternalWorkspace && mobileConfig.features.internalWorkspaceEnabled,
        onOpenInternalWorkspace: () => context.push('/internal-workspace'),
        onLogout: authState.status == AuthStatus.guest ? () => context.go('/login') : _logout,
      ),
    ];

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _currentIndex, children: screens),
      bottomNavigationBar: _FloatingShellNav(
        selectedIndex: _currentIndex,
        items: _navItems,
        notificationBadgeCount: unreadNotifications,
        onSelected: _selectTab,
      ),
    );
  }
}

class _FloatingShellNav extends StatelessWidget {
  const _FloatingShellNav({required this.selectedIndex, required this.items, required this.notificationBadgeCount, required this.onSelected});

  final int selectedIndex;
  final List<_ShellNavItem> items;
  final int notificationBadgeCount;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 0, 18, bottomPadding > 0 ? 8 : 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.16), blurRadius: 36, offset: const Offset(0, 18)),
              BoxShadow(color: AppTheme.primaryRed.withValues(alpha: 0.10), blurRadius: 26, offset: const Offset(0, 8)),
            ],
          ),
          child: Container(
            height: 76,
            padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.98),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white.withValues(alpha: 0.92), width: 1.2),
            ),
            child: Row(
              children: [
                for (int index = 0; index < items.length; index++)
                  Expanded(
                    child: _FloatingShellNavItem(
                      item: items[index],
                      isSelected: selectedIndex == index,
                      badgeCount: index == 4 ? notificationBadgeCount : 0,
                      onTap: () => onSelected(index),
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

class _FloatingShellNavItem extends StatelessWidget {
  const _FloatingShellNavItem({required this.item, required this.isSelected, required this.badgeCount, required this.onTap});

  final _ShellNavItem item;
  final bool isSelected;
  final int badgeCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final iconColor = isSelected ? AppTheme.primaryRed : AppTheme.textSecondary;
    final textColor = isSelected ? AppTheme.primaryRed : AppTheme.textSecondary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 60,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFF0E8E8) : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(isSelected ? item.activeIcon : item.icon, color: iconColor, size: isSelected ? 22 : 20),
                  if (badgeCount > 0)
                    Positioned(top: -8, right: -12, child: _CompactBadge(count: badgeCount)),
                ],
              ),
              const SizedBox(height: 5),
              Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: textColor, fontSize: 10.5, fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoreScreen extends StatelessWidget {
  const _MoreScreen({
    required this.onOpenDashboard,
    required this.onOpenPayments,
    required this.onOpenTaxCalculator,
    required this.onOpenSupport,
    required this.onOpenProfile,
    required this.onOpenSettings,
    required this.onOpenNotifications,
    required this.onOpenKnowledge,
    required this.onOpenExpenseTracker,
    required this.features,
    this.displayName,
    this.companyName,
    this.customerStatus,
    this.avatarUrl,
    required this.capabilities,
    required this.unreadNotifications,
    required this.isGuest,
    required this.canAccessInternalWorkspace,
    required this.onOpenInternalWorkspace,
    required this.onLogout,
  });

  final VoidCallback onOpenDashboard;
  final VoidCallback onOpenPayments;
  final VoidCallback onOpenTaxCalculator;
  final VoidCallback onOpenSupport;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenNotifications;
  final VoidCallback onOpenKnowledge;
  final VoidCallback onOpenExpenseTracker;
  final MobileFeatureConfig features;
  final String? displayName;
  final String? companyName;
  final String? customerStatus;
  final String? avatarUrl;
  final AuthCapabilities capabilities;
  final int unreadNotifications;
  final bool isGuest;
  final bool canAccessInternalWorkspace;
  final VoidCallback onOpenInternalWorkspace;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 112),
        children: [
          _MoreHeader(displayName: displayName, companyName: companyName, customerStatus: customerStatus, avatarUrl: avatarUrl),
          if (capabilities.isGuest || capabilities.isPending || capabilities.isRejected) ...[
            const SizedBox(height: 12),
            _AccessStatusNote(capabilities: capabilities),
          ],
          const SizedBox(height: 18),
          _MoreGroup(
            title: 'Account',
            children: [
              _MoreTile(icon: Icons.person_outline_rounded, title: 'Profile', subtitle: 'Personal info and account details', onTap: onOpenProfile),
              _MoreTile(icon: Icons.notifications_none_rounded, title: 'Notifications', subtitle: 'Service updates and tax alerts', badgeCount: unreadNotifications, onTap: onOpenNotifications),
              _MoreTile(icon: Icons.settings_outlined, title: 'Settings', subtitle: 'Theme, notifications and preferences', onTap: onOpenSettings),
            ],
          ),
          const SizedBox(height: 16),
          _MoreGroup(
            title: 'Services',
            children: [
              _MoreTile(icon: Icons.analytics_outlined, title: 'Dashboard', subtitle: 'Your service summary, documents and recent activity', onTap: onOpenDashboard),
              if (features.paymentsEnabled)
                _MoreTile(icon: Icons.receipt_long_outlined, title: 'Payments', subtitle: 'Invoices, dues and receipt uploads', onTap: onOpenPayments),
              _MoreTile(icon: Icons.calculate_outlined, title: 'Tax Calculator', subtitle: 'Estimate salary tax quickly', onTap: onOpenTaxCalculator),
              if (features.knowledgeEnabled)
                _MoreTile(icon: Icons.menu_book_outlined, title: 'Knowledge & News', subtitle: 'Tax guides, FBR updates and OMC news', onTap: onOpenKnowledge),
              if (features.expenseTrackerEnabled && !capabilities.isInternal)
                _MoreTile(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Tax-Ready Expense Tracker',
                  subtitle: _expenseSubtitle(capabilities),
                  onTap: onOpenExpenseTracker,
                ),
            ],
          ),
          if (features.supportEnabled) ...[
            const SizedBox(height: 16),
            _MoreGroup(title: 'Help', children: [_MoreTile(icon: Icons.support_agent_outlined, title: 'Support', subtitle: 'Tickets, WhatsApp and contact channels', onTap: onOpenSupport)]),
          ],
          if (canAccessInternalWorkspace) ...[
            const SizedBox(height: 16),
            _MoreGroup(title: 'Workspace', children: [_MoreTile(icon: Icons.admin_panel_settings_outlined, title: 'Internal Workspace', subtitle: 'Leads, customers, tasks and payments', onTap: onOpenInternalWorkspace)]),
          ],
          const SizedBox(height: 18),
          PremiumCard(
            padding: EdgeInsets.zero,
            child: _MoreTile(
              icon: isGuest ? Icons.login_rounded : Icons.logout_rounded,
              title: isGuest ? 'Login' : 'Logout',
              subtitle: isGuest ? 'Sign in to access your protected OMC workspace' : 'Clear secure session and return to login',
              isDestructive: !isGuest,
              showChevron: false,
              onTap: onLogout,
            ),
          ),
        ],
      ),
    );
  }

  String _expenseSubtitle(AuthCapabilities capabilities) {
    if (capabilities.isGuest) return 'Track locally on this device';
    if (capabilities.isPending) return 'Local tracker — sync after approval';
    if (capabilities.isApproved) return 'Track, sync and generate reports';
    return 'Track expenses, receipts and tax-ready summaries';
  }
}

class _MoreHeader extends StatelessWidget {
  const _MoreHeader({this.displayName, this.companyName, this.customerStatus, this.avatarUrl});

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
    return 'Profile, preferences and business shortcuts.';
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
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          _MoreHeaderAvatar(avatarUrl: resolvedAvatarUrl, initials: _initials(displayName)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_cleanLabel(displayName) ?? 'OMC Workspace', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.35)),
                const SizedBox(height: 5),
                Text(_headerSubtitle, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5, height: 1.35, fontWeight: FontWeight.w600)),
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
      AccountAccessState.guest => (Icons.explore_outlined, 'Guest mode', 'Public services, local tracker, support contacts and tax tools are available.'),
      AccountAccessState.pending => (Icons.hourglass_top_rounded, 'Account under review', 'Expense tracker remains local. Sync activates after approval.'),
      AccountAccessState.rejected => (Icons.block_rounded, 'Approval required', 'Protected services are unavailable for this account. Contact OMC support.'),
      _ => (Icons.verified_user_outlined, 'Approved access', 'Protected services are enabled for this account.'),
    };
    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          _TileIcon(icon: icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13.5, fontWeight: FontWeight.w900)),
                const SizedBox(height: 3),
                Text(message, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.35, fontWeight: FontWeight.w600)),
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
    final hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        gradient: hasAvatar ? null : const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppTheme.primaryRed, AppTheme.darkRed]),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: AppTheme.primaryRed.withValues(alpha: 0.18), blurRadius: 18, offset: const Offset(0, 9))],
      ),
      clipBehavior: Clip.antiAlias,
      child: hasAvatar
          ? Image.network(
              avatarUrl!,
              width: 58,
              height: 58,
              fit: BoxFit.cover,
              webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
              errorBuilder: (_, _, _) => _MoreAvatarFallback(initials: initials),
            )
          : _MoreAvatarFallback(initials: initials),
    );
  }
}

class _MoreAvatarFallback extends StatelessWidget {
  const _MoreAvatarFallback({required this.initials});
  final String initials;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: -0.2)));
  }
}

String _initials(String? name) {
  final parts = (name ?? '').trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).toList();
  if (parts.isEmpty) return 'OMC';
  if (parts.length == 1) return parts.first.characters.take(2).toString().toUpperCase();
  return '${parts.first.characters.first}${parts.last.characters.first}'.toUpperCase();
}

class _MoreGroup extends StatelessWidget {
  const _MoreGroup({required this.title, required this.children});
  final String title;
  final List<_MoreTile> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 0.4)),
        ),
        PremiumCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (int index = 0; index < children.length; index++) ...[
                children[index],
                if (index != children.length - 1) const _DividerIndent(),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile({required this.icon, required this.title, required this.subtitle, required this.onTap, this.isDestructive = false, this.showChevron = true, this.badgeCount = 0});
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;
  final bool showChevron;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.red.shade700 : AppTheme.primaryRed;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          _TileIcon(icon: icon, color: color),
          if (badgeCount > 0) Positioned(top: -5, right: -7, child: _CompactBadge(count: badgeCount)),
        ],
      ),
      title: Text(title, style: TextStyle(color: isDestructive ? Colors.red.shade700 : AppTheme.textPrimary, fontWeight: FontWeight.w900, fontSize: 14.5)),
      subtitle: Text(subtitle, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, height: 1.35, fontWeight: FontWeight.w500)),
      trailing: showChevron ? Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400) : null,
    );
  }
}

class _TileIcon extends StatelessWidget {
  const _TileIcon({required this.icon, this.color = AppTheme.primaryRed});
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(15)),
      child: Icon(icon, color: color, size: 22),
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
      decoration: BoxDecoration(color: AppTheme.primaryRed, borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white, width: 2)),
      child: Text(_label, style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, height: 1)),
    );
  }
}

class _DividerIndent extends StatelessWidget {
  const _DividerIndent();
  @override
  Widget build(BuildContext context) => const Divider(height: 1, indent: 74, endIndent: 16);
}

class _ShellNavItem {
  const _ShellNavItem({required this.label, required this.icon, required this.activeIcon});
  final String label;
  final IconData icon;
  final IconData activeIcon;
}
