import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/app_back_header.dart';
import '../../../core/widgets/premium_card.dart';
import '../domain/internal_service_case.dart';
import 'internal_workspace_providers.dart';

const EdgeInsets _kOpsPadding = EdgeInsets.fromLTRB(20, 8, 20, 164);

enum InternalOperationArea { customers, documents, payments }

class InternalOperationsCenterScreen extends ConsumerStatefulWidget {
  const InternalOperationsCenterScreen({required this.area, super.key});

  final InternalOperationArea area;

  @override
  ConsumerState<InternalOperationsCenterScreen> createState() =>
      _InternalOperationsCenterScreenState();
}

class _InternalOperationsCenterScreenState
    extends ConsumerState<InternalOperationsCenterScreen> {
  late final TextEditingController _searchController;
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _selectedFilter = _config.defaultFilter;
  }

  @override
  void didUpdateWidget(covariant InternalOperationsCenterScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.area != widget.area) {
      _selectedFilter = _config.defaultFilter;
      _searchController.clear();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  _AreaConfig get _config => _AreaConfig.forArea(widget.area);

  @override
  Widget build(BuildContext context) {
    final queueAsync = ref.watch(internalServiceCasesProvider);
    final config = _config;

    return Scaffold(
      body: Column(
        children: [
          AppBackHeader(
            title: config.title,
            subtitle: config.subtitle,
            actionIcon: config.actionIcon,
            actionTooltip: 'Open full list',
            onAction: () => context.go(config.fallbackRoute),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () {
                ref.invalidate(internalServiceCasesProvider);
                return ref.read(internalServiceCasesProvider.future);
              },
              child: queueAsync.when(
                loading: () => const _OperationsLoading(),
                error: (error, _) => _OperationsError(
                  title: '${config.title} unavailable',
                  message: _cleanErrorMessage(error),
                  onRetry: () => ref.invalidate(internalServiceCasesProvider),
                ),
                data: (queue) {
                  final cases = _filteredCases(queue.cases);
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: _kOpsPadding,
                    children: [
                      _OperationsSearchAndFilters(
                        controller: _searchController,

                        hint: config.searchHint,

                        filters: config.filters,

                        selectedFilter: _selectedFilter,

                        counts: widget.area == InternalOperationArea.payments
                            ? _paymentFilterCounts(queue.cases)
                            : const <String, int>{},

                        onSearchChanged: (_) => setState(() {}),

                        onFilterChanged: (value) =>
                            setState(() => _selectedFilter = value),
                      ),
                      const SizedBox(height: 14),
                      _OperationsSummary(area: widget.area, cases: cases),
                      const SizedBox(height: 16),
                      if (cases.isEmpty)
                        _OperationsEmpty(
                          title: config.emptyTitle,
                          message: config.emptyMessage,
                        )
                      else
                        for (final serviceCase in cases)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _OperationsCaseCard(
                              area: widget.area,
                              serviceCase: serviceCase,
                            ),
                          ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<InternalServiceCase> _filteredCases(List<InternalServiceCase> cases) {
    final query = _searchController.text.trim().toLowerCase();
    Iterable<InternalServiceCase> result = cases;

    if (query.isNotEmpty) {
      result = result.where((item) {
        final haystack = [
          item.id,
          item.displayCustomer,
          item.customerProfile,
          item.displayService,
          item.status,
          item.documentSummaryLabel,
        ].join(' ').toLowerCase();
        return haystack.contains(query);
      });
    }

    if (_selectedFilter != 'All') {
      result = result.where(
        (item) => _matchesAreaFilter(item, _selectedFilter),
      );
    }

    return result.toList(growable: false);
  }

  Map<String, int> _paymentFilterCounts(List<InternalServiceCase> cases) {
    final counts = <String, int>{};

    for (final filter in _config.filters) {
      if (filter == 'All') {
        counts[filter] = cases.length;
        continue;
      }

      counts[filter] = cases
          .where((item) => _matchesAreaFilter(item, filter))
          .length;
    }

    return counts;
  }

  bool _matchesAreaFilter(InternalServiceCase item, String filter) {
    switch (widget.area) {
      case InternalOperationArea.customers:
        if (filter == 'Has pending docs') {
          return item.pendingDocuments > 0;
        }
        if (filter == 'Has uploaded docs') {
          return item.uploadedDocuments > 0;
        }
        if (filter == 'Active') {
          return !_isClosedStatus(item.status);
        }
        return item.status.toLowerCase().contains(filter.toLowerCase());
      case InternalOperationArea.documents:
        if (filter == 'Needs Review') return item.uploadedDocuments > 0;
        if (filter == 'Missing') return item.pendingDocuments > 0;
        if (filter == 'Approved') return item.approvedDocuments > 0;
        if (filter == 'Rejected') return item.rejectedDocuments > 0;
        if (filter == 'Uploaded') return item.uploadedDocuments > 0;
        return true;
      case InternalOperationArea.payments:
        if (filter == 'Pending') return !_isClosedStatus(item.status);
        if (filter == 'Received') return _isClosedStatus(item.status);
        if (filter == 'Receipt Uploaded') return item.uploadedDocuments > 0;
        if (filter == 'Overdue') {
          return item.status.toLowerCase().contains('waiting');
        }
        return true;
    }
  }
}

bool _isClosedStatus(String status) {
  final clean = status.toLowerCase();
  return clean.contains('complete') ||
      clean.contains('cancel') ||
      clean.contains('closed');
}

class InternalServiceCaseWorkspaceScreen extends ConsumerWidget {
  const InternalServiceCaseWorkspaceScreen({required this.caseId, super.key});

  final String caseId;

  String get _fullCaseRoute => '/my-services/${Uri.encodeComponent(caseId)}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(internalServiceCasesProvider);

    return Scaffold(
      body: Column(
        children: [
          AppBackHeader(
            title: 'Case Details',
            subtitle: caseId,
            actionIcon: Icons.launch_rounded,
            actionTooltip: 'Open full case',
            onAction: () => context.go(_fullCaseRoute),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () {
                ref.invalidate(internalServiceCasesProvider);
                return ref.read(internalServiceCasesProvider.future);
              },
              child: queueAsync.when(
                loading: () => const _CaseDetailsLoading(),
                error: (error, _) => _CaseDetailsState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Case details unavailable',
                  message: _cleanErrorMessage(error),
                  actionLabel: 'Try again',
                  actionIcon: Icons.refresh_rounded,
                  onAction: () => ref.invalidate(internalServiceCasesProvider),
                ),
                data: (queue) {
                  InternalServiceCase? serviceCase;

                  for (final item in queue.cases) {
                    if (item.id == caseId) {
                      serviceCase = item;
                      break;
                    }
                  }

                  if (serviceCase == null) {
                    return _CaseDetailsState(
                      icon: Icons.search_off_rounded,
                      title: 'Case not found in queue',
                      message:
                          'This case is not available in the current operations '
                          'queue. Open the full case to review its available '
                          'details and actions.',
                      actionLabel: 'Open full case',
                      actionIcon: Icons.launch_rounded,
                      onAction: () => context.go(_fullCaseRoute),
                    );
                  }

                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: _kOpsPadding,
                    children: [
                      _ServiceWorkspaceHeader(serviceCase: serviceCase),
                      const SizedBox(height: 12),
                      _NextCaseAction(serviceCase: serviceCase),
                      const SizedBox(height: 12),
                      _WorkspaceOverview(serviceCase: serviceCase),
                      const SizedBox(height: 12),
                      _StatusProgressBlock(serviceCase: serviceCase),
                      const SizedBox(height: 12),
                      _DocumentsBlock(serviceCase: serviceCase),
                      const SizedBox(height: 12),
                      _PaymentsBlock(serviceCase: serviceCase),
                      const SizedBox(height: 12),
                      _ActivityTimelineBlock(serviceCase: serviceCase),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AreaConfig {
  const _AreaConfig({
    required this.title,
    required this.subtitle,
    required this.searchHint,
    required this.defaultFilter,
    required this.filters,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.fallbackRoute,
    required this.actionIcon,
  });

  factory _AreaConfig.forArea(InternalOperationArea area) {
    switch (area) {
      case InternalOperationArea.customers:
        return const _AreaConfig(
          title: 'Customers',
          subtitle: 'Profiles, services and account activity',
          searchHint: 'Search customer, CNIC, NTN, phone or service ID',
          defaultFilter: 'All',
          filters: [
            'All',
            'Active',
            'Has pending docs',
            'Has uploaded docs',
            'Completed',
          ],
          emptyTitle: 'No matching customers',
          emptyMessage: 'Adjust search or open the full customer list.',
          fallbackRoute: '/customers',
          actionIcon: Icons.groups_2_rounded,
        );
      case InternalOperationArea.documents:
        return const _AreaConfig(
          title: 'Document Review',
          subtitle: 'Review uploaded and pending documents',
          searchHint: 'Search customer, document context or service ID',
          defaultFilter: 'Needs Review',
          filters: [
            'Needs Review',
            'Uploaded',
            'Missing',
            'Approved',
            'Rejected',
            'All',
          ],
          emptyTitle: 'No documents in this filter',
          emptyMessage: 'Use another filter or open a service case directly.',
          fallbackRoute: '/documents',
          actionIcon: Icons.folder_copy_rounded,
        );
      case InternalOperationArea.payments:
        return const _AreaConfig(
          title: 'Payment Review',
          subtitle: 'Review receipts and payment status',
          searchHint: 'Search customer, receipt context or service ID',
          defaultFilter: 'Pending',
          filters: [
            'Pending',
            'Receipt Uploaded',
            'Received',
            'Rejected',
            'Overdue',
            'All',
          ],
          emptyTitle: 'No payments in this filter',
          emptyMessage:
              'Use another filter or open service cases for payment actions.',
          fallbackRoute: '/payments',
          actionIcon: Icons.payments_rounded,
        );
    }
  }

  final String title;
  final String subtitle;
  final String searchHint;
  final String defaultFilter;
  final List<String> filters;
  final String emptyTitle;
  final String emptyMessage;
  final String fallbackRoute;
  final IconData actionIcon;
}

class _OperationsSearchAndFilters extends StatelessWidget {
  const _OperationsSearchAndFilters({
    required this.controller,
    required this.hint,
    required this.filters,
    required this.selectedFilter,
    required this.onSearchChanged,
    required this.onFilterChanged,
    this.counts = const <String, int>{},
  });

  final TextEditingController controller;
  final String hint;
  final List<String> filters;
  final String selectedFilter;
  final Map<String, int> counts;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onFilterChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 66,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E6EE)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A0B1633),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 18),
              const Icon(
                Icons.search_rounded,
                size: 27,
                color: Color(0xFF172033),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: controller,
                  onChanged: onSearchChanged,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: const TextStyle(
                      color: Color(0xFF7A8190),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              Container(width: 1, height: 42, color: const Color(0xFFE4E7ED)),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () {},
                icon: const Icon(
                  Icons.tune_rounded,
                  size: 26,
                  color: Color(0xFF172033),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final filter in filters)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: _OpsFilterChip(
                    label: filter,
                    count: counts[filter],
                    selected: selectedFilter == filter,
                    onTap: () => onFilterChanged(filter),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OpsFilterChip extends StatelessWidget {
  const _OpsFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.count,
  });

  final String label;
  final int? count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.primary.withValues(alpha: 0.09) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppTheme.primary.withValues(alpha: 0.25)
                  : const Color(0xFFDCE1E9),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppTheme.primary : const Color(0xFF273044),
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: 9),
                Container(
                  constraints: const BoxConstraints(minWidth: 25),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppTheme.primary
                        : const Color(0xFFF0F2F6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: selected ? Colors.white : const Color(0xFF273044),
                      fontSize: 11,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OperationsSummary extends StatelessWidget {
  const _OperationsSummary({required this.area, required this.cases});

  final InternalOperationArea area;
  final List<InternalServiceCase> cases;

  @override
  Widget build(BuildContext context) {
    final uploaded = cases.fold<int>(
      0,
      (sum, item) => sum + item.uploadedDocuments,
    );
    final pending = cases.fold<int>(
      0,
      (sum, item) => sum + item.pendingDocuments,
    );
    final approved = cases.fold<int>(
      0,
      (sum, item) => sum + item.approvedDocuments,
    );
    final completed = cases
        .where((item) => _isClosedStatus(item.status))
        .length;

    if (area == InternalOperationArea.payments) {
      return LayoutBuilder(
        builder: (context, constraints) {
          final metrics = [
            _OpsMetric(
              value: '${cases.length}',
              label: 'Services',
              subtitle: 'Total',
              icon: Icons.receipt_long_outlined,
              color: AppTheme.primary,
            ),
            _OpsMetric(
              value: '$uploaded',
              label: 'Uploaded',
              subtitle: 'Files available',
              icon: Icons.cloud_upload_outlined,
              color: const Color(0xFFF08A35),
            ),
            _OpsMetric(
              value: '$pending',
              label: 'Pending',
              subtitle: 'Action required',
              icon: Icons.schedule_rounded,
              color: const Color(0xFF2464D8),
            ),
            _OpsMetric(
              value: '$completed',
              label: 'Received',
              subtitle: 'Completed',
              icon: Icons.check_circle_outline_rounded,
              color: const Color(0xFF2E9B58),
            ),
          ];

          return Row(
            children: [
              for (var index = 0; index < metrics.length; index++) ...[
                Expanded(
                  child: _OpsMetric(
                    value: metrics[index].value,
                    label: metrics[index].label,
                    subtitle: metrics[index].subtitle,
                    icon: metrics[index].icon,
                    color: metrics[index].color,
                    compact: true,
                  ),
                ),
                if (index != metrics.length - 1) const SizedBox(width: 8),
              ],
            ],
          );
        },
      );
    }

    if (area != InternalOperationArea.customers) {
      return Row(
        children: [
          Expanded(
            child: _OpsMetric(
              value: '${cases.length}',
              label: 'Services',
              subtitle: 'Total',
              icon: Icons.work_outline_rounded,
              color: const Color(0xFF2464D8),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _OpsMetric(
              value: '$uploaded',
              label: 'Uploaded',
              subtitle: 'Current',
              icon: Icons.cloud_upload_outlined,
              color: const Color(0xFFF08A35),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _OpsMetric(
              value: '$approved',
              label: 'Approved',
              subtitle: 'Current',
              icon: Icons.check_circle_outline_rounded,
              color: const Color(0xFF2E9B58),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: _OpsMetric(
            value: '${cases.length}',
            label: 'Customers',
            subtitle: 'Total',
            icon: Icons.group_outlined,
            color: const Color(0xFF2464D8),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _OpsMetric(
            value: '$uploaded',
            label: 'Uploaded',
            subtitle: 'Today',
            icon: Icons.cloud_upload_outlined,
            color: const Color(0xFFF08A35),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _OpsMetric(
            value: '$approved',
            label: 'Approved',
            subtitle: 'This month',
            icon: Icons.check_circle_outline_rounded,
            color: const Color(0xFF2E9B58),
          ),
        ),
      ],
    );
  }
}

class _OpsMetric extends StatelessWidget {
  const _OpsMetric({
    required this.value,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.compact = false,
  });

  final String value;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 7 : 14,
        vertical: compact ? 13 : 18,
      ),
      child: Column(
        mainAxisAlignment: compact
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        crossAxisAlignment: compact
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Container(
            width: compact ? 38 : 44,
            height: compact ? 38 : 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: compact ? 21 : 24),
          ),
          SizedBox(height: compact ? 10 : 14),
          Text(
            value,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: compact ? 20 : 22,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: compact ? 6 : 7),
          Text(
            label,
            maxLines: 1,
            textAlign: compact ? TextAlign.center : TextAlign.start,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFF526887),
              fontSize: compact ? 10.5 : 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 1,
            textAlign: compact ? TextAlign.center : TextAlign.start,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: compact ? 9.5 : 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _OperationsCaseCard extends StatelessWidget {
  const _OperationsCaseCard({required this.area, required this.serviceCase});

  final InternalOperationArea area;
  final InternalServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    if (area == InternalOperationArea.customers) {
      return _Customer360Card(serviceCase: serviceCase);
    }

    if (area == InternalOperationArea.payments) {
      return _PaymentReviewCard(serviceCase: serviceCase);
    }

    final subtitle =
        '${serviceCase.displayCustomer} · '
        '${serviceCase.displayService} · ${serviceCase.id}';

    return PremiumCard(
      onTap: () => context.go(
        '/internal-workspace/service-cases/'
        '${Uri.encodeComponent(serviceCase.id)}',
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(_areaIcon(area), color: AppTheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      serviceCase.documentSummaryLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12.5,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPill(label: serviceCase.status),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniTag(label: '${serviceCase.uploadedDocuments} uploaded'),
              _MiniTag(label: '${serviceCase.pendingDocuments} missing'),
              _MiniTag(label: '${serviceCase.approvedDocuments} approved'),
              if (serviceCase.rejectedDocuments > 0)
                _MiniTag(label: '${serviceCase.rejectedDocuments} rejected'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.go(
                    '/internal-workspace/service-cases/'
                    '${Uri.encodeComponent(serviceCase.id)}',
                  ),
                  icon: const Icon(Icons.visibility_outlined),
                  label: const Text('Open service'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => context.go(
                    '/my-services/${Uri.encodeComponent(serviceCase.id)}',
                  ),
                  icon: const Icon(Icons.rate_review_outlined),
                  label: const Text('Actions'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentReviewCard extends StatelessWidget {
  const _PaymentReviewCard({required this.serviceCase});

  final InternalServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    final workspacePath =
        '/internal-workspace/service-cases/'
        '${Uri.encodeComponent(serviceCase.id)}';
    final livePath = '/my-services/${Uri.encodeComponent(serviceCase.id)}';
    final isClosed = _isClosedStatus(serviceCase.status);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: () => context.go(workspacePath),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE7E9EF)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x080B1633),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.receipt_long_outlined,
                      color: AppTheme.primary,
                      size: 27,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Payment control',
                          style: TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 17,
                            height: 1.15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          '${serviceCase.displayCustomer}  ·  '
                          '${serviceCase.displayService}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF526887),
                            fontSize: 13,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          serviceCase.id,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF526887),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusPill(label: serviceCase.status),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.textPrimary,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _PaymentCountTag(
                    label: '${serviceCase.uploadedDocuments} uploaded',
                    color: const Color(0xFF2464D8),
                    background: const Color(0xFFEEF3FF),
                  ),
                  _PaymentCountTag(
                    label: '${serviceCase.pendingDocuments} missing',
                    color: const Color(0xFFE27922),
                    background: const Color(0xFFFFF3E8),
                  ),
                  _PaymentCountTag(
                    label: '${serviceCase.approvedDocuments} approved',
                    color: const Color(0xFF16864B),
                    background: const Color(0xFFEAF7EF),
                  ),
                  if (serviceCase.rejectedDocuments > 0)
                    _PaymentCountTag(
                      label: '${serviceCase.rejectedDocuments} rejected',
                      color: AppTheme.primary,
                      background: AppTheme.primary.withValues(alpha: 0.07),
                    ),
                ],
              ),
              const SizedBox(height: 15),
              Container(height: 1, color: const Color(0xFFE5E8EF)),
              const SizedBox(height: 14),
              LayoutBuilder(
                builder: (context, constraints) {
                  final dateInfo = Row(
                    children: [
                      Expanded(
                        child: _PaymentMetaItem(
                          icon: Icons.calendar_today_outlined,
                          label: 'Requested on',
                          value: serviceCase.createdAt,
                        ),
                      ),
                      if (constraints.maxWidth >= 560) ...[
                        Container(
                          width: 1,
                          height: 42,
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          color: const Color(0xFFE5E8EF),
                        ),
                        Expanded(
                          child: _PaymentMetaItem(
                            icon: Icons.update_rounded,
                            label: 'Last updated',
                            value: serviceCase.updatedAt,
                          ),
                        ),
                      ],
                    ],
                  );

                  final action = SizedBox(
                    height: 44,
                    child: isClosed
                        ? OutlinedButton.icon(
                            onPressed: () => context.go(livePath),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primary,
                              side: const BorderSide(color: AppTheme.primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13),
                              ),
                            ),
                            icon: const Icon(
                              Icons.receipt_long_outlined,
                              size: 19,
                            ),
                            label: const Text(
                              'View Payment',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          )
                        : FilledButton.icon(
                            onPressed: () => context.go(livePath),
                            style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(13),
                              ),
                              elevation: 0,
                            ),
                            icon: const Icon(
                              Icons.visibility_outlined,
                              size: 20,
                            ),
                            label: const Text(
                              'Review Payment',
                              style: TextStyle(fontWeight: FontWeight.w900),
                            ),
                          ),
                  );

                  if (constraints.maxWidth < 470) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [dateInfo, const SizedBox(height: 13), action],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: dateInfo),
                      const SizedBox(width: 16),
                      action,
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentMetaItem extends StatelessWidget {
  const _PaymentMetaItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 19, color: const Color(0xFF172033)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF526887),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaymentCountTag extends StatelessWidget {
  const _PaymentCountTag({
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _Customer360Card extends StatelessWidget {
  const _Customer360Card({required this.serviceCase});

  final InternalServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    final workspacePath =
        '/internal-workspace/service-cases/'
        '${Uri.encodeComponent(serviceCase.id)}';

    final livePath = '/my-services/${Uri.encodeComponent(serviceCase.id)}';

    final initial = serviceCase.displayCustomer.trim().isEmpty
        ? '?'
        : serviceCase.displayCustomer.trim()[0].toUpperCase();

    final avatarColor = _customerAvatarColor(serviceCase.id);
    final statusColor = _customerStatusColor(serviceCase.status);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: () => context.go(workspacePath),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE7E9EF)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x080B1633),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: avatarColor.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          initial,
                          style: TextStyle(
                            color: avatarColor,
                            fontSize: 24,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Positioned(
                        right: 1,
                        bottom: 1,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: _isClosedStatus(serviceCase.status)
                                ? const Color(0xFFA8AFBB)
                                : const Color(0xFF42BE78),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          serviceCase.displayCustomer,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            height: 1.1,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          '${serviceCase.displayService}  •  '
                          '${serviceCase.id}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF526887),
                            fontSize: 13,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _CustomerStatusPill(
                        label: serviceCase.status,
                        color: statusColor,
                      ),
                      const SizedBox(height: 8),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppTheme.textPrimary,
                        size: 26,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 17),
              Padding(
                padding: const EdgeInsets.only(left: 72),
                child: Wrap(
                  spacing: 9,
                  runSpacing: 8,
                  children: [
                    _CustomerDocumentTag(
                      label: '${serviceCase.uploadedDocuments} uploaded',
                      color: serviceCase.uploadedDocuments > 0
                          ? const Color(0xFF2E9B58)
                          : AppTheme.primary,
                    ),
                    _CustomerDocumentTag(
                      label: '${serviceCase.pendingDocuments} missing',
                      color: serviceCase.pendingDocuments > 0
                          ? const Color(0xFFF08A35)
                          : const Color(0xFF2E9B58),
                    ),
                    _CustomerDocumentTag(
                      label: '${serviceCase.approvedDocuments} approved',
                      color: const Color(0xFF2E9B58),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 17),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => context.go(workspacePath),
                      icon: const Icon(Icons.visibility_outlined, size: 19),
                      label: const Text('Open 360'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textPrimary,
                        side: const BorderSide(color: Color(0xFF7D8490)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => context.go(livePath),
                      icon: const Icon(Icons.bar_chart_rounded, size: 20),
                      label: const Text('Actions'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
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

class _CustomerStatusPill extends StatelessWidget {
  const _CustomerStatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 105),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _CustomerDocumentTag extends StatelessWidget {
  const _CustomerDocumentTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.075),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

Color _customerStatusColor(String status) {
  final clean = status.toLowerCase();

  if (clean.contains('cancel') || clean.contains('closed')) {
    return const Color(0xFF616A7A);
  }

  if (clean.contains('complete')) {
    return const Color(0xFF2E9B58);
  }

  if (clean.contains('progress') ||
      clean.contains('review') ||
      clean.contains('waiting')) {
    return const Color(0xFF6842C2);
  }

  return const Color(0xFF2464D8);
}

Color _customerAvatarColor(String seed) {
  const colors = [
    Color(0xFFD51445),
    Color(0xFF2464D8),
    Color(0xFFCF8A20),
    Color(0xFF6738C7),
  ];

  return colors[seed.hashCode.abs() % colors.length];
}

IconData _areaIcon(InternalOperationArea area) {
  switch (area) {
    case InternalOperationArea.customers:
      return Icons.person_search_rounded;
    case InternalOperationArea.documents:
      return Icons.folder_copy_rounded;
    case InternalOperationArea.payments:
      return Icons.receipt_long_rounded;
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = _workspaceStatusColors(label);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        child: Text(
          label.trim().isEmpty ? 'Not set' : label.trim(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colors.foreground,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cleanLabel = label.toLowerCase();

    late final Color foreground;
    late final Color background;

    if (cleanLabel.contains('approved')) {
      foreground = const Color(0xFF138A4B);
      background = const Color(0xFFE8F7EE);
    } else if (cleanLabel.contains('rejected')) {
      foreground = const Color(0xFFC81E3A);
      background = const Color(0xFFFDECEF);
    } else if (cleanLabel.contains('missing')) {
      foreground = const Color(0xFFE86F00);
      background = const Color(0xFFFFF1E3);
    } else {
      foreground = const Color(0xFF155EEF);
      background = const Color(0xFFEAF1FF);
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: TextStyle(
            color: foreground,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _ServiceWorkspaceHeader extends StatelessWidget {
  const _ServiceWorkspaceHeader({required this.serviceCase});

  final InternalServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    final priorityColors = _workspacePriorityColors(serviceCase.priority);

    return PremiumCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _WorkspaceIconTile(
            icon: Icons.business_center_outlined,
            foreground: Color(0xFF344054),
            background: Color(0xFFF1F3F7),
            size: 48,
            iconSize: 23,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        serviceCase.displayService,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 17,
                          height: 1.18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.25,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(child: _StatusPill(label: serviceCase.status)),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  serviceCase.displayCustomer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${serviceCase.id}  •  Updated ${serviceCase.updatedAt}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11.5,
                    height: 1.35,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 11),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: priorityColors.foreground,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Text(
                      '${_displayValue(serviceCase.priority)} priority',
                      style: TextStyle(
                        color: priorityColors.foreground,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
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
}

class _NextCaseAction extends StatelessWidget {
  const _NextCaseAction({required this.serviceCase});

  final InternalServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    final nextAction = _caseNextAction(serviceCase);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7FD),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFDDE8F6)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 14, 15, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _WorkspaceIconTile(
                  icon: Icons.next_plan_outlined,
                  foreground: Color(0xFF315F91),
                  background: Color(0xFFE1ECF8),
                  size: 38,
                  iconSize: 19,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Next action',
                        style: TextStyle(
                          color: Color(0xFF315F91),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        nextAction,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13.5,
                          height: 1.35,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: const Color(0xFF263244),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(16),
            ),
            child: InkWell(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
              onTap: () => context.go(
                '/my-services/${Uri.encodeComponent(serviceCase.id)}',
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 15, vertical: 13),
                child: Row(
                  children: [
                    Icon(
                      Icons.admin_panel_settings_outlined,
                      color: Colors.white,
                      size: 19,
                    ),
                    SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        'Open case actions',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceOverview extends StatelessWidget {
  const _WorkspaceOverview({required this.serviceCase});

  final InternalServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    return _WorkspaceSection(
      title: 'Case overview',
      icon: Icons.grid_view_rounded,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final useGrid = constraints.maxWidth >= 430;
            final width = useGrid
                ? (constraints.maxWidth - 10) / 2
                : constraints.maxWidth;

            final items = [
              _OverviewItem(
                icon: Icons.person_outline_rounded,
                label: 'Customer',
                value: serviceCase.displayCustomer,
              ),
              _OverviewItem(
                icon: Icons.flag_outlined,
                label: 'Current status',
                value: _displayValue(serviceCase.status),
              ),
              _OverviewItem(
                icon: Icons.priority_high_rounded,
                label: 'Priority',
                value: _displayValue(serviceCase.priority),
              ),
              _OverviewItem(
                icon: Icons.update_rounded,
                label: 'Last updated',
                value: _displayValue(serviceCase.updatedAt),
              ),
            ];

            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final item in items) SizedBox(width: width, child: item),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _OverviewItem extends StatelessWidget {
  const _OverviewItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 76),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7EAF0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 31,
            height: 31,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE3E7EE)),
            ),
            child: Icon(icon, size: 16, color: const Color(0xFF667085)),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _displayValue(value),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12.5,
                    height: 1.3,
                    fontWeight: FontWeight.w800,
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

class _StatusProgressBlock extends StatelessWidget {
  const _StatusProgressBlock({required this.serviceCase});

  final InternalServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    return _WorkspaceSection(
      title: 'Service progress',
      icon: Icons.route_outlined,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                _progressHeading(serviceCase.status),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _displayValue(serviceCase.status),
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 17),
        _WorkspaceProgressTracker(status: serviceCase.status),
      ],
    );
  }
}

class _WorkspaceProgressTracker extends StatelessWidget {
  const _WorkspaceProgressTracker({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    const labels = ['Open', 'Processing', 'Review', 'Completed'];
    final progress = _progressState(status);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < labels.length; index++) ...[
          Expanded(
            child: _ProgressStage(
              label: progress.isCancelled && index == progress.index
                  ? 'Closed'
                  : labels[index],
              isCompleted: !progress.isCancelled && index < progress.index,
              isCurrent: index == progress.index,
              isCancelled: progress.isCancelled && index == progress.index,
            ),
          ),
          if (index != labels.length - 1)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 7),
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    color: !progress.isCancelled && index < progress.index
                        ? const Color(0xFF5A9B73)
                        : const Color(0xFFE0E4EB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _ProgressStage extends StatelessWidget {
  const _ProgressStage({
    required this.label,
    required this.isCompleted,
    required this.isCurrent,
    required this.isCancelled,
  });

  final String label;
  final bool isCompleted;
  final bool isCurrent;
  final bool isCancelled;

  @override
  Widget build(BuildContext context) {
    final Color circleColor;
    final Color borderColor;

    if (isCancelled) {
      circleColor = const Color(0xFF667085);
      borderColor = const Color(0xFF667085);
    } else if (isCompleted) {
      circleColor = const Color(0xFF5A9B73);
      borderColor = const Color(0xFF5A9B73);
    } else if (isCurrent) {
      circleColor = AppTheme.primary;
      borderColor = AppTheme.primary;
    } else {
      circleColor = Colors.white;
      borderColor = const Color(0xFFC9CFDA);
    }

    return Column(
      children: [
        Container(
          width: 15,
          height: 15,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: circleColor,
            shape: BoxShape.circle,
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: isCompleted
              ? const Icon(Icons.check_rounded, size: 9, color: Colors.white)
              : isCancelled
              ? const Icon(Icons.close_rounded, size: 9, color: Colors.white)
              : null,
        ),
        const SizedBox(height: 7),
        Text(
          label,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isCurrent || isCompleted
                ? AppTheme.textPrimary
                : AppTheme.textSecondary,
            fontSize: 9.5,
            height: 1.2,
            fontWeight: isCurrent ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _DocumentsBlock extends StatelessWidget {
  const _DocumentsBlock({required this.serviceCase});

  final InternalServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    final received =
        serviceCase.uploadedDocuments + serviceCase.approvedDocuments;
    final total = received + serviceCase.pendingDocuments;
    final progress = total == 0 ? 0.0 : (received / total).clamp(0.0, 1.0);

    final metrics = <_DocumentMetric>[
      _DocumentMetric(
        label: 'Received',
        count: received,
        color: const Color(0xFF3478F6),
      ),
      _DocumentMetric(
        label: 'Approved',
        count: serviceCase.approvedDocuments,
        color: const Color(0xFF238653),
      ),
      _DocumentMetric(
        label: 'Missing',
        count: serviceCase.pendingDocuments,
        color: const Color(0xFFD87816),
      ),
      if (serviceCase.rejectedDocuments > 0)
        _DocumentMetric(
          label: 'Rejected',
          count: serviceCase.rejectedDocuments,
          color: const Color(0xFFC93C52),
        ),
    ];

    return _WorkspaceSection(
      title: 'Documents',
      icon: Icons.folder_outlined,
      trailing: TextButton(
        onPressed: () =>
            context.go('/my-services/${Uri.encodeComponent(serviceCase.id)}'),
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF315F91),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          textStyle: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w900,
          ),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('View all'),
            SizedBox(width: 2),
            Icon(Icons.arrow_forward_rounded, size: 16),
          ],
        ),
      ),
      children: [
        Wrap(spacing: 18, runSpacing: 13, children: metrics),
        const SizedBox(height: 17),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            backgroundColor: const Color(0xFFE9EDF3),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF3478F6)),
          ),
        ),
        const SizedBox(height: 9),
        Text(
          total == 0
              ? 'No document requirements are available in this summary.'
              : '$received of $total documents received',
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _DocumentMetric extends StatelessWidget {
  const _DocumentMetric({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
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
}

class _PaymentsBlock extends StatelessWidget {
  const _PaymentsBlock({required this.serviceCase});

  final InternalServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    return _WorkspaceSection(
      title: 'Payment review',
      icon: Icons.receipt_long_outlined,
      children: [
        const Text(
          'Review invoices, receipts and payment status in the full case. '
          'Payment records are not loaded in this overview.',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12.5,
            height: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 14),
        _CaseNavigationAction(
          icon: Icons.payments_outlined,
          label: 'Open payment actions',
          onTap: () =>
              context.go('/my-services/${Uri.encodeComponent(serviceCase.id)}'),
        ),
      ],
    );
  }
}

class _ActivityTimelineBlock extends StatelessWidget {
  const _ActivityTimelineBlock({required this.serviceCase});

  final InternalServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    return _WorkspaceSection(
      title: 'Case activity',
      icon: Icons.schedule_rounded,
      children: [
        _CompactActivityItem(
          icon: Icons.add_circle_outline_rounded,
          title: 'Case created',
          value: _displayValue(serviceCase.createdAt),
        ),
        const _ActivityDivider(),
        _CompactActivityItem(
          icon: Icons.update_rounded,
          title: 'Last updated',
          value: _displayValue(serviceCase.updatedAt),
        ),
        const _ActivityDivider(),
        _CompactActivityItem(
          icon: Icons.flag_outlined,
          title: 'Current workflow state',
          value: _displayValue(serviceCase.status),
        ),
      ],
    );
  }
}

class _CaseNavigationAction extends StatelessWidget {
  const _CaseNavigationAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF7F8FA),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: const Color(0xFFE4E7ED)),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF475467)),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 17,
                color: Color(0xFF667085),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactActivityItem extends StatelessWidget {
  const _CompactActivityItem({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFF2F4F7),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 17, color: const Color(0xFF667085)),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
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
    );
  }
}

class _ActivityDivider extends StatelessWidget {
  const _ActivityDivider();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.fromLTRB(17, 5, 0, 5),
      child: SizedBox(
        height: 12,
        child: VerticalDivider(
          width: 1,
          thickness: 1,
          color: Color(0xFFDDE2EA),
        ),
      ),
    );
  }
}

class _CaseDetailsLoading extends StatelessWidget {
  const _CaseDetailsLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: _kOpsPadding,
      children: const [
        _CaseSkeletonCard(height: 128),
        SizedBox(height: 12),
        _CaseSkeletonCard(height: 112),
        SizedBox(height: 12),
        _CaseSkeletonCard(height: 190),
        SizedBox(height: 12),
        _CaseSkeletonCard(height: 160),
      ],
    );
  }
}

class _CaseSkeletonCard extends StatelessWidget {
  const _CaseSkeletonCard({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EBF0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 12,
            decoration: BoxDecoration(
              color: const Color(0xFFEEF1F5),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 13),
          Container(
            width: double.infinity,
            height: 14,
            decoration: BoxDecoration(
              color: const Color(0xFFE9EDF2),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 9),
          Container(
            width: 180,
            height: 11,
            decoration: BoxDecoration(
              color: const Color(0xFFF0F2F5),
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ],
      ),
    );
  }
}

class _CaseDetailsState extends StatelessWidget {
  const _CaseDetailsState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.actionIcon,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final IconData actionIcon;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: _kOpsPadding,
      children: [
        PremiumCard(
          child: Column(
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F3F6),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(icon, size: 25, color: const Color(0xFF667085)),
              ),
              const SizedBox(height: 15),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12.5,
                  height: 1.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 44,
                child: FilledButton.icon(
                  onPressed: onAction,
                  icon: Icon(actionIcon, size: 18),
                  label: Text(actionLabel),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF263244),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CaseProgressState {
  const _CaseProgressState({required this.index, required this.isCancelled});

  final int index;
  final bool isCancelled;
}

_CaseProgressState _progressState(String rawStatus) {
  final clean = rawStatus.trim().toLowerCase();

  if (clean.contains('cancel') ||
      clean.contains('rejected') ||
      clean.contains('closed')) {
    return const _CaseProgressState(index: 3, isCancelled: true);
  }

  if (clean.contains('complete') || clean.contains('done')) {
    return const _CaseProgressState(index: 3, isCancelled: false);
  }

  if (clean.contains('review') ||
      clean.contains('approval') ||
      clean.contains('verification')) {
    return const _CaseProgressState(index: 2, isCancelled: false);
  }

  if (clean.contains('progress') ||
      clean.contains('processing') ||
      clean.contains('working') ||
      clean.contains('pending') ||
      clean.contains('waiting')) {
    return const _CaseProgressState(index: 1, isCancelled: false);
  }

  return const _CaseProgressState(index: 0, isCancelled: false);
}

String _progressHeading(String status) {
  final state = _progressState(status);

  if (state.isCancelled) return 'Case closed without completion';
  if (state.index == 3) return 'Service workflow completed';
  if (state.index == 2) return 'Case is under review';
  if (state.index == 1) return 'Service work is in progress';
  return 'Case has entered the workflow';
}

String _caseNextAction(InternalServiceCase item) {
  if (_progressState(item.status).isCancelled) {
    return 'Review the closed case and available administrative actions';
  }

  if (item.uploadedDocuments > 0) {
    final count = item.uploadedDocuments;
    return 'Review $count uploaded customer '
        '${count == 1 ? 'document' : 'documents'}';
  }

  if (item.pendingDocuments > 0) {
    final count = item.pendingDocuments;
    return 'Request $count missing '
        '${count == 1 ? 'document' : 'documents'} from the customer';
  }

  if (!_isClosedStatus(item.status)) {
    return 'Continue internal processing for this service case';
  }

  return 'Review the completed case and available follow-up actions';
}

String _displayValue(String value) {
  final clean = value.trim();
  if (clean.isEmpty || clean == '-') return 'Not available';
  return clean;
}

class _WorkspaceSection extends StatelessWidget {
  const _WorkspaceSection({
    required this.title,
    required this.icon,
    required this.children,
    this.trailing,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _WorkspaceIconTile(
                icon: icon,
                foreground: AppTheme.primary,
                background: AppTheme.primary.withValues(alpha: 0.08),
                size: 38,
                iconSize: 19,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 17),
          ...children,
        ],
      ),
    );
  }
}

class _WorkspaceIconTile extends StatelessWidget {
  const _WorkspaceIconTile({
    required this.icon,
    required this.foreground,
    required this.background,
    required this.size,
    required this.iconSize,
  });

  final IconData icon;
  final Color foreground;
  final Color background;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, color: foreground, size: iconSize),
    );
  }
}

class _WorkspaceColors {
  const _WorkspaceColors({required this.foreground, required this.background});

  final Color foreground;
  final Color background;
}

_WorkspaceColors _workspaceStatusColors(String rawStatus) {
  final status = rawStatus.trim().toLowerCase();

  if (status.contains('complete') ||
      status.contains('closed') ||
      status.contains('approved')) {
    return const _WorkspaceColors(
      foreground: Color(0xFF138A4B),
      background: Color(0xFFE8F7EE),
    );
  }

  if (status.contains('cancel') ||
      status.contains('reject') ||
      status.contains('failed')) {
    return const _WorkspaceColors(
      foreground: Color(0xFFC81E3A),
      background: Color(0xFFFDECEF),
    );
  }

  if (status.contains('progress') ||
      status.contains('processing') ||
      status.contains('review')) {
    return const _WorkspaceColors(
      foreground: Color(0xFFE86F00),
      background: Color(0xFFFFF1E3),
    );
  }

  return const _WorkspaceColors(
    foreground: Color(0xFF155EEF),
    background: Color(0xFFEAF1FF),
  );
}

_WorkspaceColors _workspacePriorityColors(String rawPriority) {
  final priority = rawPriority.trim().toLowerCase();

  if (priority.contains('urgent') ||
      priority.contains('critical') ||
      priority.contains('high')) {
    return const _WorkspaceColors(
      foreground: Color(0xFFC81E3A),
      background: Color(0xFFFDECEF),
    );
  }

  if (priority.contains('medium') || priority.contains('normal')) {
    return const _WorkspaceColors(
      foreground: Color(0xFFE86F00),
      background: Color(0xFFFFF1E3),
    );
  }

  return const _WorkspaceColors(
    foreground: Color(0xFF138A4B),
    background: Color(0xFFE8F7EE),
  );
}

class _OperationsLoading extends StatelessWidget {
  const _OperationsLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: _kOpsPadding,
      children: const [
        _LoadingCard(height: 130),
        SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _LoadingCard(height: 78)),
            SizedBox(width: 10),
            Expanded(child: _LoadingCard(height: 78)),
            SizedBox(width: 10),
            Expanded(child: _LoadingCard(height: 78)),
          ],
        ),
        SizedBox(height: 14),
        _LoadingCard(height: 176),
        SizedBox(height: 12),
        _LoadingCard(height: 176),
      ],
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(24),
      ),
    );
  }
}

class _OperationsError extends StatelessWidget {
  const _OperationsError({
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: _kOpsPadding,
      children: [
        PremiumCard(
          child: Column(
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: AppTheme.primary,
                size: 34,
              ),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
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
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OperationsEmpty extends StatelessWidget {
  const _OperationsEmpty({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        children: [
          const Icon(Icons.inbox_rounded, color: AppTheme.primary, size: 34),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
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
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.open_in_new_rounded),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

String _cleanErrorMessage(Object error) {
  if (error is ApiError && error.message.trim().isNotEmpty) {
    return error.message.trim();
  }

  final raw = error.toString().replaceFirst('ApiError:', '').trim();
  return raw.isEmpty ? 'The internal workspace could not load this data.' : raw;
}
