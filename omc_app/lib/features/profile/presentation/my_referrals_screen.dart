import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

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
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Referral code copied.')),
    );
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
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: const AppBackHeader(title: 'My Referrals'),
      body: RefreshIndicator(
        onRefresh: () => _load(refresh: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
          children: [
            if (_loading)
              const SizedBox(
                height: 360,
                child: LoadingView(message: 'Loading referral dashboard...'),
              )
            else if (_error != null && _items.isEmpty)
              AppErrorState.fromError(
                error: _error!,
                fallbackTitle: 'Referrals unavailable',
                fallbackMessage:
                    'Your referral dashboard could not be loaded right now.',
                onRetry: () => _load(refresh: true),
              )
            else ...[
              if (_summary != null)
                _ReferralHero(
                  summary: _summary!,
                  onCopy: _copyCode,
                  onShare: _shareCode,
                ),
              const SizedBox(height: 14),
              if (_summary != null) _PrimaryMetrics(summary: _summary!),
              if (_summary != null &&
                  (_summary!.selfCreatedServices > 0 ||
                      _summary!.referrerCreatedServices > 0 ||
                      _summary!.consentedReferrals > 0)) ...[
                const SizedBox(height: 10),
                _SecondaryMetrics(summary: _summary!),
              ],
              const SizedBox(height: 18),
              _SearchCard(
                controller: _searchController,
                onSearch: () => _load(refresh: true),
                onClear: _clearSearch,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _searchController.text.trim().isEmpty
                          ? '${_summary?.totalReferrals ?? _items.length} referrals'
                          : '${_items.length} matching result${_items.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (_searchController.text.trim().isNotEmpty)
                    TextButton(
                      onPressed: _clearSearch,
                      child: const Text('Clear'),
                    ),
                ],
              ),
              const SizedBox(height: 4),
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
                for (final item in _items) ...[
                  _ReferralCustomerCard(
                    customer: item,
                    onTap: () => _openDetail(item),
                  ),
                  const SizedBox(height: 10),
                ],
              if (_error != null && _items.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'More referrals could not be loaded. Pull to refresh or try again.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (_loadingMore)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_hasMore)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.expand_more_rounded),
                    label: const Text('Load more referrals'),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReferralHero extends StatelessWidget {
  const _ReferralHero({
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
    return PremiumCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Referral code',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFFEAF8F0)
                      : const Color(0xFFFFF1F0),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  active ? 'Active' : 'Inactive',
                  style: TextStyle(
                    color: active
                        ? const Color(0xFF067647)
                        : const Color(0xFFB42318),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(
            summary.code.isEmpty ? 'Not available' : summary.code,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: summary.code.isEmpty ? null : onCopy,
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copy'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: active && summary.code.isNotEmpty ? onShare : null,
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: const Text('Share'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            active
                ? 'Customers can use this code when joining OMC.'
                : 'This code is inactive and cannot be used for new referrals.',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryMetrics extends StatelessWidget {
  const _PrimaryMetrics({required this.summary});
  final ReferralSummary summary;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: _Metric(label: 'Total', value: summary.totalReferrals)),
      const SizedBox(width: 10),
      Expanded(child: _Metric(label: 'Active', value: summary.activeReferrals)),
      const SizedBox(width: 10),
      Expanded(child: _Metric(label: 'Services', value: summary.totalServices)),
    ],
  );
}

class _SecondaryMetrics extends StatelessWidget {
  const _SecondaryMetrics({required this.summary});
  final ReferralSummary summary;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      _CompactMetric('Consented', summary.consentedReferrals),
      _CompactMetric('Customer-created', summary.selfCreatedServices),
      _CompactMetric('Started by you', summary.referrerCreatedServices),
    ],
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => PremiumCard(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
    child: Column(
      children: [
        Text(
          '$value',
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );
}

class _CompactMetric extends StatelessWidget {
  const _CompactMetric(this.label, this.value);
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: AppTheme.border),
    ),
    child: Text(
      '$label $value',
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _SearchCard extends StatelessWidget {
  const _SearchCard({
    required this.controller,
    required this.onSearch,
    required this.onClear,
  });

  final TextEditingController controller;
  final VoidCallback onSearch;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => PremiumCard(
    padding: const EdgeInsets.all(14),
    child: TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => onSearch(),
      decoration: InputDecoration(
        hintText: 'Search referrals',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: controller.text.trim().isEmpty
            ? null
            : IconButton(
                tooltip: 'Clear search',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
              ),
      ),
    ),
  );
}

class _ReferralCustomerCard extends StatelessWidget {
  const _ReferralCustomerCard({required this.customer, required this.onTap});

  final ReferralCustomer customer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => PremiumCard(
    padding: EdgeInsets.zero,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                _initials(customer.displayName),
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.displayName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    customer.contactLine,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      _StatusChip(
                        customer.customerStatus.isEmpty
                            ? 'Status unavailable'
                            : customer.customerStatus,
                      ),
                      _StatusChip(
                        customer.consentGranted
                            ? 'Assistance consented'
                            : 'No assistance consent',
                      ),
                      _StatusChip('${customer.totalServices} services'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
          ],
        ),
      ),
    ),
  );
}

class _StatusChip extends StatelessWidget {
  const _StatusChip(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFF2F4F7),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: const Color(0xFFD0D5DD)),
    ),
    child: Text(
      label,
      style: const TextStyle(
        color: Color(0xFF475467),
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
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
