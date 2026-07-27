import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/app_back_header.dart';
import '../../../core/widgets/app_state.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/premium_card.dart';
import '../data/referral_repository.dart';

class MyReferralsScreen extends ConsumerStatefulWidget {
  const MyReferralsScreen({super.key});

  @override
  ConsumerState<MyReferralsScreen> createState() => _MyReferralsScreenState();
}

class _MyReferralsScreenState extends ConsumerState<MyReferralsScreen> {
  final _searchController = TextEditingController();

  List<ReferralCustomer> _items = const [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final items = await ref
          .read(referralRepositoryProvider)
          .fetchReferrals(search: _searchController.text);

      if (!mounted) return;
      setState(() => _items = items);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _clearSearch() {
    _searchController.clear();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: const AppBackHeader(title: 'My Referrals'),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 140),
          children: [
            _SearchCard(
              controller: _searchController,
              onSearch: _load,
              onClear: _clearSearch,
            ),
            const SizedBox(height: 14),
            if (_loading)
              const SizedBox(
                height: 320,
                child: LoadingView(message: 'Loading your referrals...'),
              )
            else if (_error != null)
              AppErrorState.fromError(
                error: _error!,
                fallbackTitle: 'Referrals unavailable',
                fallbackMessage:
                    'Your authorised referral list could not be loaded right now.',
                onRetry: _load,
              )
            else if (_items.isEmpty)
              EmptyState(
                title: _searchController.text.trim().isEmpty
                    ? 'No referrals yet'
                    : 'No matching referrals',
                message: _searchController.text.trim().isEmpty
                    ? 'Customers who join through your referral code will appear here.'
                    : 'Try a different name, phone number or email.',
                icon: Icons.people_outline_rounded,
              )
            else ...[
              Text(
                '${_items.length} referral${_items.length == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              for (final item in _items) ...[
                _ReferralCustomerCard(customer: item),
                const SizedBox(height: 10),
              ],
            ],
          ],
        ),
      ),
    );
  }
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
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: TextField(
        controller: controller,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => onSearch(),
        decoration: InputDecoration(
          hintText: 'Search name, phone or email',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: IconButton(
            tooltip: 'Clear search',
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded),
          ),
        ),
      ),
    );
  }
}

class _ReferralCustomerCard extends StatelessWidget {
  const _ReferralCustomerCard({required this.customer});

  final ReferralCustomer customer;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
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
                const SizedBox(height: 10),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _StatusChip(
                      label: customer.consentGranted
                          ? 'Assistance consented'
                          : 'No assistance consent',
                      positive: customer.consentGranted,
                    ),
                    if (customer.approvalStatus.isNotEmpty)
                      _StatusChip(
                        label: customer.approvalStatus,
                        positive: customer.approvalStatus
                            .toLowerCase()
                            .contains('approv'),
                      ),
                    if (customer.customerStatus.isNotEmpty)
                      _StatusChip(
                        label: customer.customerStatus,
                        positive: customer.customerStatus
                            .toLowerCase()
                            .contains('active'),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
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
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.positive});

  final String label;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final foreground = positive
        ? const Color(0xFF067647)
        : const Color(0xFF475467);
    final background = positive
        ? const Color(0xFFEAF8F0)
        : const Color(0xFFF2F4F7);
    final border = positive ? const Color(0xFFBFE8D0) : const Color(0xFFD0D5DD);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
