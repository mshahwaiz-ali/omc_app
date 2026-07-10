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

  @override
  Widget build(BuildContext context) {
    final casesAsync = ref.watch(serviceCasesProvider);

    return Scaffold(
      body: SafeArea(
        child: casesAsync.when(
          loading: () => const _LoadingState(),
          error: (error, _) => _ErrorState(
            message: _cleanError(error),
            onRetry: () => ref.invalidate(serviceCasesProvider),
            onStartRequest: () => context.go('/services'),
          ),
          data: (cases) {
            final visibleCases = cases.where(_selectedFilter.matches).toList(growable: false);

            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(serviceCasesProvider),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
                children: [
                  const PremiumListHeader(
                    icon: Icons.track_changes_rounded,
                    title: 'Track',
                    subtitle: 'Follow active services, documents, payments and completion status.',
                  ),
                  const SizedBox(height: 16),
                  _TopStats(cases: cases),
                  const SizedBox(height: 12),
                  _InternalCaseFilterBar(
                    cases: cases,
                    selectedFilter: _selectedFilter,
                    onSelected: (filter) => setState(() => _selectedFilter = filter),
                  ),
                  const SizedBox(height: 12),
                  if (visibleCases.isEmpty)
                    _EmptyFilterCard(filter: _selectedFilter)
                  else ...[
                    for (var i = 0; i < visibleCases.length; i++) ...[
                      _InternalServiceCaseCard(serviceCase: visibleCases[i]),
                      if (i != visibleCases.length - 1) const SizedBox(height: 12),
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
}

enum _InternalCaseFilter {
  active('Active', Icons.timeline_rounded),
  open('Open', Icons.pending_actions_rounded),
  inReview('In Review', Icons.fact_check_outlined),
  inProgress('In Progress', Icons.sync_rounded),
  closed('Closed', Icons.check_circle_rounded),
  cancelled('Cancelled', Icons.cancel_rounded),
  all('All', Icons.format_list_bulleted_rounded);

  const _InternalCaseFilter(this.label, this.icon);

  final String label;
  final IconData icon;

  bool matches(ServiceCase serviceCase) {
    final state = _stateFor(serviceCase);

    switch (this) {
      case _InternalCaseFilter.active:
        return !state.isDone && !state.isCancelled;
      case _InternalCaseFilter.open:
        return !state.isDone && !state.isCancelled && state.isOpen;
      case _InternalCaseFilter.inReview:
        return !state.isDone && !state.isCancelled && state.isInReview;
      case _InternalCaseFilter.inProgress:
        return !state.isDone && !state.isCancelled && state.isInProgress;
      case _InternalCaseFilter.closed:
        return state.isDone;
      case _InternalCaseFilter.cancelled:
        return state.isCancelled;
      case _InternalCaseFilter.all:
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
                border: Border.all(
                  color: selected ? color.withValues(alpha: 0.28) : Colors.black.withValues(alpha: 0.08),
                ),
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
              _StatusIcon(palette: palette),
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
                        _StatusBadge(label: palette.label, color: palette.color),
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

class _StatusIcon extends StatelessWidget {
  const _StatusIcon({required this.palette});

  final _StatusPalette palette;

  @override
  Widget build(BuildContext context) {
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
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

class _EmptyFilterCard extends StatelessWidget {
  const _EmptyFilterCard({required this.filter});

  final _InternalCaseFilter filter;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _EmptyIcon(icon: filter.icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No ${filter.label.toLowerCase()} service requests',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Change the filter or refresh the queue.',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12.5,
                    height: 1.35,
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

class _EmptyIcon extends StatelessWidget {
  const _EmptyIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: AppTheme.primaryRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: AppTheme.primaryRed),
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

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

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
    required this.onStartRequest,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onStartRequest;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: PremiumCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 42, color: AppTheme.primaryRed),
              const SizedBox(height: 12),
              const Text(
                'Track queue unavailable',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onRetry,
                      child: const Text('Retry'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: onStartRequest,
                      child: const Text('Start request'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _cleanError(Object error) {
  if (error is ApiError && error.message.trim().isNotEmpty) {
    return error.message.trim();
  }
  final text = error.toString().replaceFirst('ApiError:', '').trim();
  return text.isEmpty ? 'Could not load service requests from the backend right now.' : text;
}

bool _isCancelled(ServiceCase serviceCase) {
  final status = serviceCase.status.trim().toLowerCase();
  return status.contains('cancel') || status.contains('reject') || status.contains('declin') || status.contains('blocked');
}

bool _isDone(ServiceCase serviceCase) {
  final status = serviceCase.status.trim().toLowerCase();
  return _isCancelled(serviceCase) || status.contains('complete') || status.contains('closed') || status.contains('done') || status.contains('resolved');
}

_ServiceCaseState _stateFor(ServiceCase serviceCase) {
  final status = serviceCase.status.trim().toLowerCase();
  final nextStep = serviceCase.nextStep?.trim().toLowerCase() ?? '';

  final isCancelled = _isCancelled(serviceCase);
  final isDone = _isDone(serviceCase);

  final needsAction = !isCancelled &&
      !isDone &&
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

  final isInReview = !isCancelled && !isDone && !needsAction && (status.contains('review') || status.contains('document') || status.contains('verification'));
  final isInProgress = !isCancelled && !isDone && !needsAction && !isInReview && (status.contains('progress') || status.contains('processing') || status.contains('working'));
  final isOpen = !isCancelled && !isDone && !needsAction && !isInReview && !isInProgress;

  return _ServiceCaseState(
    isCancelled: isCancelled,
    isDone: isDone,
    needsAction: needsAction,
    isInReview: isInReview,
    isInProgress: isInProgress,
    isOpen: isOpen,
  );
}

class _ServiceCaseState {
  const _ServiceCaseState({
    required this.isCancelled,
    required this.isDone,
    required this.needsAction,
    required this.isInReview,
    required this.isInProgress,
    required this.isOpen,
  });

  final bool isCancelled;
  final bool isDone;
  final bool needsAction;
  final bool isInReview;
  final bool isInProgress;
  final bool isOpen;
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

_StatusPalette _paletteFor(_ServiceCaseState state) {
  if (state.isCancelled) {
    return const _StatusPalette(label: 'Cancelled', color: Color(0xFFEF4444), icon: Icons.cancel_rounded);
  }
  if (state.isDone) {
    return const _StatusPalette(label: 'Completed', color: Color(0xFF16A34A), icon: Icons.check_circle_rounded);
  }
  if (state.needsAction) {
    return const _StatusPalette(label: 'Action needed', color: Color(0xFFF59E0B), icon: Icons.priority_high_rounded);
  }
  if (state.isInReview) {
    return const _StatusPalette(label: 'In Review', color: Color(0xFF14B8A6), icon: Icons.fact_check_outlined);
  }
  if (state.isInProgress) {
    return const _StatusPalette(label: 'In Progress', color: Color(0xFF2563EB), icon: Icons.sync_rounded);
  }
  return const _StatusPalette(label: 'Open', color: AppTheme.primaryRed, icon: Icons.timeline_rounded);
}

Color _filterColor(_InternalCaseFilter filter) {
  switch (filter) {
    case _InternalCaseFilter.active:
      return AppTheme.primaryRed;
    case _InternalCaseFilter.open:
      return const Color(0xFF2563EB);
    case _InternalCaseFilter.inReview:
      return const Color(0xFF14B8A6);
    case _InternalCaseFilter.inProgress:
      return const Color(0xFFF59E0B);
    case _InternalCaseFilter.closed:
      return const Color(0xFF16A34A);
    case _InternalCaseFilter.cancelled:
      return const Color(0xFFEF4444);
    case _InternalCaseFilter.all:
      return AppTheme.primaryRed;
  }
}
