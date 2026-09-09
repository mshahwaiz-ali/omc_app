import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
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
      backgroundColor: AppTheme.background,
      appBar: AppBackHeader(title: widget.customerName),
      body: RefreshIndicator.adaptive(
        onRefresh: _load,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final inset = AppLayout.pageInsetFor(constraints.maxWidth);
            final horizontal =
                constraints.maxWidth > AppLayout.generalMaxWidth + inset * 2
                ? (constraints.maxWidth - AppLayout.generalMaxWidth) / 2
                : inset;
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 100),
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
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildContent(ReferralDetail detail) {
    final customer = detail.customer;
    return [
      _CustomerAccessCard(
        customer: customer,
        onStartService: customer.consentGranted
            ? () {
                final path =
                    '/services'
                    '?assisted=1'
                    '&customer_profile=${Uri.encodeQueryComponent(widget.customerProfile)}'
                    '&customer_name=${Uri.encodeQueryComponent(customer.displayName)}';
                context.push(path);
              }
            : null,
      ),
      const SizedBox(height: AppSpacing.xl),
      Text('Service activity', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: AppSpacing.sm),
      if (detail.services.isEmpty && detail.requests.isEmpty)
        const EmptyState(
          title: 'No service activity',
          message: 'This referral has not started a service request yet.',
          icon: Icons.design_services_outlined,
        )
      else ...[
        if (detail.services.isNotEmpty) ...[
          Text(
            'Services taken',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var index = 0; index < detail.services.length; index++) ...[
            _ServiceCard(service: detail.services[index]),
            if (index != detail.services.length - 1)
              const SizedBox(height: AppSpacing.sm),
          ],
        ],
        if (detail.requests.isNotEmpty) ...[
          if (detail.services.isNotEmpty) const SizedBox(height: AppSpacing.xl),
          Text(
            'Request history',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          for (var index = 0; index < detail.requests.length; index++) ...[
            _RequestCard(
              request: detail.requests[index],
              customerName: customer.displayName,
            ),
            if (index != detail.requests.length - 1)
              const SizedBox(height: AppSpacing.sm),
          ],
        ],
      ],
      const SizedBox(height: AppSpacing.xl),
      _SummaryCard(detail: detail),
    ];
  }
}

class _CustomerAccessCard extends StatelessWidget {
  const _CustomerAccessCard({
    required this.customer,
    required this.onStartService,
  });

  final ReferralDetailCustomer customer;
  final VoidCallback? onStartService;

  @override
  Widget build(BuildContext context) {
    final contact = [
      customer.phone,
      customer.email,
    ].where((value) => value.isNotEmpty).join(' • ');
    final consentColor = customer.consentGranted
        ? AppTheme.success
        : AppTheme.processing;
    final consentBackground = customer.consentGranted
        ? AppTheme.successSoft
        : AppTheme.processingSoft;

    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppTheme.processingSoft,
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
                    if (contact.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        contact,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Customer account',
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              if (customer.customerStatus.trim().isNotEmpty)
                _StateBadge(
                  label: customer.customerStatus,
                  color: AppTheme.processing,
                  background: AppTheme.processingSoft,
                ),
              if (customer.approvalStatus.trim().isNotEmpty)
                _StateBadge(
                  label: customer.approvalStatus,
                  color: AppTheme.processing,
                  background: AppTheme.processingSoft,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: consentBackground,
              borderRadius: BorderRadius.circular(AppRadius.control),
              border: Border.all(color: consentColor.withValues(alpha: 0.24)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  customer.consentGranted
                      ? Icons.check_circle_outline_rounded
                      : Icons.info_outline_rounded,
                  color: consentColor,
                  size: 20,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customer.consentGranted
                            ? 'Assistance consent granted'
                            : 'Assistance consent not granted',
                        style: Theme.of(
                          context,
                        ).textTheme.labelMedium?.copyWith(color: consentColor),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        customer.consentGranted
                            ? 'You can start an assisted service for this referral.'
                            : 'Assisted service creation remains unavailable without referral assistance consent.',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: consentColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (onStartService != null) ...[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onStartService,
                icon: const Icon(Icons.add_business_outlined),
                label: const Text('Start service for this customer'),
              ),
            ),
          ],
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
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            service.title.isEmpty ? service.service : service.title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          _CountRows(
            rows: [
              ('Total requests', service.total),
              ('Customer created', service.selfCreated),
              ('Started by you', service.referrerCreated),
            ],
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.request, required this.customerName});

  final ReferralRequestSummary request;
  final String customerName;

  @override
  Widget build(BuildContext context) {
    final source = request.createdByReferrer
        ? 'Created by you'
        : 'Customer created';
    final path =
        '/my-services/${Uri.encodeComponent(request.id)}'
        '?assisted=1'
        '&customer_name=${Uri.encodeQueryComponent(customerName)}';

    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: request.id.trim().isEmpty ? null : () => context.push(path),
      semanticLabel:
          '${request.title.isEmpty ? request.id : request.title}. ${request.status}. $source. Open assisted request detail.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            request.title.isEmpty ? request.id : request.title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          _StateBadge(
            label: request.status,
            color: AppTheme.processing,
            background: AppTheme.processingSoft,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            source,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.detail});

  final ReferralDetail detail;

  @override
  Widget build(BuildContext context) {
    final summary = <(String, int)>[
      ('Total services', detail.counts.total),
      ('Customer created', detail.counts.selfCreated),
      ('Started by you', detail.counts.referrerCreated),
    ];

    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Summary', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          _CountRows(rows: summary),
          if (detail.statusCounts.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Divider(height: 1),
            ),
            Text(
              'Service status',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            _CountRows(
              rows: detail.statusCounts.entries
                  .map((entry) => (entry.key, entry.value))
                  .toList(growable: false),
            ),
          ],
        ],
      ),
    );
  }
}

class _CountRows extends StatelessWidget {
  const _CountRows({required this.rows});

  final List<(String, int)> rows;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.sm,
      children: rows
          .map(
            (row) => ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${row.$2}',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    row.$1,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
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
  final result = parts.map((part) => part[0].toUpperCase()).join();
  return result.isEmpty ? 'OMC' : result;
}
