import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/design_tokens.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/app_back_header.dart';
import '../../../core/widgets/app_state.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/premium_card.dart';
import '../data/referral_repository.dart';
import '../data/referral_summary.dart';

class MyReferralsScreen extends ConsumerStatefulWidget {
  const MyReferralsScreen({super.key});

  @override
  ConsumerState<MyReferralsScreen> createState() => _MyReferralsScreenState();
}

class _MyReferralsScreenState extends ConsumerState<MyReferralsScreen> {
  static const _pageSize = 20;
  final _searchController = TextEditingController();

  ReferralSummary? _summary;
  final _items = <ReferralCustomer>[];
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int? _nextStart;
  Object? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _load(refresh: true));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) {
      if (mounted) {
        setState(() {
          _loading = true;
          _error = null;
          _items.clear();
          _nextStart = 0;
          _hasMore = false;
        });
      }
    } else {
      if (_loadingMore || !_hasMore || _nextStart == null) return;
      setState(() => _loadingMore = true);
    }

    try {
      final repository = ref.read(referralRepositoryProvider);
      if (refresh) {
        final summary = await repository.fetchSummary();
        if (!mounted) return;
        _summary = summary;
      }
      final page = await repository.fetchReferralPage(
        search: _searchController.text,
        limitStart: refresh ? 0 : (_nextStart ?? 0),
        limitPageLength: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _hasMore = page.hasMore;
        _nextStart = page.nextStart;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadingMore = false;
        });
      }
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _load(refresh: true);
  }

  Future<void> _copyCode() async {
    final code = _summary?.code.trim() ?? '';
    if (code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Referral code copied.')));
  }

  Future<void> _shareCode() async {
    final code = _summary?.code.trim() ?? '';
    if (code.isEmpty || !(_summary?.isActive ?? false)) return;
    await Share.share(
      'Join OMC using my referral code: $code',
      subject: 'OMC referral code',
    );
  }

  void _openDetail(ReferralCustomer customer) {
    context.push(
      '/my-referrals/${Uri.encodeComponent(customer.id)}'
      '?name=${Uri.encodeQueryComponent(customer.displayName)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: const AppBackHeader(title: 'My referrals'),
      body: RefreshIndicator.adaptive(
        onRefresh: () => _load(refresh: true),
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
                if (_loading)
                  const SizedBox(
                    height: 360,
                    child: LoadingView(message: 'Loading referrals...'),
                  )
                else if (_error != null && _items.isEmpty)
                  AppErrorState.fromError(
                    error: _error!,
                    fallbackTitle: 'Referrals unavailable',
                    fallbackMessage:
                        'Your referrals could not be loaded right now.',
                    onRetry: () => _load(refresh: true),
                  )
                else ...[
                  if (_summary != null)
                    _ReferralCodeCard(
                      summary: _summary!,
                      onCopy: _copyCode,
                      onShare: _shareCode,
                    ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    'Referral customers',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Search customers who joined through your referral access.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _SearchField(
                    controller: _searchController,
                    onSearch: () => _load(refresh: true),
                    onClear: _clearSearch,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _ResultSummary(
                    summary: _summary,
                    loadedCount: _items.length,
                    hasSearch: _searchController.text.trim().isNotEmpty,
                    hasMore: _hasMore,
                    onClear: _clearSearch,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  if (_items.isEmpty)
                    EmptyState(
                      title: _searchController.text.trim().isEmpty
                          ? 'No referrals yet'
                          : 'No matching referrals',
                      message: _searchController.text.trim().isEmpty
                          ? 'Customers who join through your referral code will appear here.'
                          : 'Try a different name, phone number or email.',
                      icon: Icons.people_outline_rounded,
                    )
                  else
                    for (var index = 0; index < _items.length; index++) ...[
                      _ReferralCustomerCard(
                        customer: _items[index],
                        onTap: () => _openDetail(_items[index]),
                      ),
                      if (index != _items.length - 1)
                        const SizedBox(height: AppSpacing.sm),
                    ],
                  if (_error != null && _items.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'More referrals could not be loaded. Pull to refresh or try again.',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: AppTheme.danger),
                    ),
                  ],
                  if (_loadingMore)
                    const Padding(
                      padding: EdgeInsets.all(AppSpacing.lg),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_hasMore) ...[
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _load,
                        icon: const Icon(Icons.expand_more_rounded),
                        label: const Text('Load more referrals'),
                      ),
                    ),
                  ],
                  if (_summary != null) ...[
                    const SizedBox(height: AppSpacing.xl),
                    _ReferralSummaryCard(summary: _summary!),
                  ],
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ReferralCodeCard extends StatelessWidget {
  const _ReferralCodeCard({
    required this.summary,
    required this.onCopy,
    required this.onShare,
  });

  final ReferralSummary summary;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  @override
  Widget build(BuildContext context) {
    final active = summary.isActive;
    final color = active ? AppTheme.success : AppTheme.danger;
    final background = active ? AppTheme.successSoft : AppTheme.dangerSoft;
    final textScale = MediaQuery.textScalerOf(context).scale(1);

    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Referral code',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _StateBadge(
                label: active ? 'Active' : 'Inactive',
                color: color,
                background: background,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          SelectableText(
            summary.code.isEmpty ? 'Not available' : summary.code,
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            active
                ? 'Customers can use this code when joining OMC.'
                : 'This code is inactive and cannot be used for new referrals.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final stack = constraints.maxWidth < 320 || textScale >= 1.5;
              final copy = OutlinedButton.icon(
                onPressed: summary.code.isEmpty ? null : onCopy,
                icon: const Icon(Icons.copy_rounded),
                label: const Text('Copy code'),
              );
              final share = FilledButton.icon(
                onPressed: active && summary.code.isNotEmpty ? onShare : null,
                icon: const Icon(Icons.share_outlined),
                label: const Text('Share code'),
              );
              if (stack) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    share,
                    const SizedBox(height: AppSpacing.xs),
                    copy,
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: copy),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(child: share),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onSearch,
    required this.onClear,
  });

  final TextEditingController controller;
  final VoidCallback onSearch;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => onSearch(),
      decoration: InputDecoration(
        labelText: 'Search referrals',
        hintText: 'Name, phone or email',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: controller.text.trim().isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
              ),
      ),
    );
  }
}

class _ResultSummary extends StatelessWidget {
  const _ResultSummary({
    required this.summary,
    required this.loadedCount,
    required this.hasSearch,
    required this.hasMore,
    required this.onClear,
  });

  final ReferralSummary? summary;
  final int loadedCount;
  final bool hasSearch;
  final bool hasMore;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            hasSearch
                ? '$loadedCount matching referral${loadedCount == 1 ? '' : 's'} loaded'
                : hasMore
                ? '$loadedCount referrals loaded · more available'
                : '${summary?.totalReferrals ?? loadedCount} referrals',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
          ),
        ),
        if (hasSearch) ...[
          const SizedBox(width: AppSpacing.xs),
          TextButton(onPressed: onClear, child: const Text('Clear')),
        ],
      ],
    );
  }
}

class _ReferralCustomerCard extends StatelessWidget {
  const _ReferralCustomerCard({required this.customer, required this.onTap});

  final ReferralCustomer customer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: onTap,
      semanticLabel:
          '${customer.displayName}. ${customer.customerStatus.isEmpty ? 'Status unavailable' : customer.customerStatus}. ${customer.consentGranted ? 'Assistance consent granted' : 'No assistance consent'}. Open referral details.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppTheme.processingSoft,
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: Text(
                  _initials(customer.displayName),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.displayName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      customer.contactLine,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _StateBadge(
                label: customer.customerStatus.isEmpty
                    ? 'Status unavailable'
                    : customer.customerStatus,
                color: AppTheme.processing,
                background: AppTheme.processingSoft,
              ),
              _StateBadge(
                label: customer.consentGranted
                    ? 'Assistance consented'
                    : 'No assistance consent',
                color: customer.consentGranted
                    ? AppTheme.success
                    : AppTheme.processing,
                background: customer.consentGranted
                    ? AppTheme.successSoft
                    : AppTheme.processingSoft,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${customer.totalServices} service${customer.totalServices == 1 ? '' : 's'}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ReferralSummaryCard extends StatelessWidget {
  const _ReferralSummaryCard({required this.summary});

  final ReferralSummary summary;

  @override
  Widget build(BuildContext context) {
    final items = <(String, int)>[
      ('Total referrals', summary.totalReferrals),
      ('Active referrals', summary.activeReferrals),
      ('Total services', summary.totalServices),
      ('Consented referrals', summary.consentedReferrals),
      ('Customer-created services', summary.selfCreatedServices),
      ('Started by you', summary.referrerCreatedServices),
    ];

    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Summary', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.sm,
            children: items
                .map(
                  (item) => ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 120),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item.$2}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(
                          item.$1,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _StateBadge extends StatelessWidget {
  const _StateBadge({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
      ),
    );
  }
}

String _initials(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2);
  final initials = parts.map((part) => part[0].toUpperCase()).join();
  return initials.isEmpty ? 'OMC' : initials;
}
