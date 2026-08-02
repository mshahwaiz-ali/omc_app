import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/app_back_header.dart';
import '../../../core/widgets/app_state.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/loading_view.dart';
import '../../../core/widgets/premium_card.dart';
import '../data/referral_detail.dart';
import '../data/referral_repository.dart';

class ReferralDetailScreen extends ConsumerStatefulWidget {
  const ReferralDetailScreen({
    required this.customerProfile,
    required this.customerName,
    super.key,
  });

  final String customerProfile;
  final String customerName;

  @override
  ConsumerState<ReferralDetailScreen> createState() =>
      _ReferralDetailScreenState();
}

class _ReferralDetailScreenState extends ConsumerState<ReferralDetailScreen> {
  ReferralDetail? _detail;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final detail = await ref
          .read(referralRepositoryProvider)
          .fetchReferralDetail(widget.customerProfile);
      if (!mounted) return;
      setState(() => _detail = detail);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBackHeader(title: widget.customerName),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
          children: [
            if (_loading)
              const SizedBox(
                height: 360,
                child: LoadingView(message: 'Loading referral details...'),
              )
            else if (_error != null)
              AppErrorState.fromError(
                error: _error!,
                fallbackTitle: 'Referral details unavailable',
                fallbackMessage:
                    'This referral record could not be loaded right now.',
                onRetry: _load,
              )
            else if (_detail != null)
              ..._buildContent(_detail!),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildContent(ReferralDetail detail) {
    final customer = detail.customer;
    return [
      PremiumCard(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.08),
                  child: Text(
                    _initials(customer.displayName),
                    style: const TextStyle(
                      color: AppTheme.primary,
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
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          customer.phone,
                          customer.email,
                        ].where((value) => value.isNotEmpty).join(' • '),
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
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Chip(label: customer.customerStatus),
                _Chip(label: customer.approvalStatus),
                _Chip(
                  label: customer.consentGranted
                      ? 'Assistance consented'
                      : 'Consent revoked',
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      _MetricGrid(counts: detail.counts),
      const SizedBox(height: 18),
      const _SectionTitle('Service status'),
      const SizedBox(height: 10),
      if (detail.statusCounts.isEmpty)
        const EmptyState(
          title: 'No service activity',
          message:
              'Service status counts will appear after a request is created.',
          icon: Icons.query_stats_outlined,
        )
      else
        PremiumCard(
          padding: const EdgeInsets.all(14),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: detail.statusCounts.entries
                .map((entry) => _CountChip(entry.key, entry.value))
                .toList(growable: false),
          ),
        ),
      const SizedBox(height: 18),
      const _SectionTitle('Services taken'),
      const SizedBox(height: 10),
      if (detail.services.isEmpty)
        const EmptyState(
          title: 'No services yet',
          message: 'This customer has not started a service request yet.',
          icon: Icons.design_services_outlined,
        )
      else
        for (final service in detail.services) ...[
          _ServiceCard(service: service),
          const SizedBox(height: 10),
        ],
      const SizedBox(height: 8),
      const _SectionTitle('Request history'),
      const SizedBox(height: 10),
      if (detail.requests.isEmpty)
        const EmptyState(
          title: 'No requests yet',
          message: 'Request history will appear here.',
          icon: Icons.history_rounded,
        )
      else
        for (final request in detail.requests) ...[
          _RequestCard(request: request),
          const SizedBox(height: 10),
        ],
    ];
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.counts});

  final ReferralServiceCounts counts;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _Metric('Total', counts.total)),
        const SizedBox(width: 10),
        Expanded(child: _Metric('Customer', counts.selfCreated)),
        const SizedBox(width: 10),
        Expanded(child: _Metric('By you', counts.referrerCreated)),
      ],
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
      child: Column(
        children: [
          Text(
            '$value',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({required this.service});

  final ReferralServiceBreakdown service;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            service.title.isEmpty ? service.service : service.title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _CountChip('Total', service.total),
              _CountChip('Customer', service.selfCreated),
              _CountChip('By you', service.referrerCreated),
            ],
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request});

  final ReferralRequestSummary request;

  @override
  Widget build(BuildContext context) {
    final source = request.createdByReferrer
        ? 'Created by you'
        : 'Customer created';
    return PremiumCard(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            color: AppTheme.textSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.title.isEmpty ? request.id : request.title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$source • ${request.status}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11.5,
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppTheme.textPrimary,
        fontSize: 16,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    if (label.trim().isEmpty) return const SizedBox.shrink();
    return Container(
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
}

class _CountChip extends StatelessWidget {
  const _CountChip(this.label, this.value);
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F4F7),
        borderRadius: BorderRadius.circular(999),
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
}

String _initials(String value) {
  final parts = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2);
  final result = parts.map((part) => part[0].toUpperCase()).join();
  return result.isEmpty ? 'OMC' : result;
}
