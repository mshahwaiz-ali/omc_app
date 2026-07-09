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
import 'my_services_screen.dart';


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
    final status = serviceCase.status.trim().toLowerCase();

    switch (this) {
      case _InternalCaseFilter.active:
        return !_isDone(serviceCase) && !_isCancelled(serviceCase);
      case _InternalCaseFilter.open:
        return !_isDone(serviceCase) &&
            !_isCancelled(serviceCase) &&
            (status.contains('open') ||
                status.contains('new') ||
                status.contains('submitted') ||
                status.contains('pending') ||
                status.isEmpty);
      case _InternalCaseFilter.inReview:
        return !_isDone(serviceCase) &&
            !_isCancelled(serviceCase) &&
            (status.contains('review') ||
                status.contains('document') ||
                status.contains('verification'));
      case _InternalCaseFilter.inProgress:
        return !_isDone(serviceCase) &&
            !_isCancelled(serviceCase) &&
            (status.contains('progress') ||
                status.contains('processing') ||
                status.contains('working'));
      case _InternalCaseFilter.closed:
        return _isDone(serviceCase);
      case _InternalCaseFilter.cancelled:
        return _isCancelled(serviceCase);
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
    return PremiumCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            for (final filter in _InternalCaseFilter.values) ...[
              ChoiceChip(
                avatar: Icon(filter.icon, size: 16),
                label: Text('${filter.label} ${filter.count(cases)}'),
                selected: selectedFilter == filter,
                onSelected: (_) => onSelected(filter),
                selectedColor: AppTheme.primaryRed.withValues(alpha: 0.12),
                side: BorderSide(
                  color: selectedFilter == filter
                      ? AppTheme.primaryRed.withValues(alpha: 0.28)
                      : Colors.black.withValues(alpha: 0.08),
                ),
                labelStyle: TextStyle(
                  color: selectedFilter == filter
                      ? AppTheme.primaryRed
                      : AppTheme.textSecondary,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
      ),
    );
  }
}


class InternalServiceTrackScreen extends ConsumerStatefulWidget {
  const InternalServiceTrackScreen({super.key});

  @override
  ConsumerState<InternalServiceTrackScreen> createState() =>
      _InternalServiceTrackScreenState();
}

class _InternalServiceTrackScreenState
    extends ConsumerState<InternalServiceTrackScreen> {
  String? _selectedCustomerKey;
  _InternalCaseFilter _selectedFilter = _InternalCaseFilter.active;

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
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 164),
                children: [
                  PremiumListHeader(
                    icon: Icons.track_changes_rounded,
                    title: 'Track',
                    subtitle:
                        'Select a customer first, then view only that customer’s service requests.',
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
                    PremiumEmptyState(
                      icon: Icons.assignment_outlined,
                      title: 'No service requests',
                      message: 'No ${_selectedFilter.label.toLowerCase()} service requests found in this queue.',
                    )
                  else ...[
                    _CustomerSelectorCard(
                      groups: groups,
                      selectedKey: selectedGroup.key,
                      onSelected: (key) =>
                          setState(() => _selectedCustomerKey = key),
                    ),
                    const SizedBox(height: 12),
                    _CustomerSummaryCard(group: selectedGroup),
                    const SizedBox(height: 12),
                    PremiumListHeader(
                      icon: Icons.assignment_outlined,
                      title: 'Service Requests',
                      subtitle: selectedGroup.customerName,
                      metaLabel: '${selectedGroup.cases.length} shown',
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

  _CustomerCaseGroup _selectedGroup(
    List<_CustomerCaseGroup> groups,
    String? selectedKey,
  ) {
    if (groups.isEmpty) return _CustomerCaseGroup.empty();

    for (final group in groups) {
      if (group.key == selectedKey) return group;
    }

    return groups.first;
  }
}

String _cleanError(Object error) {
  if (error is ApiError && error.message.trim().isNotEmpty) {
    return error.message.trim();
  }
  final text = error.toString().replaceFirst('ApiError:', '').trim();
  return text.isEmpty
      ? 'Could not load service requests from the backend right now.'
      : text;
}

class _CustomerCaseGroup {
  const _CustomerCaseGroup({
    required this.key,
    required this.customerName,
    required this.email,
    required this.phone,
    required this.ntn,
    required this.cnic,
    required this.companyName,
    required this.cases,
  });

  factory _CustomerCaseGroup.empty() {
    return const _CustomerCaseGroup(
      key: '-',
      customerName: 'Customer',
      email: null,
      phone: null,
      ntn: null,
      cnic: null,
      companyName: null,
      cases: <ServiceCase>[],
    );
  }

  final String key;
  final String customerName;
  final String? email;
  final String? phone;
  final String? ntn;
  final String? cnic;
  final String? companyName;
  final List<ServiceCase> cases;

  int get active => cases.where(_isActive).length;
  int get needAction => cases.where(_needsAction).length;
  int get done => cases.where(_isDone).length;
  int get cancelled => cases.where(_isCancelled).length;

  static List<_CustomerCaseGroup> fromCases(List<ServiceCase> cases) {
    final grouped = <String, List<ServiceCase>>{};

    for (final serviceCase in cases) {
      final key = _groupKey(serviceCase);
      grouped.putIfAbsent(key, () => <ServiceCase>[]).add(serviceCase);
    }

    final groups = grouped.entries.map((entry) {
      final first = entry.value.first;
      return _CustomerCaseGroup(
        key: entry.key,
        customerName: first.displayCustomerName,
        email: first.customerEmail,
        phone: first.customerPhone,
        ntn: first.customerNtn,
        cnic: first.customerCnic,
        companyName: first.companyName,
        cases: entry.value,
      );
    }).toList();

    groups.sort((a, b) {
      final actionCompare = b.needAction.compareTo(a.needAction);
      if (actionCompare != 0) return actionCompare;
      return a.customerName.compareTo(b.customerName);
    });

    return groups;
  }

  static String _groupKey(ServiceCase serviceCase) {
    final values = [
      serviceCase.customerProfile,
      serviceCase.customerEmail,
      serviceCase.customerPhone,
      serviceCase.customerName,
      serviceCase.companyName,
    ];

    for (final value in values) {
      final text = value?.trim();
      if (text != null && text.isNotEmpty) return text;
    }

    return 'Unknown Customer';
  }
}

class _TopStats extends StatelessWidget {
  const _TopStats({required this.cases});

  final List<ServiceCase> cases;

  @override
  Widget build(BuildContext context) {
    final active = cases.where(_isActive).length;
    final needAction = cases.where(_needsAction).length;
    final done = cases.where(_isDone).length;

    return Row(
      children: [
        Expanded(child: _MetricTile(value: active.toString(), label: 'Active')),
        const SizedBox(width: 10),
        Expanded(
          child: _MetricTile(value: needAction.toString(), label: 'Need action'),
        ),
        const SizedBox(width: 10),
        Expanded(child: _MetricTile(value: done.toString(), label: 'Done')),
      ],
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
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: DropdownButtonFormField<String>(
        initialValue: selectedKey,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Customer / user',
          prefixIcon: Icon(Icons.person_search_rounded),
        ),
        items: groups
            .map(
              (group) => DropdownMenuItem<String>(
                value: group.key,
                child: Text(
                  '${group.customerName} · ${group.cases.length} requests',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: onSelected,
      ),
    );
  }
}

class _CustomerSummaryCard extends StatelessWidget {
  const _CustomerSummaryCard({required this.group});

  final _CustomerCaseGroup group;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.account_circle_outlined,
                  color: AppTheme.primaryRed,
                  size: 25,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.customerName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      group.email ?? group.phone ?? 'Customer service queue',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PremiumInfoChip(label: '${group.cases.length} requests'),
              PremiumInfoChip(label: '${group.active} active'),
              if (group.needAction > 0)
                PremiumInfoChip(
                  label: '${group.needAction} need action',
                  color: Colors.orange.shade800,
                ),
              if (group.done > 0)
                PremiumInfoChip(
                  label: '${group.done} done',
                  color: Colors.green.shade700,
                ),
              if (group.cancelled > 0)
                PremiumInfoChip(
                  label: '${group.cancelled} cancelled',
                  color: Colors.red.shade700,
                ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoGrid(
            items: [
              _InfoItem('Phone', group.phone),
              _InfoItem('Email', group.email),
              _InfoItem('NTN', group.ntn),
              _InfoItem('CNIC', group.cnic),
              _InfoItem('Company', group.companyName),
            ],
          ),
        ],
      ),
    );
  }
}

class _InternalServiceCaseCard extends ConsumerWidget {
  const _InternalServiceCaseCard({required this.serviceCase});

  final ServiceCase serviceCase;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressPercent =
        (serviceCase.progress.clamp(0, 1) * 100).round().toString();

    return PremiumCard(
      onTap: () => context.go('/my-services/${serviceCase.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusIcon(status: serviceCase.status),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              PremiumInfoChip(icon: Icons.category_outlined, label: serviceCase.category),
              ServiceCaseStatusBadge(status: serviceCase.status),
              PremiumInfoChip(
                icon: Icons.confirmation_number_outlined,
                label: serviceCase.displayReference,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withValues(alpha: 0.035),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: LinearProgressIndicator(
                      value: serviceCase.progress.clamp(0, 1),
                      minHeight: 8,
                      backgroundColor:
                          AppTheme.primaryRed.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '$progressPercent%',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (serviceCase.nextStep != null &&
              serviceCase.nextStep!.trim().isNotEmpty)
            _DetailRow(
              icon: Icons.flag_outlined,
              label: 'Next step',
              value: serviceCase.nextStep!,
            ),
          if (serviceCase.missingDocuments.isNotEmpty)
            _DetailRow(
              icon: Icons.warning_amber_rounded,
              label: 'Missing docs',
              value: '${serviceCase.missingDocuments.length} required',
            ),
          _DetailRow(
            icon: Icons.update_rounded,
            label: 'Updated',
            value: serviceCase.updatedAtLabel,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/my-services/${serviceCase.id}'),
                  icon: const Icon(Icons.visibility_outlined),
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

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.items});

  final List<_InfoItem> items;

  @override
  Widget build(BuildContext context) {
    final visibleItems = items
        .where((item) => item.value != null && item.value!.trim().isNotEmpty)
        .toList(growable: false);

    if (visibleItems.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final item in visibleItems)
          SizedBox(
            width: 145,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.value!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _InfoItem {
  const _InfoItem(this.label, this.value);
  final String label;
  final String? value;
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(12),
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
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w800,
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
    final normalized = status.toLowerCase();
    final icon = normalized.contains('complete')
        ? Icons.check_circle_rounded
        : normalized.contains('document')
            ? Icons.description_outlined
            : Icons.pending_actions_rounded;

    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: AppTheme.primaryRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(icon, color: AppTheme.primaryRed, size: 23),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: AppTheme.primaryRed.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.primaryRed, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label: $value',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackLoadingView extends StatelessWidget {
  const _TrackLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 164),
      children: const [
        PremiumListHeader(
          icon: Icons.track_changes_rounded,
          title: 'Track',
          subtitle: 'Loading customer service queues.',
          metaLabel: 'Loading',
        ),
        SizedBox(height: 16),
        PremiumCard(
          padding: EdgeInsets.all(22),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
    );
  }
}

bool _isCancelled(ServiceCase serviceCase) {
  final status = serviceCase.status.trim().toLowerCase();
  return status.contains('cancel') || status.contains('reject');
}

bool _isDone(ServiceCase serviceCase) {
  final status = serviceCase.status.trim().toLowerCase();
  return !_isCancelled(serviceCase) &&
      (status.contains('complete') || status.contains('closed'));
}

bool _needsAction(ServiceCase serviceCase) {
  final status = serviceCase.status.trim().toLowerCase();
  return !_isCancelled(serviceCase) &&
      !_isDone(serviceCase) &&
      (serviceCase.customerActionRequired ||
          status.contains('waiting for document') ||
          status.contains('waiting for payment') ||
          status.contains('waiting for customer') ||
          serviceCase.missingDocuments.isNotEmpty ||
          serviceCase.rejectedDocumentTotal > 0 ||
          serviceCase.rejectedPaymentTotal > 0);
}

bool _isActive(ServiceCase serviceCase) {
  return !_isCancelled(serviceCase) &&
      !_isDone(serviceCase) &&
      !_needsAction(serviceCase);
}
