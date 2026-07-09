import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_info_chip.dart';
import '../../../core/widgets/premium_list_header.dart';
import '../../support/application/support_launcher.dart';
import '../data/service_case.dart';
import '../data/service_case_repository.dart';

class MyServicesScreen extends ConsumerStatefulWidget {
  const MyServicesScreen({super.key});

  static ServiceCase? findCaseById(List<ServiceCase> cases, String caseId) {
    for (final serviceCase in cases) {
      if (serviceCase.id == caseId || serviceCase.reference == caseId) {
        return serviceCase;
      }
    }
    return null;
  }

  @override
  ConsumerState<MyServicesScreen> createState() => _MyServicesScreenState();
}

class _MyServicesScreenState extends ConsumerState<MyServicesScreen> {
  _ServiceCaseFilter _selectedFilter = _ServiceCaseFilter.active;

  @override
  Widget build(BuildContext context) {
    final casesAsync = ref.watch(serviceCasesProvider);

    return Scaffold(
      body: SafeArea(
        top: true,
        child: casesAsync.when(
          loading: () => const _ServiceLoadingView(),
          error: (error, stackTrace) => _LoadErrorState(
            message: _cleanErrorMessage(error),
            onRetry: () => ref.invalidate(serviceCasesProvider),
            onStartRequest: () => context.go('/services'),
          ),
          data: (cases) {
            if (cases.isEmpty) {
              return _EmptyServicesState(onStartRequest: () => context.go('/services'));
            }

            final visibleCases = cases.where(_selectedFilter.matches).toList(growable: false);

            return RefreshIndicator(
              onRefresh: () async => ref.invalidate(serviceCasesProvider),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 112),
                children: [
                  _HeaderCard(cases: cases),
                  const SizedBox(height: 12),
                  _ServiceCaseFilterTabs(
                    cases: cases,
                    selectedFilter: _selectedFilter,
                    onSelected: (filter) => setState(() => _selectedFilter = filter),
                  ),
                  const SizedBox(height: 12),
                  _FilterSummary(filter: _selectedFilter, count: visibleCases.length),
                  const SizedBox(height: 10),
                  if (visibleCases.isEmpty)
                    _EmptyFilterCard(filter: _selectedFilter)
                  else
                    for (final serviceCase in visibleCases)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ServiceCaseCard(serviceCase: serviceCase),
                      ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

enum _ServiceCaseFilter {
  active,
  open,
  needsAction,
  closed,
  cancelled,
  all;

  String get label {
    switch (this) {
      case _ServiceCaseFilter.active:
        return 'Active';
      case _ServiceCaseFilter.open:
        return 'Open';
      case _ServiceCaseFilter.needsAction:
        return 'Needs action';
      case _ServiceCaseFilter.closed:
        return 'Closed';
      case _ServiceCaseFilter.cancelled:
        return 'Cancelled';
      case _ServiceCaseFilter.all:
        return 'All';
    }
  }

  IconData get icon {
    switch (this) {
      case _ServiceCaseFilter.active:
        return Icons.timeline_rounded;
      case _ServiceCaseFilter.open:
        return Icons.pending_actions_rounded;
      case _ServiceCaseFilter.needsAction:
        return Icons.priority_high_rounded;
      case _ServiceCaseFilter.closed:
        return Icons.check_circle_rounded;
      case _ServiceCaseFilter.cancelled:
        return Icons.cancel_rounded;
      case _ServiceCaseFilter.all:
        return Icons.format_list_bulleted_rounded;
    }
  }

  String get emptyTitle {
    switch (this) {
      case _ServiceCaseFilter.active:
        return 'No active service requests';
      case _ServiceCaseFilter.open:
        return 'No open service requests';
      case _ServiceCaseFilter.needsAction:
        return 'No action needed';
      case _ServiceCaseFilter.closed:
        return 'No closed service requests';
      case _ServiceCaseFilter.cancelled:
        return 'No cancelled service requests';
      case _ServiceCaseFilter.all:
        return 'No service requests';
    }
  }

  String get emptyMessage {
    switch (this) {
      case _ServiceCaseFilter.active:
        return 'Live, open and in-progress requests will appear here.';
      case _ServiceCaseFilter.open:
        return 'New, submitted, pending and review-stage requests will appear here.';
      case _ServiceCaseFilter.needsAction:
        return 'Requests needing documents, payment or a customer response will appear here.';
      case _ServiceCaseFilter.closed:
        return 'Completed and closed requests will appear here for history.';
      case _ServiceCaseFilter.cancelled:
        return 'Cancelled or rejected requests will appear here.';
      case _ServiceCaseFilter.all:
        return 'Start a service request from the catalogue to begin tracking.';
    }
  }

  bool matches(ServiceCase serviceCase) {
    final state = _ServiceCaseState.from(serviceCase);
    switch (this) {
      case _ServiceCaseFilter.active:
        return state.isActive;
      case _ServiceCaseFilter.open:
        return state.isOpen;
      case _ServiceCaseFilter.needsAction:
        return state.needsAction;
      case _ServiceCaseFilter.closed:
        return state.isClosed;
      case _ServiceCaseFilter.cancelled:
        return state.isCancelled;
      case _ServiceCaseFilter.all:
        return true;
    }
  }

  int count(List<ServiceCase> cases) => cases.where(matches).length;
}

class _ServiceCaseState {
  const _ServiceCaseState({
    required this.isClosed,
    required this.isCancelled,
    required this.needsAction,
    required this.isOpen,
  });

  final bool isClosed;
  final bool isCancelled;
  final bool needsAction;
  final bool isOpen;

  bool get isActive => !isClosed && !isCancelled;

  static _ServiceCaseState from(ServiceCase serviceCase) {
    final status = serviceCase.status.trim().toLowerCase();
    final nextStep = serviceCase.nextStep?.trim().toLowerCase() ?? '';

    final isCancelled = status.contains('cancel') ||
        status.contains('reject') ||
        status.contains('declined');

    final isClosed = !isCancelled &&
        (status.contains('complete') ||
            status.contains('completed') ||
            status.contains('closed') ||
            status.contains('done') ||
            status.contains('resolved'));

    final needsAction = !isCancelled &&
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

    final isOpen = !isCancelled &&
        !isClosed &&
        (status.contains('open') ||
            status.contains('new') ||
            status.contains('draft') ||
            status.contains('submitted') ||
            status.contains('pending') ||
            status.contains('review') ||
            status.contains('progress') ||
            status.contains('processing') ||
            status.contains('waiting') ||
            status.isEmpty ||
            !needsAction);

    return _ServiceCaseState(
      isClosed: isClosed,
      isCancelled: isCancelled,
      needsAction: needsAction,
      isOpen: isOpen,
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.cases});

  final List<ServiceCase> cases;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PremiumListHeader(
          icon: Icons.track_changes_rounded,
          title: 'Track requests',
          subtitle: 'Follow active services, documents, payments and completion status.',
          metaLabel: '${_ServiceCaseFilter.active.count(cases)} active',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _HeaderStat(value: _ServiceCaseFilter.active.count(cases).toString(), label: 'Active')),
            const SizedBox(width: 8),
            Expanded(child: _HeaderStat(value: _ServiceCaseFilter.needsAction.count(cases).toString(), label: 'Action')),
            const SizedBox(width: 8),
            Expanded(child: _HeaderStat(value: _ServiceCaseFilter.closed.count(cases).toString(), label: 'Closed')),
          ],
        ),
      ],
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({required this.value, required this.label});

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

class _ServiceCaseFilterTabs extends StatelessWidget {
  const _ServiceCaseFilterTabs({
    required this.cases,
    required this.selectedFilter,
    required this.onSelected,
  });

  final List<ServiceCase> cases;
  final _ServiceCaseFilter selectedFilter;
  final ValueChanged<_ServiceCaseFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (final filter in _ServiceCaseFilter.values) ...[
            _ServiceCaseFilterChip(
              filter: filter,
              count: filter.count(cases),
              selected: selectedFilter == filter,
              onTap: () => onSelected(filter),
            ),
            if (filter != _ServiceCaseFilter.values.last) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _ServiceCaseFilterChip extends StatelessWidget {
  const _ServiceCaseFilterChip({
    required this.filter,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final _ServiceCaseFilter filter;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textColor = selected ? AppTheme.primaryRed : AppTheme.textPrimary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primaryRed.withValues(alpha: 0.10) : Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppTheme.primaryRed.withValues(alpha: 0.28) : AppTheme.primaryRed.withValues(alpha: 0.08),
            ),
            boxShadow: selected
                ? [BoxShadow(color: AppTheme.primaryRed.withValues(alpha: 0.07), blurRadius: 14, offset: const Offset(0, 8))]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(filter.icon, size: 14.5, color: textColor),
              const SizedBox(width: 6),
              Text(
                filter.label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.05,
                ),
              ),
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed.withValues(alpha: selected ? 0.13 : 0.055),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(color: textColor, fontSize: 10.5, height: 1, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterSummary extends StatelessWidget {
  const _FilterSummary({required this.filter, required this.count});

  final _ServiceCaseFilter filter;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, right: 2),
      child: Row(
        children: [
          Icon(filter.icon, size: 15, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              '${filter.label} requests',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w900),
            ),
          ),
          Text(
            '$count found',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _ServiceCaseCard extends ConsumerWidget {
  const _ServiceCaseCard({required this.serviceCase});

  final ServiceCase serviceCase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressPercent = serviceCase.progressPercent ?? (serviceCase.progress.clamp(0, 1) * 100).round();
    final state = _ServiceCaseState.from(serviceCase);

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
              const SizedBox(width: 11),
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
                        fontSize: 15.5,
                        height: 1.22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.12,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        PremiumInfoChip(icon: Icons.category_outlined, label: serviceCase.category),
                        ServiceCaseStatusBadge(status: serviceCase.status),
                        if (state.needsAction)
                          const PremiumInfoChip(icon: Icons.priority_high_rounded, label: 'Action required', color: AppTheme.primaryRed),
                        if (serviceCase.reference != null)
                          PremiumInfoChip(icon: Icons.confirmation_number_outlined, label: serviceCase.reference!),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.chevron_right_rounded, color: Colors.grey.shade400),
            ],
          ),
          const SizedBox(height: 13),
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withValues(alpha: 0.035),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value: serviceCase.progress.clamp(0, 1),
                      minHeight: 7,
                      backgroundColor: AppTheme.primaryRed.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Text(
                  '$progressPercent%',
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _CompactDetailGrid(serviceCase: serviceCase),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/my-services/${serviceCase.id}'),
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('View details'),
                ),
              ),
              const SizedBox(width: 9),
              IconButton.filledTonal(
                tooltip: 'Ask support',
                onPressed: () => SupportLauncher.openWhatsApp(context),
                icon: const Icon(Icons.chat_bubble_outline_rounded),
              ),
            ],
          ),
          if (serviceCase.canCancel && state.isActive) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _confirmCancelRequest(context, ref),
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('Cancel request'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryRed,
                  side: BorderSide(color: AppTheme.primaryRed.withValues(alpha: 0.34)),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmCancelRequest(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancel request?'),
        content: Text('This will cancel ${serviceCase.displayReference}. You can still view its history after cancellation.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Keep request')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Cancel request')),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final repository = ref.read(serviceCaseRepositoryProvider);
      await repository.cancelServiceRequest(caseId: serviceCase.id);
      ref.invalidate(serviceCasesProvider);
      ref.invalidate(serviceCaseDetailProvider(serviceCase.id));

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Service request cancelled.')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_cleanErrorMessage(error))));
    }
  }
}

class _CompactDetailGrid extends StatelessWidget {
  const _CompactDetailGrid({required this.serviceCase});

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
            style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12.5, height: 1.32, fontWeight: FontWeight.w900),
          ),
          Expanded(
            child: Text(
              item.value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5, height: 1.32, fontWeight: FontWeight.w600),
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
    final style = serviceCaseStatusStyle(status);
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppTheme.primaryRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.08)),
      ),
      child: Icon(style.icon, color: AppTheme.primaryRed, size: 22),
    );
  }
}

class _EmptyFilterCard extends StatelessWidget {
  const _EmptyFilterCard({required this.filter});

  final _ServiceCaseFilter filter;

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
                  filter.emptyTitle,
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  filter.emptyMessage,
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12.5, height: 1.35, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyServicesState extends StatelessWidget {
  const _EmptyServicesState({required this.onStartRequest});

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
              const _EmptyIcon(icon: Icons.assignment_add),
              const SizedBox(height: 13),
              const Text(
                'No service requests yet',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 7),
              const Text(
                'Start a guided request from the catalogue. Tracking appears here after submission.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.35, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 15),
              FilledButton.icon(onPressed: onStartRequest, icon: const Icon(Icons.add_rounded), label: const Text('Start a request')),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadErrorState extends StatelessWidget {
  const _LoadErrorState({required this.message, required this.onRetry, required this.onStartRequest});

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
              const _EmptyIcon(icon: Icons.cloud_off_rounded),
              const SizedBox(height: 13),
              const Text(
                'Service tracking unavailable',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 7),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.35, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 15),
              Row(
                children: [
                  Expanded(child: FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh_rounded), label: const Text('Retry'))),
                  const SizedBox(width: 9),
                  Expanded(child: OutlinedButton.icon(onPressed: onStartRequest, icon: const Icon(Icons.add_rounded), label: const Text('New request'))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceLoadingView extends StatelessWidget {
  const _ServiceLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 112),
      children: const [
        _LoadingHero(),
        SizedBox(height: 12),
        _ServiceLoadingCard(),
        SizedBox(height: 10),
        _ServiceLoadingCard(),
        SizedBox(height: 10),
        _ServiceLoadingCard(),
      ],
    );
  }
}

class _LoadingHero extends StatelessWidget {
  const _LoadingHero();

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: const [
          _EmptyIcon(icon: Icons.assignment_rounded),
          SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Loading services', style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w900)),
                SizedBox(height: 5),
                Text('Fetching active cases, progress and request history.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12.5, height: 1.35, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceLoadingCard extends StatelessWidget {
  const _ServiceLoadingCard();

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: const [
          _LoadingBlock(width: 44, height: 44, radius: 17),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LoadingBlock(widthFactor: 0.76, height: 10, radius: 99),
                SizedBox(height: 9),
                _LoadingBlock(widthFactor: 0.52, height: 10, radius: 99),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingBlock extends StatelessWidget {
  const _LoadingBlock({this.width, this.widthFactor, required this.height, required this.radius});

  final double? width;
  final double? widthFactor;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final block = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.primaryRed.withValues(alpha: 0.065),
        borderRadius: BorderRadius.circular(radius),
      ),
    );

    if (widthFactor == null) return block;
    return FractionallySizedBox(widthFactor: widthFactor, alignment: Alignment.centerLeft, child: block);
  }
}

class _EmptyIcon extends StatelessWidget {
  const _EmptyIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: AppTheme.primaryRed.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primaryRed.withValues(alpha: 0.08)),
      ),
      child: Icon(icon, color: AppTheme.primaryRed, size: 25),
    );
  }
}

class ServiceCaseStatusBadge extends StatelessWidget {
  const ServiceCaseStatusBadge({super.key, required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final style = serviceCaseStatusStyle(status);
    return PremiumInfoChip(icon: style.icon, label: style.label, color: AppTheme.primaryRed);
  }
}

ServiceCaseStatusStyle serviceCaseStatusStyle(String status) {
  final normalized = status.trim().toLowerCase();
  return ServiceCaseStatusStyle(
    icon: normalized.contains('complete') || normalized.contains('closed') || normalized.contains('done')
        ? Icons.check_circle_rounded
        : normalized.contains('cancel') || normalized.contains('reject')
            ? Icons.cancel_rounded
            : normalized.contains('document')
                ? Icons.description_outlined
                : normalized.contains('payment')
                    ? Icons.payments_outlined
                    : Icons.pending_actions_rounded,
    label: status.trim().isEmpty ? 'Open' : status.trim(),
  );
}

String _cleanErrorMessage(Object error) {
  if (error is ApiError && error.message.trim().isNotEmpty) {
    return error.message.trim();
  }

  final rawMessage = error.toString().replaceFirst('ApiError:', '').trim();
  if (rawMessage.isEmpty) {
    return 'Service tracking is unavailable right now. Submitted requests are still sent to OMC.';
  }
  return rawMessage;
}
