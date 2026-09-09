import 'package:flutter/material.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/omc_premium.dart';
import '../../../core/widgets/premium_card.dart';
import '../../auth/application/auth_state.dart';
import '../../service_catalogue/data/service_item.dart';
import '../data/home_content.dart';
import '../data/home_dashboard_repository.dart';
import '../data/mobile_quick_actions_repository.dart';
import 'widgets/home_content_rail.dart';
import 'widgets/home_featured_carousel.dart';

class CustomerGuestHomeView extends StatelessWidget {
  const CustomerGuestHomeView({
    required this.displayName,
    required this.avatarUrl,
    required this.summary,
    required this.homeContent,
    required this.capabilities,
    required this.actions,
    required this.searchableServices,
    required this.isGuest,
    required this.isPending,
    required this.isRejected,
    required this.loadMessage,
    required this.onRetryHomeLoad,
    required this.onRefresh,
    required this.onNotifications,
    required this.onAvatar,
    required this.onSearch,
    required this.onOpenSearchResult,
    required this.onAction,
    required this.isActionAllowed,
    required this.onLockedAction,
    required this.onOpenService,
    required this.onOpenServices,
    required this.onPrimaryServiceAction,
    required this.onBannerTap,
    required this.onContentTap,
    required this.onActivityTap,
    required this.onSignUp,
    required this.onSignIn,
    super.key,
  });

  final String displayName;
  final String? avatarUrl;
  final HomeDashboardSummary summary;
  final HomeContent homeContent;
  final AuthCapabilities capabilities;
  final List<MobileQuickAction> actions;
  final List<ServiceItem> searchableServices;
  final bool isGuest;
  final bool isPending;
  final bool isRejected;
  final String? loadMessage;
  final VoidCallback onRetryHomeLoad;
  final Future<void> Function() onRefresh;
  final VoidCallback onNotifications;
  final VoidCallback onAvatar;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onOpenSearchResult;
  final ValueChanged<MobileQuickAction> onAction;
  final bool Function(MobileQuickAction) isActionAllowed;
  final ValueChanged<MobileQuickAction> onLockedAction;
  final ValueChanged<String> onOpenService;
  final VoidCallback onOpenServices;
  final ValueChanged<HomeDashboardServiceSnapshot> onPrimaryServiceAction;
  final ValueChanged<HomeBanner> onBannerTap;
  final ValueChanged<HomeContentCard> onContentTap;
  final VoidCallback onActivityTap;
  final VoidCallback onSignUp;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    final publicActions = [...actions]
      ..sort((a, b) {
        final allowed = (isActionAllowed(b) ? 1 : 0).compareTo(
          isActionAllowed(a) ? 1 : 0,
        );
        if (allowed != 0) return allowed;
        final priority = _publicActionPriority(
          a,
        ).compareTo(_publicActionPriority(b));
        if (priority != 0) return priority;
        return a.sortOrder.compareTo(b.sortOrder);
      });
    final publicServices = searchableServices.take(4).toList(growable: false);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator.adaptive(
          onRefresh: onRefresh,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 150),
            children: [
              _GuestIdentityHeader(
                displayName: displayName,
                avatarUrl: avatarUrl,
                unreadNotifications: summary.unreadNotifications,
                isGuest: isGuest,
                onNotifications: onNotifications,
                onAvatar: onAvatar,
              ),
              const SizedBox(height: 16),
              _AccessStateNote(
                isGuest: isGuest,
                isPending: isPending,
                isRejected: isRejected,
              ),
              if (loadMessage != null) ...[
                const SizedBox(height: 12),
                _LoadNotice(message: loadMessage!, onRetry: onRetryHomeLoad),
              ],
              const SizedBox(height: 20),
              const _HomeSectionHeader(
                title: 'Find a service',
                subtitle:
                    'Search the public OMC catalogue without unlocking restricted account actions.',
              ),
              const SizedBox(height: 10),
              _PublicServiceSearch(
                services: searchableServices,
                onSubmit: onSearch,
                onOpenResult: onOpenSearchResult,
              ),
              if (publicServices.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final service in publicServices)
                      ActionChip(
                        avatar: const Icon(
                          Icons.work_outline_rounded,
                          size: 18,
                        ),
                        label: Text(service.title),
                        onPressed: () => onOpenService(service.id),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 22),
              const _HomeSectionHeader(
                title: 'Public tools',
                subtitle:
                    'Use available calculators, knowledge and catalogue actions now.',
              ),
              const SizedBox(height: 10),
              _PublicActionsGrid(
                actions: publicActions,
                isAllowed: isActionAllowed,
                onAction: onAction,
                onLocked: onLockedAction,
              ),
              if (homeContent.featuredBanners.isNotEmpty) ...[
                const SizedBox(height: 24),
                const _HomeSectionHeader(
                  title: 'Featured',
                  subtitle: 'Published OMC information and timely updates.',
                ),
                const SizedBox(height: 10),
                HomeFeaturedCarousel(
                  banners: homeContent.featuredBanners,
                  onBannerTap: onBannerTap,
                ),
              ],
              if (homeContent.taxBusinessUpdates.isNotEmpty) ...[
                const SizedBox(height: 24),
                const _HomeSectionHeader(
                  title: 'Tax & business updates',
                  subtitle: 'Recent published guidance from OMC.',
                ),
                const SizedBox(height: 10),
                HomeContentRail(
                  items: homeContent.taxBusinessUpdates,
                  onTap: onContentTap,
                ),
              ],
              if (homeContent.learnGrow.isNotEmpty) ...[
                const SizedBox(height: 24),
                const _HomeSectionHeader(
                  title: 'Knowledge & news',
                  subtitle: 'Learn before you decide what to do next.',
                ),
                const SizedBox(height: 10),
                HomeContentRail(
                  items: homeContent.learnGrow,
                  onTap: onContentTap,
                ),
              ],
              const SizedBox(height: 24),
              _AccountCta(
                isGuest: isGuest,
                isPending: isPending,
                isRejected: isRejected,
                onAvatar: onAvatar,
                onSignUp: onSignUp,
                onSignIn: onSignIn,
                onOpenServices: onOpenServices,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuestIdentityHeader extends StatelessWidget {
  const _GuestIdentityHeader({
    required this.displayName,
    required this.avatarUrl,
    required this.unreadNotifications,
    required this.isGuest,
    required this.onNotifications,
    required this.onAvatar,
  });

  final String displayName;
  final String? avatarUrl;
  final int unreadNotifications;
  final bool isGuest;
  final VoidCallback onNotifications;
  final VoidCallback onAvatar;

  @override
  Widget build(BuildContext context) {
    final name = isGuest
        ? 'Welcome to OMC'
        : displayName.trim().isEmpty
        ? 'Your OMC account'
        : displayName.trim();

    return LayoutBuilder(
      builder: (context, constraints) {
        final stack =
            constraints.maxWidth < 360 ||
            MediaQuery.textScalerOf(context).scale(1) >= 1.4;
        final identity = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isGuest ? 'Explore OMC' : 'Account access',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Semantics(
              header: true,
              child: Text(
                name,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 26,
                  height: 1.12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
        final actions = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              button: true,
              label: unreadNotifications > 0
                  ? 'Notifications, $unreadNotifications unread'
                  : 'Notifications',
              child: IconButton.outlined(
                onPressed: onNotifications,
                icon: Badge(
                  isLabelVisible: unreadNotifications > 0,
                  label: Text(
                    unreadNotifications > 99 ? '99+' : '$unreadNotifications',
                  ),
                  child: const Icon(Icons.notifications_none_rounded),
                ),
              ),
            ),
            const SizedBox(width: 8),
            _GuestAvatar(name: name, avatarUrl: avatarUrl, onTap: onAvatar),
          ],
        );

        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [identity, const SizedBox(height: 12), actions],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: identity),
            const SizedBox(width: 12),
            actions,
          ],
        );
      },
    );
  }
}

class _GuestAvatar extends StatelessWidget {
  const _GuestAvatar({
    required this.name,
    required this.avatarUrl,
    required this.onTap,
  });

  final String name;
  final String? avatarUrl;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cleanUrl = avatarUrl?.trim();
    final initial = name.trim().isEmpty ? 'O' : name.trim()[0].toUpperCase();
    return Semantics(
      button: true,
      label: 'Account',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: CircleAvatar(
          radius: 24,
          backgroundColor: AppTheme.primarySoft,
          child: cleanUrl == null || cleanUrl.isEmpty
              ? Text(
                  initial,
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                )
              : ClipOval(
                  child: Image.network(
                    cleanUrl,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Center(
                      child: Text(
                        initial,
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w700,
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

class _AccessStateNote extends StatelessWidget {
  const _AccessStateNote({
    required this.isGuest,
    required this.isPending,
    required this.isRejected,
  });

  final bool isGuest;
  final bool isPending;
  final bool isRejected;

  @override
  Widget build(BuildContext context) {
    late final String title;
    late final String message;
    late final IconData icon;
    late final Color tone;

    if (isPending) {
      title = 'Account under review';
      message =
          'OMC is reviewing your profile. Public service search, tax tools and published knowledge remain available while you wait.';
      icon = Icons.hourglass_top_rounded;
      tone = AppTheme.warning;
    } else if (isRejected) {
      title = 'Customer service access unavailable';
      message =
          'This account is not approved for restricted customer services. Public tools and published information remain available.';
      icon = Icons.info_outline_rounded;
      tone = AppTheme.danger;
    } else {
      title = 'Public access';
      message =
          'Explore services and public tools now. Create an account or sign in when you want tracked OMC customer services.';
      icon = Icons.public_rounded;
      tone = AppTheme.info;
    }

    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OmcIconBadge(icon: icon, color: tone, size: 42, iconSize: 21),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 17,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 15,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
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

class _LoadNotice extends StatelessWidget {
  const _LoadNotice({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.cloud_off_outlined, color: AppTheme.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

class _HomeSectionHeader extends StatelessWidget {
  const _HomeSectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 21,
              height: 1.2,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 15,
            height: 1.4,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _PublicServiceSearch extends StatelessWidget {
  const _PublicServiceSearch({
    required this.services,
    required this.onSubmit,
    required this.onOpenResult,
  });

  final List<ServiceItem> services;
  final ValueChanged<String> onSubmit;
  final ValueChanged<String> onOpenResult;

  @override
  Widget build(BuildContext context) {
    return Autocomplete<ServiceItem>(
      displayStringForOption: (service) => service.title,
      optionsBuilder: (value) {
        final query = value.text.trim().toLowerCase();
        if (query.isEmpty) return const Iterable<ServiceItem>.empty();
        return services
            .where((service) {
              final searchable = '${service.title} ${service.category}'
                  .toLowerCase();
              return searchable.contains(query);
            })
            .take(6);
      },
      onSelected: (service) => onOpenResult(service.id),
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          textInputAction: TextInputAction.search,
          onSubmitted: (value) {
            onSubmit(value.trim());
            onFieldSubmitted();
          },
          style: const TextStyle(fontSize: 16),
          decoration: const InputDecoration(
            hintText: 'Search services, tax, registration…',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final values = options.toList(growable: false);
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 3,
            borderRadius: BorderRadius.circular(12),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520, maxHeight: 320),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                itemCount: values.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final service = values[index];
                  return ListTile(
                    minTileHeight: 56,
                    title: Text(
                      service.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: service.category.trim().isEmpty
                        ? null
                        : Text(service.category),
                    onTap: () => onSelected(service),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PublicActionsGrid extends StatelessWidget {
  const _PublicActionsGrid({
    required this.actions,
    required this.isAllowed,
    required this.onAction,
    required this.onLocked,
  });

  final List<MobileQuickAction> actions;
  final bool Function(MobileQuickAction) isAllowed;
  final ValueChanged<MobileQuickAction> onAction;
  final ValueChanged<MobileQuickAction> onLocked;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return const PremiumCard(
        padding: EdgeInsets.all(16),
        child: Text(
          'Public tools are not available right now.',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 15,
            height: 1.4,
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final textScale = MediaQuery.textScalerOf(context).scale(1);
        final singleColumn = constraints.maxWidth < 330 || textScale >= 1.5;
        final tileWidth = singleColumn
            ? constraints.maxWidth
            : (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final action in actions)
              Builder(
                builder: (context) {
                  final allowed = isAllowed(action);
                  return SizedBox(
                    width: tileWidth,
                    child: PremiumCard(
                      padding: EdgeInsets.zero,
                      child: InkWell(
                        onTap: () =>
                            allowed ? onAction(action) : onLocked(action),
                        borderRadius: BorderRadius.circular(16),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 72),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                OmcIconBadge(
                                  icon: _quickActionIcon(action.iconKey),
                                  color: allowed
                                      ? _quickActionColor(action.iconKey)
                                      : AppTheme.textSecondary,
                                  size: 42,
                                  iconSize: 21,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        action.title,
                                        softWrap: true,
                                        style: const TextStyle(
                                          color: AppTheme.textPrimary,
                                          fontSize: 15,
                                          height: 1.25,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (action.subtitle
                                          .trim()
                                          .isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          action.subtitle,
                                          softWrap: true,
                                          style: const TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 13,
                                            height: 1.35,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  allowed
                                      ? Icons.chevron_right_rounded
                                      : Icons.lock_outline_rounded,
                                  color: AppTheme.textSecondary,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}

class _AccountCta extends StatelessWidget {
  const _AccountCta({
    required this.isGuest,
    required this.isPending,
    required this.isRejected,
    required this.onAvatar,
    required this.onSignUp,
    required this.onSignIn,
    required this.onOpenServices,
  });

  final bool isGuest;
  final bool isPending;
  final bool isRejected;
  final VoidCallback onAvatar;
  final VoidCallback onSignUp;
  final VoidCallback onSignIn;
  final VoidCallback onOpenServices;

  @override
  Widget build(BuildContext context) {
    if (isGuest) {
      return PremiumCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Ready for tracked OMC services?',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Create an account to submit requests and track documents, payments and support conversations.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 15,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onSignUp,
              child: const Text('Create account'),
            ),
            const SizedBox(height: 8),
            TextButton(onPressed: onSignIn, child: const Text('Sign in')),
          ],
        ),
      );
    }

    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            isPending ? 'Review in progress' : 'Account access',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            isPending
                ? 'You can keep using public tools while OMC completes the account review.'
                : 'Review your account information or continue browsing public services.',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 15,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: onAvatar,
            icon: const Icon(Icons.person_outline_rounded),
            label: const Text('View account'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: onOpenServices,
            child: const Text('Browse services'),
          ),
        ],
      ),
    );
  }
}

int _publicActionPriority(MobileQuickAction action) {
  final value = '${action.title} ${action.targetValue}'.toLowerCase();
  if (value.contains('calculator') || value.contains('tax')) return 0;
  if (value.contains('knowledge') || value.contains('news')) return 1;
  if (value.contains('service')) return 2;
  return 3;
}

IconData _quickActionIcon(String key) {
  final value = key.toLowerCase();
  if (value.contains('calculator')) return Icons.calculate_outlined;
  if (value.contains('knowledge')) return Icons.menu_book_outlined;
  if (value.contains('tax')) return Icons.receipt_long_outlined;
  if (value.contains('document')) return Icons.folder_copy_outlined;
  if (value.contains('payment')) return Icons.account_balance_wallet_outlined;
  if (value.contains('support')) return Icons.support_agent_rounded;
  if (value.contains('track')) return Icons.timeline_rounded;
  return Icons.grid_view_rounded;
}

Color _quickActionColor(String key) {
  final value = key.toLowerCase();
  if (value.contains('calculator') || value.contains('tax')) {
    return OmcPremium.tax;
  }
  if (value.contains('knowledge')) return AppTheme.textSecondary;
  if (value.contains('document')) return OmcPremium.documents;
  if (value.contains('payment')) return OmcPremium.payments;
  if (value.contains('support')) return OmcPremium.system;
  return OmcPremium.services;
}
