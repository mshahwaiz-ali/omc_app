import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/app_back_header.dart';
import '../../../core/widgets/app_state.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/premium_card.dart';
import '../data/referral_repository.dart';
import '../data/referral_summary.dart';
import 'referral_detail_screen.dart';

class MyReferralsScreen extends ConsumerStatefulWidget {
  const MyReferralsScreen({super.key});

  @override
  ConsumerState<MyReferralsScreen> createState() => _MyReferralsScreenState();
}

class _MyReferralsScreenState extends ConsumerState<MyReferralsScreen> {
  final _searchController = TextEditingController();

  ReferralSummary? _summary;
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
      final repository = ref.read(referralRepositoryProvider);
      final results = await Future.wait([
        repository.fetchSummary(),
        repository.fetchReferrals(search: _searchController.text),
      ]);

      if (!mounted) return;
      setState(() {
        _summary = results[0] as ReferralSummary;
        _items = results[1] as List<ReferralCustomer>;
      });
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

  Future<void> _copyCode() async {
    final code = _summary?.code.trim() ?? '';
    if (code.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Referral code copied.')));
  }

  void _openDetail(ReferralCustomer customer) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReferralDetailScreen(
          customerProfile: customer.id,
          customerName: customer.displayName,
        ),
      ),
    );
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
            if (_loading)
              const SizedBox(
                height: 360,
                child: LoadingView(message: 'Loading referral dashboard...'),
              )
            else if (_error != null)
              AppErrorState.fromError(
                error: _error!,
                fallbackTitle: 'Referrals unavailable',
                fallbackMessage:
                    'Your referral dashboard could not be loaded right now.',
                onRetry: _load,
              )
            else ...[
              if (_summary != null)
                _ReferralCodeCard(summary: _summary!, onCopy: _copyCode),
              const SizedBox(height: 14),
              if (_summary != null) _SummaryGrid(summary: _summary!),
              const SizedBox(height: 18),
              _SearchCard(
                controller: _searchController,
                onSearch: _load,
                onClear: _clearSearch,
              ),
              const SizedBox(height: 14),
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
                  _ReferralCustomerCard(
                    customer: item,
                    onTap: () => _openDetail(item),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _ReferralCodeCard extends StatelessWidget {
  const _ReferralCodeCard({required this.summary, required this.onCopy});

  final ReferralSummary summary;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your referral code',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  summary.code.isEmpty ? 'Not available' : summary.code,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Copy referral code',
                onPressed: summary.code.isEmpty ? null : onCopy,
                icon: const Icon(Icons.copy_rounded),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            summary.isActive
                ? 'Share this code with customers during signup.'
                : 'This referral code is currently inactive.',
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

class _SummaryGrid extends StatelessWidget {
  const _SummaryGrid({required this.summary});

  final ReferralSummary summary;

  @override
  Widget build(BuildContext context) {
    final metrics = [
      ('Referrals', summary.totalReferrals),
      ('Active', summary.activeReferrals),
      ('Services', summary.totalServices),
      ('By customer', summary.selfCreatedServices),
      ('By you', summary.referrerCreatedServices),
      ('Consented', summary.consentedReferrals),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: metrics.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.25,
      ),
      itemBuilder: (context, index) {
        final metric = metrics[index];
        return PremiumCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${metric.$2}',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                metric.$1,
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
      },
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
  const _ReferralCustomerCard({required this.customer, required this.onTap});

  final ReferralCustomer customer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
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
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        _CountChip('Services', customer.totalServices),
                        _CountChip('Customer', customer.selfCreatedServices),
                        _CountChip('By you', customer.referrerCreatedServices),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
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

class _CountChip extends StatelessWidget {
  const _CountChip(this.label, this.value);

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD0D5DD)),
      ),
      child: Text(
        '$label $value',
        style: const TextStyle(
          color: Color(0xFF475467),
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
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
