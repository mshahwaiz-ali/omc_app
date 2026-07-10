import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_empty_state.dart';
import '../../../core/widgets/premium_info_chip.dart';
import '../../../core/widgets/premium_list_header.dart';
import '../../support/application/support_launcher.dart';
import '../data/service_case.dart';
import '../data/service_case_repository.dart';

class InternalServiceTrackScreen extends ConsumerStatefulWidget {
  const InternalServiceTrackScreen({super.key});

  @override
  ConsumerState<InternalServiceTrackScreen> createState() => _InternalServiceTrackScreenState();
}

class _InternalServiceTrackScreenState extends ConsumerState<InternalServiceTrackScreen> {
  _InternalCaseFilter _selectedFilter = _InternalCaseFilter.active;
  String? _selectedCustomerKey;

  @override
  Widget build(BuildContext context) {
    final casesAsync = ref.watch(serviceCasesProvider);

    return Scaffold(
      body: SafeArea(
        child: casesAsync.when(
          loading: () => const _TrackLoadingView(),
          error: (error, _) => PremiumEmptyState(
            icon: Icons.cloud_off_rounded,
            title: 'Track queue unavailable',
            message: _cleanError(error),
            actionLabel: 'Retry',
            onAction: () => ref.invalidate(serviceCasesProvider),
          ),
          data: (cases) {
            final visibleCases = cases.where(_selectedFilter.matches).toList(growable: false);
            final groups = _CustomerCaseGroup.fromCases(visibleCases);
            final selectedGroup = _selectedGroup(groups, _selectedCustomerKey);

            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(serviceCasesProvider),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                children: [
                  PremiumListHeader(
                    icon: Icons.track_changes_rounded,
                    title: 'Track',
                    subtitle: 'Select a customer first, then view only that customer\'s service requests.',
                    metaLabel: '${visibleCases.length} shown',
                  ),
                  const SizedBox(height: 16),
                  _TopStats(cases: cases),
                  const SizedBox(height: 12),
                  _InternalCaseFilterBar(
                    cases: cases,
                    selectedFilter: _selectedFilter,
                    onSelected: (filter) => setState(() {
                      _selectedFilter = filter;
                      _selectedCustomerKey = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  if (groups.isEmpty)
                    const PremiumEmptyState(
                      icon: Icons.assignment_outlined,
                      title: 'No service requests',
                      message: 'No matching service requests were found in this queue.',
                    )
                  else ...[
                    _CustomerSelectorCard(
                      groups: groups,
                      selectedKey: selectedGroup.key,
                      onSelected: (key) => setState(() => _selectedCustomerKey = key),
                    ),
                    const SizedBox(height: 12),
                    _CustomerSummaryCard(group: selectedGroup),
                    const SizedBox(height: 12),
                    const PremiumListHeader(
                      icon: Icons.assignment_outlined,
                      title: 'Service Requests',
                      subtitle: 'Open the selected customer\'s cases below.',
                    ),
                    const SizedBox(height: 12),
                    for (final serviceCase in selectedGroup.cases) ...[
                      _InternalServiceCaseCard(serviceCase: serviceCase),
                      const SizedBox(height: 12),
                    ],
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  _CustomerCaseGroup _selectedGroup(List<_CustomerCaseGroup> groups, String? selectedKey) {
    if (groups.isEmpty) return _CustomerCaseGroup.empty();
    for (final group in groups) {
      if (group.key == selectedKey) return group;
    }
    return groups.first;
  }
}

class _InternalCaseFilter {
  const _InternalCaseFilter._(this.label, this.icon);

  static const active = _InternalCaseFilter._('Active', Icons.timeline_rounded);
  static const open = _InternalCaseFilter._('Open', Icons.pending_actions_rounded);
  static const inReview = _InternalCaseFilter._('In Review', Icons.fact_check_outlined);
  static const inProgress = _InternalCaseFilter._('In Progress', Icons.sync_rounded);
  static const closed = _InternalCaseFilter._('Closed', Icons.check_circle_rounded);
  static const cancelled = _InternalCaseFilter._('Cancelled', Icons.cancel_rounded);
  static const all = _InternalCaseFilter._('All', Icons.format_list_bulleted_rounded);

  final String label;
  final IconData icon;

  static const values = <_InternalCaseFilter>[active, open, inReview, inProgress, closed, cancelled, all];

  bool matches(ServiceCase serviceCase) {
    final status = serviceCase.status.trim().toLowerCase();
    switch (this) {
      case active:
        return !_isDone(serviceCase) && !_isCancelled(serviceCase);
      case open:
        return !_isDone(serviceCase) &&
            !_isCancelled(serviceCase) &&
            (status.contains('open') || status.contains('new') || status.contains('submitted') || status.contains('pending') || status.isEmpty);
      case inReview:
        return !_isDone(serviceCase) &&
            !_isCancelled(serviceCase) &&
            (status.contains('review') || status.contains('document') || status.contains('verification'));
      case inProgress:
        return !_isDone(serviceCase) &&
            !_isCancelled(serviceCase) &&
            (status.contains('progress') || status.contains('processing') || status.contains('working'));
      case closed:
        return _isDone(serviceCase);
      case cancelled:
        return _isCancelled(serviceCase);
      case all:
        return true;
    }
  }

  int count(List<ServiceCase> cases) => cases.where(matches).length;
}

class _InternalCaseFilterBar extends StatelessWidget {
  const _InternalCaseFilterBar({
    required this.cases,
    required this.selectedFilter,
    required this.onSelected,
  });

  final List<ServiceCase> cases;
  final _InternalCaseFilter selectedFilter;
  final ValueChanged<_InternalCaseFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: _InternalCaseFilter.values.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = _InternalCaseFilter.values[index];
          final selected = filter == selectedFilter;
          final color = _filterColor(filter);
          final count = filter.count(cases);

          return InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: () => onSelected(filter),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: selected ? color.withValues(alpha: 0.12) : Colors.white,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: selected ? color.withValues(alpha: 0.28) : Colors.black.withValues(alpha: 0.08)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(filter.icon, size: 14.5, color: selected ? color : AppTheme.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    filter.label,
                    style: TextStyle(
                      color: selected ? color : AppTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: selected ? 0.14 : 0.07),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        color: selected ? color : AppTheme.textSecondary,
                        fontSize: 10.5,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TopStats extends StatelessWidget {
  const _TopStats({required this.cases});

  final List<ServiceCase> cases;

  @override
  Widget build(BuildContext context) {
    final active = _InternalCaseFilter.active.count(cases);
    final action = cases.where((item) => _stateFor(item).needsAction).length;
    final closed = _InternalCaseFilter.closed.count(cases);

    return Row(
      children: [
        Expanded(child: _StatTile(value: '$active', label: 'Active')),
        const SizedBox(width: 8),
        Expanded(child: _StatTile(value: '$action', label: 'Action')),
        const SizedBox(width: 8),
        Expanded(child: _StatTile(value: '$closed', label: 'Closed')),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(
        color: AppTheme.primaryRed.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              height: 1.05,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10.5,
              height: 1.15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerSelectorCard extends StatelessWidget {
  const _CustomerSelectorCard({
    required this.groups,
    required this.selectedKey,
    required this.onSelected,
  });

  final List<_CustomerCaseGroup> groups;
  final String selectedKey;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Customer',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: groups.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final group = groups[index];
                final selected = group.key == selectedKey;
                return ChoiceChip(
                  selected: selected,
                  label: Text(group.customerName),
                  onSelected: (_) => onSelected(group.key),
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                  selectedColor: AppTheme.primaryRed,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: selected ? AppTheme.primaryRed : Colors.black.withValues(alpha: 0.08),
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerSummaryCard extends StatelessWidget {
  const _CustomerSummaryCard({required this.group});

  final _CustomerCaseGroup group;

  @override
  Widget build(BuildContext context) {
    final counts = group.counts;

    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.customerName,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${group.cases.length} service request(s)',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _SummaryChip(label: 'Active', value: '${counts.active}')),
              const SizedBox(width: 8),
              Expanded(child: _SummaryChip(label: 'Action', value: '${counts.actionNeeded}')),
              const SizedBox(width: 8),
              Expanded(child: _SummaryChip(label: 'Closed', value: '${counts.closed}')),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InternalServiceCaseCard extends StatelessWidget {
  const _InternalServiceCaseCard({required this.serviceCase});

  final ServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    final state = _stateFor(serviceCase);
    final palette = _paletteFor(state);
    final progressPercent = serviceCase.progressPercent ?? (serviceCase.progress.clamp(0, 1) * 100).round();

    return PremiumCard(
      onTap: () => context.go('/my-services/${serviceCase.id}'),
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StatusIcon(status: serviceCase.status),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      serviceCase.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        height: 1.25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        PremiumInfoChip(icon: Icons.category_outlined, label: serviceCase.category),
                        ServiceCaseStatusBadge(status: serviceCase.status),
                        if (serviceCase.reference != null && serviceCase.reference!.trim().isNotEmpty)
                          PremiumInfoChip(icon: Icons.confirmation_number_outlined, label: serviceCase.reference!),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Open case',
                onPressed: () => context.go('/my-services/${serviceCase.id}'),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.color.withValues(alpha: 0.035),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: serviceCase.progress.clamp(0, 1),
                      minHeight: 8,
                      backgroundColor: palette.color.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(palette.color),
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Text(
                  '$progressPercent%',
                  style: TextStyle(
                    color: palette.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _CompactDetails(serviceCase: serviceCase),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/my-services/${serviceCase.id}'),
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('View details'),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                tooltip: 'Ask support',
                onPressed: () => SupportLauncher.openWhatsApp(context),
                icon: const Icon(Icons.chat_bubble_outline_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ServiceCaseStatusBadge extends StatelessWidget {
  const ServiceCaseStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final palette = _statusPalette(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: palette.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: palette.color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(
            palette.label,
            style: TextStyle(
              color: palette.color,
              fontSize: 11.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactDetails extends StatelessWidget {
  const _CompactDetails({required this.serviceCase});

  final ServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    final items = <_DetailItem>[
      if (serviceCase.nextStep != null && serviceCase.nextStep!.trim().isNotEmpty)
        _DetailItem(Icons.flag_outlined, 'Next', serviceCase.nextStep!),
      _DetailItem(Icons.description_outlined, 'Docs', serviceCase.documentSummaryLabel),
      _DetailItem(Icons.payments_outlined, 'Payment', serviceCase.paymentSummaryLabel),
      _DetailItem(Icons.update_rounded, 'Updated', serviceCase.updatedAtLabel),
    ];

    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: _DetailRow(item: item),
          ),
      ],
    );
  }
}

class _DetailItem {
  const _DetailItem(this.icon, this.label, this.value);
  final IconData icon;
  final String label;
  final String value;
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.item});

  final _DetailItem item;

  @override
  Widget build(BuildContext context) {
    if (item.value.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primaryRed.withValues(alpha: 0.030),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, color: AppTheme.primaryRed, size: 16),
          const SizedBox(width: 8),
          Text(
            '${item.label}: ',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 12.5,
              height: 1.32,
              fontWeight: FontWeight.w900,
            ),
          ),
          Expanded(
            child: Text(
              item.value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12.5,
                height: 1.32,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final palette = _statusPalette(status);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: palette.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: palette.color.withValues(alpha: 0.08)),
      ),
      child: Icon(palette.icon, color: palette.color, size: 22),
    );
  }
}

class _TrackLoadingView extends StatelessWidget {
  const _TrackLoadingView();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        _LoadingBlock(width: 150, height: 18, radius: 999, color: color),
        const SizedBox(height: 10),
        _LoadingBlock(width: double.infinity, height: 124, radius: 22, color: color),
        const SizedBox(height: 12),
        _LoadingBlock(width: double.infinity, height: 46, radius: 999, color: color),
        const SizedBox(height: 12),
        _LoadingBlock(width: double.infinity, height: 146, radius: 22, color: color),
      ],
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock({
    required this.width,
    required this.height,
    required this.radius,
    required this.color,
  });

  final double width;
  final double height;
  final double radius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _CustomerCaseGroup {
  const _CustomerCaseGroup({
    required this.key,
    required this.customerName,
    required this.cases,
  });

  factory _CustomerCaseGroup.empty() => const _CustomerCaseGroup(
        key: '-',
        customerName: 'Customer',
        cases: <ServiceCase>[],
      );

  factory _CustomerCaseGroup.fromCases(List<ServiceCase> cases) {
    final grouped = <String, List<ServiceCase>>{};
    for (final serviceCase in cases) {
      final key = _groupKey(serviceCase);
      grouped.putIfAbsent(key, () => <ServiceCase>[]).add(serviceCase);
    }

    return grouped.entries
        .map(
          (entry) => _CustomerCaseGroup(
            key: entry.key,
            customerName: _customerNameFromGroup(entry.value.first),
            cases: entry.value,
          ),
        )
        .toList(growable: false)
        .sortedByCustomerName();
  }

  final String key;
  final String customerName;
  final List<ServiceCase> cases;

  _Counts get counts {
    var active = 0;
    var actionNeeded = 0;
    var closed = 0;
    for (final serviceCase in cases) {
      final state = _stateFor(serviceCase);
      if (state.isClosed) {
        closed += 1;
      } else if (state.needsAction) {
        actionNeeded += 1;
      } else {
        active += 1;
      }
    }
    return _Counts(active: active, actionNeeded: actionNeeded, closed: closed);
  }
}

class _Counts {
  const _Counts({
    required this.active,
    required this.actionNeeded,
    required this.closed,
  });

  final int active;
  final int actionNeeded;
  final int closed;
}

class _StatusPalette {
  const _StatusPalette({
    required this.label,
    required this.color,
    required this.icon,
  });

  final String label;
  final Color color;
  final IconData icon;
}

_StatusPalette _statusPalette(String status) {
  final normalized = status.trim().toLowerCase();

  if (normalized.contains('cancel') || normalized.contains('reject') || normalized.contains('declin')) {
    return const _StatusPalette(label: 'Cancelled', color: Color(0xFFEF4444), icon: Icons.cancel_rounded);
  }
  if (normalized.contains('complete') || normalized.contains('closed') || normalized.contains('done') || normalized.contains('resolved')) {
    return const _StatusPalette(label: 'Completed', color: Color(0xFF16A34A), icon: Icons.check_circle_rounded);
  }
  if (normalized.contains('review') || normalized.contains('document')) {
    return const _StatusPalette(label: 'In Review', color: Color(0xFF14B8A6), icon: Icons.fact_check_outlined);
  }
  if (normalized.contains('progress') || normalized.contains('processing') || normalized.contains('working')) {
    return const _StatusPalette(label: 'In Progress', color: Color(0xFF2563EB), icon: Icons.sync_rounded);
  }
  if (normalized.contains('open') || normalized.contains('new') || normalized.contains('submitted') || normalized.contains('pending')) {
    return const _StatusPalette(label: 'Open', color: Color(0xFFF59E0B), icon: Icons.pending_actions_rounded);
  }

  return const _StatusPalette(label: 'Active', color: AppTheme.primaryRed, icon: Icons.timeline_rounded);
}

_ServiceCaseState _stateFor(ServiceCase serviceCase) {
  final status = serviceCase.status.trim().toLowerCase();
  final nextStep = serviceCase.nextStep?.trim().toLowerCase() ?? '';

  final isBlocked = status.contains('cancel') ||
      status.contains('reject') ||
      status.contains('declin') ||
      status.contains('blocked');

  final isClosed = !isBlocked &&
      (status.contains('complete') ||
          status.contains('closed') ||
          status.contains('done') ||
          status.contains('resolved'));

  final needsAction = !isBlocked &&
      !isClosed &&
      (serviceCase.customerActionRequired ||
          serviceCase.missingDocuments.isNotEmpty ||
          (serviceCase.missingDocumentsCount ?? 0) > 0 ||
          serviceCase.rejectedDocumentTotal > 0 ||
          serviceCase.rejectedPaymentTotal > 0 ||
          serviceCase.paymentDetails.any((payment) => payment.needsCustomerAction) ||
          status.contains('waiting for document') ||
          status.contains('waiting for payment') ||
          status.contains('waiting for customer') ||
          status.contains('action required') ||
          nextStep.contains('upload') ||
          nextStep.contains('pay') ||
          nextStep.contains('submit'));

  final isUnderReview = !isBlocked &&
      !isClosed &&
      !needsAction &&
      (status.contains('review') ||
          status.contains('processing') ||
          status.contains('pending') ||
          status.contains('documents under review') ||
          status.contains('payment under review'));

  final isOpen = !isBlocked && !isClosed && !needsAction && !isUnderReview;

  return _ServiceCaseState(
    isBlocked: isBlocked,
    isClosed: isClosed,
    needsAction: needsAction,
    isUnderReview: isUnderReview,
    isOpen: isOpen,
  );
}

class _ServiceCaseState {
  const _ServiceCaseState({
    required this.isBlocked,
    required this.isClosed,
    required this.needsAction,
    required this.isUnderReview,
    required this.isOpen,
  });

  final bool isBlocked;
  final bool isClosed;
  final bool needsAction;
  final bool isUnderReview;
  final bool isOpen;
}

String _cleanError(Object error) {
  if (error is ApiError && error.message.trim().isNotEmpty) {
    return error.message.trim();
  }
  final text = error.toString().replaceFirst('ApiError:', '').trim();
  return text.isEmpty ? 'Could not load service requests from the backend right now.' : text;
}

String _groupKey(ServiceCase serviceCase) {
  final company = serviceCase.companyName?.trim();
  if (company != null && company.isNotEmpty) return company.toLowerCase();

  final name = serviceCase.customerName?.trim();
  if (name != null && name.isNotEmpty) return name.toLowerCase();

  final profile = serviceCase.customerProfile?.trim();
  if (profile != null && profile.isNotEmpty) return profile.toLowerCase();

  final fallback = serviceCase.displayReference;
  return fallback.toLowerCase();
}

String _customerNameFromGroup(ServiceCase serviceCase) {
  final company = serviceCase.companyName?.trim();
  if (company != null && company.isNotEmpty) return company;

  final name = serviceCase.customerName?.trim();
  if (name != null && name.isNotEmpty) return name;

  final profile = serviceCase.customerProfile?.trim();
  if (profile != null && profile.isNotEmpty) return profile;

  return serviceCase.displayReference;
}

_Palette _paletteFor(_ServiceCaseState state) {
  if (state.isBlocked) {
    return const _Palette(label: 'Blocked', color: Color(0xFFEF4444), icon: Icons.block_rounded);
  }
  if (state.isClosed) {
    return const _Palette(label: 'Completed', color: Color(0xFF16A34A), icon: Icons.check_circle_rounded);
  }
  if (state.needsAction) {
    return const _Palette(label: 'Action needed', color: Color(0xFFF59E0B), icon: Icons.priority_high_rounded);
  }
  if (state.isUnderReview) {
    return const _Palette(label: 'Under review', color: Color(0xFF14B8A6), icon: Icons.visibility_rounded);
  }
  return const _Palette(label: 'Open', color: Color(0xFF2563EB), icon: Icons.radio_button_checked_rounded);
}

bool _isDone(ServiceCase serviceCase) => _stateFor(serviceCase).isClosed;
bool _isCancelled(ServiceCase serviceCase) => _stateFor(serviceCase).isBlocked;

List<_CustomerCaseGroup> _sortedByCustomerName(List<_CustomerCaseGroup> groups) {
  final sorted = groups.toList(growable: false);
  sorted.sort((a, b) => a.customerName.toLowerCase().compareTo(b.customerName.toLowerCase()));
  return sorted;
}

extension on List<_CustomerCaseGroup> {
  List<_CustomerCaseGroup> sortedByCustomerName() => _sortedByCustomerName(this);
}

class _Style {
  const _Style({required this.color});
  final Color color;
}

_Style _filterStyle(_InternalCaseFilter filter) {
  switch (filter) {
    case _InternalCaseFilter.active:
      return const _Style(color: AppTheme.primaryRed);
    case _InternalCaseFilter.open:
      return const _Style(color: Color(0xFF2563EB));
    case _InternalCaseFilter.inReview:
      return const _Style(color: Color(0xFF14B8A6));
    case _InternalCaseFilter.inProgress:
      return const _Style(color: Color(0xFFF59E0B));
    case _InternalCaseFilter.closed:
      return const _Style(color: Color(0xFF16A34A));
    case _InternalCaseFilter.cancelled:
      return const _Style(color: Color(0xFFEF4444));
    case _InternalCaseFilter.all:
      return const _Style(color: AppTheme.primaryRed);
  }
}
