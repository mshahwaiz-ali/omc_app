import 'package:flutter/material.dart';

import '../../auth/application/auth_state.dart';
import '../../service_catalogue/data/service_item.dart';
import '../data/home_content.dart';
import '../data/home_dashboard_repository.dart';
import '../data/mobile_quick_actions_repository.dart';
import 'widgets/home_content_rail.dart';
import 'widgets/home_featured_carousel.dart';

const Color _red = Color(0xFFDA1735);
const Color _navy = Color(0xFF111827);
const Color _blue = Color(0xFF356EEA);
const Color _green = Color(0xFF20A34A);
const Color _orange = Color(0xFFF97316);
const Color _purple = Color(0xFF7C5AC7);

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
    final services = summary.serviceSnapshots.take(2).toList(growable: false);
    final activities = summary.recentActivity.take(3).toList(growable: false);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: Stack(
        children: [
          const Positioned.fill(child: _Background()),
          SafeArea(
            bottom: false,
            child: RefreshIndicator.adaptive(
              onRefresh: onRefresh,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                slivers: [
                  if (loadMessage != null)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      sliver: SliverToBoxAdapter(
                        child: _HomeLoadNotice(
                          message: loadMessage!,
                          onRetry: onRetryHomeLoad,
                        ),
                      ),
                    ),
                  const SliverToBoxAdapter(child: SizedBox(height: 17)),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverToBoxAdapter(
                      child: _HomeHeader(
                        displayName: displayName,
                        avatarUrl: avatarUrl,
                        unreadNotifications: summary.unreadNotifications,
                        isGuest: isGuest,
                        onNotifications: onNotifications,
                        onAvatar: onAvatar,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 21)),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverToBoxAdapter(
                      child: _SearchField(
                        services: searchableServices,
                        onSubmit: onSearch,
                        onOpenResult: onOpenSearchResult,
                      ),
                    ),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 17)),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverToBoxAdapter(
                      child: homeContent.featuredBanners.isNotEmpty
                          ? HomeFeaturedCarousel(
                              banners: homeContent.featuredBanners,
                              onBannerTap: onBannerTap,
                            )
                          : _HeroArea(
                              summary: summary,
                              isGuest: isGuest,
                              isPending: isPending,
                              isRejected: isRejected,
                              onPrimaryServiceAction: onPrimaryServiceAction,
                              onOpenServices: onOpenServices,
                              onSignUp: onSignUp,
                            ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    sliver: SliverToBoxAdapter(
                      child: const _SectionHeading(title: 'Quick Actions'),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverToBoxAdapter(
                      child: _QuickActionStrip(
                        actions: actions,
                        isActionAllowed: isActionAllowed,
                        onAction: onAction,
                        onLockedAction: onLockedAction,
                      ),
                    ),
                  ),
                  if (homeContent.taxBusinessUpdates.isNotEmpty) ...[
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                      sliver: SliverToBoxAdapter(
                        child: const _SectionHeading(
                          title: 'Tax & Business Updates',
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: HomeContentRail(
                        items: homeContent.taxBusinessUpdates,
                        onTap: onContentTap,
                      ),
                    ),
                  ],
                  if (homeContent.learnGrow.isNotEmpty) ...[
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                      sliver: SliverToBoxAdapter(
                        child: const _SectionHeading(title: 'Learn & Grow'),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: HomeContentRail(
                        items: homeContent.learnGrow,
                        onTap: onContentTap,
                      ),
                    ),
                  ],
                  if (!isGuest && _hasCustomerAttention(summary)) ...[
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 11),
                      sliver: const SliverToBoxAdapter(
                        child: _SectionHeading(title: 'Needs Your Attention'),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverToBoxAdapter(
                        child: _NeedsAttentionCard(
                          summary: summary,
                          onTap: onPrimaryServiceAction,
                        ),
                      ),
                    ),
                  ],
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 11),
                    sliver: SliverToBoxAdapter(
                      child: _SectionHeading(
                        title: 'Your Services in Progress',
                        action: 'View all',
                        onTap: isGuest ? onSignUp : onOpenServices,
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverToBoxAdapter(
                      child: services.isEmpty
                          ? _EmptyServicesCard(
                              isGuest: isGuest,
                              onSignUp: onSignUp,
                            )
                          : _ServiceListCard(
                              services: services,
                              onTap: onOpenService,
                            ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 11),
                    sliver: const SliverToBoxAdapter(
                      child: _SectionHeading(title: 'Recent Activity'),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                    sliver: SliverToBoxAdapter(
                      child: activities.isEmpty
                          ? _EmptyActivityCard(
                              isGuest: isGuest,
                              onSignUp: onSignUp,
                              onSignIn: onSignIn,
                            )
                          : _ActivityCard(
                              activities: activities,
                              onTap: onActivityTap,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

bool _hasCustomerAttention(HomeDashboardSummary summary) {
  final action = summary.nextAction;
  if (action == null) return false;

  final normalized = action.type.trim().toLowerCase();

  if (normalized.isEmpty) return false;

  return normalized != 'browse_services' &&
      normalized != 'track_services' &&
      action.route.trim().isNotEmpty;
}

class _NeedsAttentionCard extends StatelessWidget {
  const _NeedsAttentionCard({required this.summary, required this.onTap});

  final HomeDashboardSummary summary;
  final ValueChanged<HomeDashboardServiceSnapshot> onTap;

  @override
  Widget build(BuildContext context) {
    final action = summary.nextAction;
    if (action == null) return const SizedBox.shrink();

    final services = summary.serviceSnapshots;
    final service = services.isNotEmpty ? services.first : null;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBFB),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFDA1735).withValues(alpha: 0.12),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A111827),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFDA1735).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.notification_important_outlined,
              color: Color(0xFFDA1735),
              size: 23,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  action.title.trim().isEmpty
                      ? 'Action required'
                      : action.title,
                  style: const TextStyle(
                    color: Color(0xFF111827),
                    fontSize: 15.5,
                    height: 1.2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (action.subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    action.subtitle,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (service != null) ...[
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () => onTap(service),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111827),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            action.buttonLabel.trim().isEmpty
                                ? 'Review'
                                : action.buttonLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 5),
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 15,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Background extends StatelessWidget {
  const _Background();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFBFCFE), Color(0xFFF7F8FA), Color(0xFFF4F6F9)],
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
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
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
        ? 'Good afternoon'
        : 'Good evening';

    final name = isGuest ? 'Guest' : _firstName(displayName);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: const TextStyle(
                  color: _navy,
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.15,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _navy,
                  fontSize: 31,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isGuest
                    ? 'Explore services and create your OMC account.'
                    : 'Welcome back! Here’s your dashboard.',
                style: const TextStyle(
                  color: Color(0xFF50617B),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _NotificationButton(count: unreadNotifications, onTap: onNotifications),
        const SizedBox(width: 13),
        GestureDetector(
          onTap: onAvatar,
          child: _Avatar(name: name, avatarUrl: avatarUrl, isGuest: isGuest),
        ),
      ],
    );
  }

  String _firstName(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Customer';
    return trimmed.split(RegExp(r'\s+')).first;
  }
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkResponse(
        onTap: onTap,
        radius: 27,
        child: SizedBox(
          width: 46,
          height: 50,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Align(
                alignment: Alignment.center,
                child: Icon(
                  Icons.notifications_none_rounded,
                  color: Color(0xFF20242B),
                  size: 29,
                ),
              ),
              if (count > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 24),
                    height: 24,
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _red,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Text(
                      count > 9 ? '9+' : '$count',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({
    required this.name,
    required this.avatarUrl,
    required this.isGuest,
  });

  final String name;
  final String? avatarUrl;
  final bool isGuest;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty
        ? 'U'
        : name.trim().substring(0, 1).toUpperCase();

    return Container(
      width: 55,
      height: 55,
      decoration: const BoxDecoration(
        color: Color(0xFFE9ECF1),
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: avatarUrl == null || avatarUrl!.trim().isEmpty || isGuest
          ? Center(
              child: Text(
                initial,
                style: const TextStyle(
                  color: _navy,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
            )
          : Image.network(
              avatarUrl!,
              fit: BoxFit.cover,
              webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
              errorBuilder: (_, error, stackTrace) => Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
    );
  }
}

class _SearchField extends StatefulWidget {
  const _SearchField({
    required this.services,
    required this.onSubmit,
    required this.onOpenResult,
  });

  final List<ServiceItem> services;
  final ValueChanged<String> onSubmit;
  final ValueChanged<String> onOpenResult;

  @override
  State<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends State<_SearchField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  String _query = '';

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (mounted) setState(() {});
  }

  void _submit() {
    final query = _controller.text.trim();
    if (query.isEmpty) return;

    _focusNode.unfocus();
    widget.onSubmit(query);
  }

  void _clear() {
    _controller.clear();
    setState(() => _query = '');
    _focusNode.requestFocus();
  }

  void _open(ServiceItem service) {
    _focusNode.unfocus();
    widget.onOpenResult(service.id);
  }

  List<ServiceItem> get _matches {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return const <ServiceItem>[];

    final words = query
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList(growable: false);

    final matches = widget.services
        .where((service) {
          final haystack = <String>[
            service.title,
            service.category,
            service.shortDescription ?? '',
            service.description ?? '',
            ...service.requirements,
          ].join(' ').toLowerCase();

          return words.every(haystack.contains);
        })
        .toList(growable: false);

    matches.sort((a, b) {
      final aTitle = a.title.toLowerCase();
      final bTitle = b.title.toLowerCase();
      final aStarts = aTitle.startsWith(query);
      final bStarts = bTitle.startsWith(query);

      if (aStarts != bStarts) return aStarts ? -1 : 1;
      return a.title.compareTo(b.title);
    });

    return matches.take(5).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final matches = _matches;
    final showPanel = _focusNode.hasFocus && _query.trim().isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: (value) => setState(() => _query = value),
          onSubmitted: (_) => _submit(),
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search services, requests or tools',
            hintStyle: const TextStyle(
              color: Color(0xFF69717F),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              size: 27,
              color: Color(0xFF434B58),
            ),
            suffixIcon: _query.isEmpty
                ? IconButton(
                    tooltip: 'Search',
                    onPressed: _submit,
                    icon: const Icon(Icons.arrow_forward_rounded),
                  )
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: _clear,
                    icon: const Icon(Icons.close_rounded),
                  ),
            filled: true,
            fillColor: Colors.white.withValues(alpha: 0.95),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: const BorderSide(color: Color(0xFFE2E4E8)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: const BorderSide(color: Color(0xFFE2E4E8)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: const BorderSide(
                color: Color(0xFF111827),
                width: 1.2,
              ),
            ),
          ),
        ),
        if (showPanel) ...[
          const SizedBox(height: 8),
          Material(
            color: Colors.white,
            elevation: 8,
            shadowColor: const Color(0x22000000),
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: matches.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_off_rounded,
                          color: Color(0xFF69717F),
                          size: 22,
                        ),
                        SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            'No matching services found',
                            style: TextStyle(
                              color: Color(0xFF50617B),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var index = 0; index < matches.length; index++) ...[
                        _SearchSuggestion(
                          service: matches[index],
                          onTap: () => _open(matches[index]),
                        ),
                        if (index < matches.length - 1)
                          const Divider(
                            height: 1,
                            indent: 56,
                            color: Color(0xFFE8EAF0),
                          ),
                      ],
                      InkWell(
                        onTap: _submit,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 13,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_rounded, size: 19, color: _red),
                              SizedBox(width: 7),
                              Text(
                                'View all search results',
                                style: TextStyle(
                                  color: _red,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ],
    );
  }
}

class _SearchSuggestion extends StatelessWidget {
  const _SearchSuggestion({required this.service, required this.onTap});

  final ServiceItem service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shortDescription = service.shortDescription?.trim() ?? '';
    final subtitle = shortDescription.isNotEmpty
        ? shortDescription
        : service.category.trim();

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 12, 12, 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Color(0xFFFDECEF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.work_outline_rounded,
                color: _red,
                size: 19,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _navy,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF69717F),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.north_west_rounded,
              color: Color(0xFF69717F),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroArea extends StatelessWidget {
  const _HeroArea({
    required this.summary,
    required this.isGuest,
    required this.isPending,
    required this.isRejected,
    required this.onPrimaryServiceAction,
    required this.onOpenServices,
    required this.onSignUp,
  });

  final HomeDashboardSummary summary;
  final bool isGuest;
  final bool isPending;
  final bool isRejected;
  final ValueChanged<HomeDashboardServiceSnapshot> onPrimaryServiceAction;
  final VoidCallback onOpenServices;
  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context) {
    if (!isGuest) {
      if (summary.serviceSnapshots.isNotEmpty) {
        return _ServiceHeroCard(
          service: summary.serviceSnapshots.first,
          nextAction: summary.nextAction,
          onPrimaryAction: () =>
              onPrimaryServiceAction(summary.serviceSnapshots.first),
        );
      }

      return _CustomerEmptyHeroCard(onOpenServices: onOpenServices);
    }

    return _GuestHeroCard(
      isPending: isPending,
      isRejected: isRejected,
      onSignUp: onSignUp,
    );
  }
}

class _CustomerEmptyHeroCard extends StatelessWidget {
  const _CustomerEmptyHeroCard({required this.onOpenServices});

  final VoidCallback onOpenServices;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      radius: 28,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFFFDECEF),
                  borderRadius: BorderRadius.circular(19),
                ),
                child: const Icon(
                  Icons.business_center_outlined,
                  color: _red,
                  size: 29,
                ),
              ),
              const SizedBox(width: 15),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Start your first OMC service',
                      style: TextStyle(
                        color: _navy,
                        fontSize: 18,
                        height: 1.18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.25,
                      ),
                    ),
                    SizedBox(height: 7),
                    Text(
                      'Browse available services and submit a request when you are ready.',
                      style: TextStyle(
                        color: Color(0xFF56647A),
                        fontSize: 12.5,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: onOpenServices,
              style: FilledButton.styleFrom(
                elevation: 0,
                backgroundColor: _red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
              icon: const Icon(Icons.grid_view_rounded, size: 20),
              label: const Text(
                'Browse services',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuestHeroCard extends StatelessWidget {
  const _GuestHeroCard({
    required this.isPending,
    required this.isRejected,
    required this.onSignUp,
  });

  final bool isPending;
  final bool isRejected;
  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context) {
    final title = isPending
        ? 'Your profile is under review'
        : isRejected
        ? 'Complete your OMC profile'
        : 'Manage every OMC service in one place';

    final message = isPending
        ? 'You can explore the app while our team verifies your account.'
        : isRejected
        ? 'Update your profile or contact OMC support to restore access.'
        : 'Create an account to track requests, upload documents, '
              'manage payments and receive live updates.';

    return _SurfaceCard(
      radius: 28,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFFFDECEF),
                  borderRadius: BorderRadius.circular(19),
                ),
                child: const Icon(
                  Icons.business_center_outlined,
                  color: _red,
                  size: 29,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: _navy,
                        fontSize: 18,
                        height: 1.18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.25,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      message,
                      style: const TextStyle(
                        color: Color(0xFF56647A),
                        fontSize: 12.5,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: onSignUp,
              style: FilledButton.styleFrom(
                elevation: 0,
                backgroundColor: _red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
              label: Text(
                isPending ? 'View account status' : 'Create OMC account',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceHeroCard extends StatelessWidget {
  const _ServiceHeroCard({
    required this.service,
    required this.nextAction,
    required this.onPrimaryAction,
  });

  final HomeDashboardServiceSnapshot service;
  final HomeDashboardNextAction? nextAction;
  final VoidCallback onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    final progress = service.progress.clamp(0.0, 1.0);
    final percentage = (progress * 100).round();
    final tone = _statusColor(service.statusLabel);
    final missing = service.documentSummary.missing;

    return _SurfaceCard(
      radius: 29,
      padding: const EdgeInsets.fromLTRB(20, 21, 20, 20),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(_serviceIcon(service), color: tone, size: 32),
              ),
              const SizedBox(width: 17),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.title.isEmpty ? 'OMC Service' : service.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _navy,
                        fontSize: 20,
                        height: 1.12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.45,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      service.id,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF50617B),
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusPill(
                label: service.statusLabel.isEmpty
                    ? 'In Progress'
                    : service.statusLabel,
                color: tone,
              ),
            ],
          ),
          const SizedBox(height: 17),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: const Color(0xFFF0F1F3),
                    valueColor: AlwaysStoppedAnimation<Color>(tone),
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Text(
                '$percentage%',
                style: TextStyle(
                  color: tone,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              Container(
                width: 31,
                height: 31,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.info_outline_rounded, color: tone, size: 17),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _nextStepLabel(service, nextAction),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 12.5,
                    height: 1.3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (missing > 0) ...[
                const SizedBox(width: 8),
                Text(
                  '$missing document${missing == 1 ? '' : 's'} missing',
                  style: TextStyle(
                    color: tone,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
              const SizedBox(width: 2),
              Icon(Icons.chevron_right_rounded, color: tone, size: 23),
            ],
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            height: 51,
            child: FilledButton.icon(
              onPressed: onPrimaryAction,
              style: FilledButton.styleFrom(
                elevation: 0,
                backgroundColor: _red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: Icon(_primaryIcon(service, nextAction), size: 21),
              label: Text(
                _primaryLabel(service, nextAction),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Color _statusColor(String status) {
    final value = status.toLowerCase();

    if (value.contains('review') ||
        value.contains('pending') ||
        value.contains('waiting')) {
      return _orange;
    }

    if (value.contains('complete') ||
        value.contains('approved') ||
        value.contains('paid')) {
      return _green;
    }

    return _red;
  }

  static IconData _serviceIcon(HomeDashboardServiceSnapshot service) {
    final value = '${service.title} ${service.colorFamily ?? ''}'.toLowerCase();

    if (value.contains('company') || value.contains('business')) {
      return Icons.apartment_rounded;
    }

    if (value.contains('tax')) {
      return Icons.business_center_outlined;
    }

    return Icons.work_outline_rounded;
  }

  static String _nextStepLabel(
    HomeDashboardServiceSnapshot service,
    HomeDashboardNextAction? nextAction,
  ) {
    final title = nextAction?.title.trim() ?? '';
    final subtitle = nextAction?.subtitle.trim() ?? '';

    if (title.isNotEmpty && subtitle.isNotEmpty) {
      return 'Next step: $subtitle';
    }

    if (subtitle.isNotEmpty) return 'Next step: $subtitle';
    if (title.isNotEmpty) return 'Next step: $title';

    if (service.documentSummary.missing > 0) {
      return 'Next step: Upload required document';
    }

    return 'Next step: View service details';
  }

  static String _primaryLabel(
    HomeDashboardServiceSnapshot service,
    HomeDashboardNextAction? nextAction,
  ) {
    final configured = nextAction?.buttonLabel.trim() ?? '';
    if (configured.isNotEmpty) return configured;

    if (service.documentSummary.missing > 0) {
      return 'Upload document';
    }

    return 'View service';
  }

  static IconData _primaryIcon(
    HomeDashboardServiceSnapshot service,
    HomeDashboardNextAction? nextAction,
  ) {
    final type = nextAction?.type.toLowerCase() ?? '';

    if (type.contains('document') || service.documentSummary.missing > 0) {
      return Icons.upload_file_outlined;
    }

    if (type.contains('payment')) {
      return Icons.payments_outlined;
    }

    return Icons.arrow_forward_rounded;
  }
}

class _QuickActionStrip extends StatelessWidget {
  const _QuickActionStrip({
    required this.actions,
    required this.isActionAllowed,
    required this.onAction,
    required this.onLockedAction,
  });

  final List<MobileQuickAction> actions;
  final bool Function(MobileQuickAction) isActionAllowed;
  final ValueChanged<MobileQuickAction> onAction;
  final ValueChanged<MobileQuickAction> onLockedAction;

  @override
  Widget build(BuildContext context) {
    final visible = actions.take(5).toList(growable: false);

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 560;
        final columns = compact ? 3 : 5;
        final spacing = compact ? 8.0 : 10.0;
        final itemWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: 4,
          children: [
            for (final action in visible)
              SizedBox(
                width: itemWidth,
                height: 74,
                child: _QuickActionTile(
                  action: action,
                  locked: !isActionAllowed(action),
                  onTap: () {
                    if (isActionAllowed(action)) {
                      onAction(action);
                    } else {
                      onLockedAction(action);
                    }
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.action,
    required this.locked,
    required this.onTap,
  });

  final MobileQuickAction action;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = _actionPalette(action.iconKey);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _actionIcon(action.iconKey),
                    color: palette.accent,
                    size: 30,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    action.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF34445E),
                      fontSize: 12,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              if (locked)
                Positioned(
                  right: 12,
                  top: -2,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: palette.border),
                      boxShadow: const [
                        BoxShadow(color: Color(0x12000000), blurRadius: 5),
                      ],
                    ),
                    child: Icon(
                      Icons.lock_rounded,
                      size: 11,
                      color: palette.accent,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceListCard extends StatelessWidget {
  const _ServiceListCard({required this.services, required this.onTap});

  final List<HomeDashboardServiceSnapshot> services;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      radius: 25,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
      child: Column(
        children: [
          for (var index = 0; index < services.length; index++) ...[
            _ServiceRow(
              service: services[index],
              onTap: () => onTap(services[index].id),
            ),
            if (index < services.length - 1)
              const Divider(height: 1, color: Color(0xFFE4E6EA)),
          ],
        ],
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({required this.service, required this.onTap});

  final HomeDashboardServiceSnapshot service;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final progress = service.progress.clamp(0.0, 1.0);
    final percentage = (progress * 100).round();
    final tone = _ServiceHeroCard._statusColor(service.statusLabel);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Icon(
                _ServiceHeroCard._serviceIcon(service),
                color: tone,
                size: 25,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          service.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _navy,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      _StatusPill(
                        label: service.statusLabel,
                        color: tone,
                        compact: true,
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFF1F2937),
                        size: 23,
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    service.id,
                    style: const TextStyle(
                      color: Color(0xFF50617B),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(999),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: const Color(0xFFF0F1F3),
                            valueColor: AlwaysStoppedAnimation<Color>(tone),
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Text(
                        '$percentage%',
                        style: TextStyle(
                          color: tone,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _ServiceHeroCard._nextStepLabel(service, null),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF50617B),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
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

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activities, required this.onTap});

  final List<HomeDashboardActivity> activities;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      radius: 25,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
      child: Column(
        children: [
          for (var index = 0; index < activities.length; index++) ...[
            _ActivityRow(activity: activities[index], onTap: onTap),
            if (index < activities.length - 1)
              const Divider(height: 1, color: Color(0xFFE4E6EA)),
          ],
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.activity, required this.onTap});

  final HomeDashboardActivity activity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = _activityPalette(activity);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Container(
              width: 37,
              height: 37,
              decoration: BoxDecoration(
                color: palette.background,
                shape: BoxShape.circle,
              ),
              child: Icon(palette.icon, color: palette.color, size: 19),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: _navy,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    activity.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF50617B),
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            if ((activity.createdAtLabel ?? '').trim().isNotEmpty)
              Text(
                activity.createdAtLabel!,
                style: const TextStyle(
                  color: Color(0xFF50617B),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(width: 5),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF1F2937),
              size: 21,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyServicesCard extends StatelessWidget {
  const _EmptyServicesCard({required this.isGuest, required this.onSignUp});

  final bool isGuest;
  final VoidCallback onSignUp;

  @override
  Widget build(BuildContext context) {
    return _LockedPreviewCard(
      icon: Icons.business_center_outlined,
      title: isGuest ? 'Your services will appear here' : 'No active services',
      message: isGuest
          ? 'Create an account to start and track OMC services.'
          : 'Your active requests will appear here when available.',
      buttonLabel: isGuest ? 'Get started' : null,
      onPressed: isGuest ? onSignUp : null,
    );
  }
}

class _EmptyActivityCard extends StatelessWidget {
  const _EmptyActivityCard({
    required this.isGuest,
    required this.onSignUp,
    required this.onSignIn,
  });

  final bool isGuest;
  final VoidCallback onSignUp;
  final VoidCallback onSignIn;

  @override
  Widget build(BuildContext context) {
    return _LockedPreviewCard(
      icon: Icons.history_rounded,
      title: isGuest ? 'Recent activity is locked' : 'No recent activity',
      message: isGuest
          ? 'Sign up to receive document, payment and service updates.'
          : 'Your latest OMC account activity will appear here.',
      buttonLabel: isGuest ? 'Create account' : null,
      onPressed: isGuest ? onSignUp : null,
    );
  }
}

class _LockedPreviewCard extends StatelessWidget {
  const _LockedPreviewCard({
    required this.icon,
    required this.title,
    required this.message,
    this.buttonLabel,
    this.onPressed,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return _SurfaceCard(
      radius: 24,
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFFDECEF),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: _red, size: 24),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: _navy,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: Color(0xFF50617B),
                    fontSize: 11,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (buttonLabel != null)
            TextButton(
              onPressed: onPressed,
              child: Text(
                buttonLabel!,
                style: const TextStyle(
                  color: _red,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.title, this.action, this.onTap});

  final String title;
  final String? action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: _navy,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
        ),
        if (action != null)
          TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              minimumSize: const Size(0, 35),
              foregroundColor: _red,
            ),
            child: Row(
              children: [
                Text(
                  action!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (action == 'View all') ...[
                  const SizedBox(width: 3),
                  const Icon(Icons.chevron_right_rounded, size: 20),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    this.compact = false,
  });

  final String label;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 11,
        vertical: compact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label.isEmpty ? 'In Progress' : label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: compact ? 9 : 10.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _SurfaceCard extends StatelessWidget {
  const _SurfaceCard({
    required this.child,
    required this.padding,
    required this.radius,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.97),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0B0F172A),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ActionPalette {
  const _ActionPalette({
    required this.accent,
    required this.background,
    required this.border,
  });

  final Color accent;
  final Color background;
  final Color border;
}

_ActionPalette _actionPalette(String key) {
  final value = key.toLowerCase();

  if (value.contains('document')) {
    return const _ActionPalette(
      accent: _blue,
      background: Color(0xFFF2F6FF),
      border: Color(0xFFD7E2FA),
    );
  }

  if (value.contains('payment')) {
    return const _ActionPalette(
      accent: _green,
      background: Color(0xFFF1FAF1),
      border: Color(0xFFD8ECD8),
    );
  }

  if (value.contains('calculator') || value.contains('tax')) {
    return const _ActionPalette(
      accent: _orange,
      background: Color(0xFFFFF7EE),
      border: Color(0xFFF4E2CD),
    );
  }

  if (value.contains('expense')) {
    return const _ActionPalette(
      accent: _purple,
      background: Color(0xFFF7F4FF),
      border: Color(0xFFE5DDFC),
    );
  }

  return const _ActionPalette(
    accent: _red,
    background: Color(0xFFFFF5F6),
    border: Color(0xFFF3D8DD),
  );
}

IconData _actionIcon(String key) {
  final value = key.toLowerCase();

  if (value.contains('document')) {
    return Icons.description_outlined;
  }

  if (value.contains('payment')) {
    return Icons.credit_card_rounded;
  }

  if (value.contains('calculator') || value.contains('tax')) {
    return Icons.calculate_outlined;
  }

  if (value.contains('expense')) {
    return Icons.pie_chart_outline_rounded;
  }

  return Icons.business_center_outlined;
}

class _ActivityPalette {
  const _ActivityPalette({
    required this.icon,
    required this.color,
    required this.background,
  });

  final IconData icon;
  final Color color;
  final Color background;
}

_ActivityPalette _activityPalette(HomeDashboardActivity activity) {
  final value =
      '${activity.title} ${activity.subtitle} ${activity.status ?? ''}'
          .toLowerCase();

  if (value.contains('approved') || value.contains('complete')) {
    return const _ActivityPalette(
      icon: Icons.check_circle_outline_rounded,
      color: _green,
      background: Color(0xFFECF9EF),
    );
  }

  if (value.contains('payment') || value.contains('receipt')) {
    return const _ActivityPalette(
      icon: Icons.account_balance_wallet_outlined,
      color: _blue,
      background: Color(0xFFEDF3FF),
    );
  }

  return const _ActivityPalette(
    icon: Icons.person_outline_rounded,
    color: _orange,
    background: Color(0xFFFFF3E7),
  );
}

class _HomeLoadNotice extends StatelessWidget {
  const _HomeLoadNotice({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 20,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
