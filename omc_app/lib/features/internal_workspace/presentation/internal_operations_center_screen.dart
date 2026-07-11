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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(internalServiceCasesProvider);

    return Scaffold(
      body: Column(
        children: [
          AppBackHeader(
            title: 'Service Workspace',
            subtitle: caseId,
            actionIcon: Icons.open_in_new_rounded,
            actionTooltip: 'Open live case',
            onAction: () =>
                context.go('/my-services/${Uri.encodeComponent(caseId)}'),
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
                  title: 'Service workspace unavailable',
                  message: _cleanErrorMessage(error),
                  onRetry: () => ref.invalidate(internalServiceCasesProvider),
                ),
                data: (queue) {
                  final serviceCase = queue.cases
                      .where((item) => item.id == caseId)
                      .cast<InternalServiceCase?>()
                      .firstWhere((item) => item != null, orElse: () => null);

                  if (serviceCase == null) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: _kOpsPadding,
                      children: [
                        _OperationsEmpty(
                          title: 'Case not found in queue',
                          message:
                              'Open the live case page to review full backend details and actions.',
                          actionLabel: 'Open live case',
                          onAction: () => context.go(
                            '/my-services/${Uri.encodeComponent(caseId)}',
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: _kOpsPadding,
                    children: [
                      _ServiceWorkspaceHeader(serviceCase: serviceCase),
                      const SizedBox(height: 14),
                      _WorkspaceOverview(serviceCase: serviceCase),
                      const SizedBox(height: 14),
                      _DocumentsBlock(serviceCase: serviceCase),
                      const SizedBox(height: 14),
                      _PaymentsBlock(serviceCase: serviceCase),
                      const SizedBox(height: 14),
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
          title: 'Customer 360',
          subtitle: 'Customer-first operations center',
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
          subtitle: 'Needs review, missing, approved and rejected files',
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
          subtitle: 'Receipt review and payment control',
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
  });

  final TextEditingController controller;
  final String hint;
  final List<String> filters;
  final String selectedFilter;
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
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppTheme.primaryRed.withValues(alpha: 0.09)
          : Colors.white,
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
                  ? AppTheme.primaryRed.withValues(alpha: 0.25)
                  : const Color(0xFFDCE1E9),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppTheme.primaryRed : const Color(0xFF273044),
              fontSize: 13,
              fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
            ),
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
              color: AppTheme.primaryRed,
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

          if (constraints.maxWidth < 700) {
            return GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.28,
              children: metrics,
            );
          }

          return Row(
            children: [
              for (var index = 0; index < metrics.length; index++) ...[
                Expanded(child: metrics[index]),
                if (index != metrics.length - 1) const SizedBox(width: 10),
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
  });

  final String value;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 14),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 22,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF526887),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
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
                  color: AppTheme.primaryRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(_areaIcon(area), color: AppTheme.primaryRed),
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
                      color: AppTheme.primaryRed.withValues(alpha: 0.09),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.receipt_long_outlined,
                      color: AppTheme.primaryRed,
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
                      color: AppTheme.primaryRed,
                      background: AppTheme.primaryRed.withValues(alpha: 0.07),
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
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 19,
                        color: Color(0xFF172033),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Requested on',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              serviceCase.createdAt,
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

                  final action = SizedBox(
                    height: 44,
                    child: isClosed
                        ? OutlinedButton.icon(
                            onPressed: () => context.go(livePath),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.primaryRed,
                              side: const BorderSide(
                                color: AppTheme.primaryRed,
                              ),
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
                              backgroundColor: AppTheme.primaryRed,
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
                          : AppTheme.primaryRed,
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
    final statusColors = _workspaceStatusColors(serviceCase.status);

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _WorkspaceIconTile(
                icon: Icons.description_outlined,
                foreground: AppTheme.primaryRed,
                background: AppTheme.primaryRed.withValues(alpha: 0.09),
                size: 58,
                iconSize: 29,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        serviceCase.displayService,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 21,
                          height: 1.15,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '${serviceCase.id}  •  ${serviceCase.displayCustomer}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12.5,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 10),
              _WorkspaceBadge(
                label: serviceCase.status,
                foreground: statusColors.foreground,
                background: statusColors.background,
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: () => context.go(
                '/my-services/${Uri.encodeComponent(serviceCase.id)}',
              ),
              icon: const Icon(Icons.admin_panel_settings_outlined, size: 20),
              label: const Text(
                'Open live review / actions',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 14.0;
        final useColumns = constraints.maxWidth >= 430;

        if (!useColumns) {
          return Column(
            children: [
              _CustomerBlock(serviceCase: serviceCase),
              const SizedBox(height: gap),
              _StatusProgressBlock(serviceCase: serviceCase),
            ],
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _CustomerBlock(serviceCase: serviceCase)),
              const SizedBox(width: gap),
              Expanded(child: _StatusProgressBlock(serviceCase: serviceCase)),
            ],
          ),
        );
      },
    );
  }
}

class _CustomerBlock extends StatelessWidget {
  const _CustomerBlock({required this.serviceCase});

  final InternalServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    return _WorkspaceSection(
      title: 'Customer',
      icon: Icons.person_outline_rounded,
      children: [
        _InfoLine(label: 'Name', value: serviceCase.displayCustomer),
        _InfoLine(label: 'Profile', value: serviceCase.customerProfile),
        _InfoLine(label: 'Service', value: serviceCase.displayService),
        _InfoLine(label: 'Last update', value: serviceCase.updatedAt),
      ],
    );
  }
}

class _StatusProgressBlock extends StatelessWidget {
  const _StatusProgressBlock({required this.serviceCase});

  final InternalServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    final statusColors = _workspaceStatusColors(serviceCase.status);
    final priorityColors = _workspacePriorityColors(serviceCase.priority);

    return _WorkspaceSection(
      title: 'Status & Progress',
      icon: Icons.trending_up_rounded,
      children: [
        _InfoLine(
          label: 'Current status',
          customValue: Align(
            alignment: Alignment.centerLeft,
            child: _WorkspaceBadge(
              label: serviceCase.status,
              foreground: statusColors.foreground,
              background: statusColors.background,
            ),
          ),
        ),
        _InfoLine(
          label: 'Priority',
          customValue: Align(
            alignment: Alignment.centerLeft,
            child: _WorkspaceBadge(
              label: serviceCase.priority,
              foreground: priorityColors.foreground,
              background: priorityColors.background,
            ),
          ),
        ),
        _InfoLine(label: 'Next step', value: _nextStep(serviceCase)),
        const SizedBox(height: 11),
        _WorkspaceProgressTracker(status: serviceCase.status),
      ],
    );
  }

  String _nextStep(InternalServiceCase item) {
    if (item.uploadedDocuments > 0) {
      return 'Review uploaded customer documents';
    }
    if (item.pendingDocuments > 0) {
      return 'Ask customer for missing documents';
    }
    if (!_isClosedStatus(item.status)) {
      return 'Continue internal processing';
    }
    return 'Case is closed or complete';
  }
}

class _WorkspaceProgressTracker extends StatelessWidget {
  const _WorkspaceProgressTracker({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    const labels = ['Open', 'In Progress', 'Review', 'Completed'];
    final activeIndex = _progressIndex(status);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < labels.length; index++) ...[
          Expanded(
            child: _ProgressStage(
              label: labels[index],
              isActive: index <= activeIndex,
              isCurrent: index == activeIndex,
            ),
          ),
          if (index != labels.length - 1)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Container(
                  height: 2,
                  color: index < activeIndex
                      ? AppTheme.primaryRed
                      : const Color(0xFFD8DDE8),
                ),
              ),
            ),
        ],
      ],
    );
  }

  int _progressIndex(String rawStatus) {
    final clean = rawStatus.trim().toLowerCase();

    if (clean.contains('complete') ||
        clean.contains('closed') ||
        clean.contains('cancel')) {
      return 3;
    }

    if (clean.contains('review') ||
        clean.contains('approval') ||
        clean.contains('verification')) {
      return 2;
    }

    if (clean.contains('progress') ||
        clean.contains('processing') ||
        clean.contains('working') ||
        clean.contains('pending') ||
        clean.contains('waiting')) {
      return 1;
    }

    return 0;
  }
}

class _ProgressStage extends StatelessWidget {
  const _ProgressStage({
    required this.label,
    required this.isActive,
    required this.isCurrent,
  });

  final String label;
  final bool isActive;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final foreground = isActive ? AppTheme.primaryRed : const Color(0xFFAFB8C8);

    return Column(
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: isActive ? AppTheme.primaryRed : Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: foreground, width: isCurrent ? 3 : 1.5),
            boxShadow: isCurrent
                ? [
                    BoxShadow(
                      color: AppTheme.primaryRed.withValues(alpha: 0.18),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: isActive && !isCurrent
              ? const Icon(Icons.check_rounded, size: 11, color: Colors.white)
              : null,
        ),
        const SizedBox(height: 7),
        Text(
          label,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: isCurrent ? AppTheme.textPrimary : AppTheme.textSecondary,
            fontSize: 10,
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

    return _WorkspaceSection(
      title: 'Required Documents',
      icon: Icons.folder_outlined,
      trailing: TextButton.icon(
        onPressed: () =>
            context.go('/my-services/${Uri.encodeComponent(serviceCase.id)}'),
        label: const Text('View all'),
        icon: const Icon(Icons.chevron_right_rounded, size: 18),
        iconAlignment: IconAlignment.end,
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF155EEF),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
        ),
      ),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _DocumentCountBadge(
              count: serviceCase.uploadedDocuments,
              label: 'Pending',
              foreground: const Color(0xFF155EEF),
              background: const Color(0xFFEAF1FF),
            ),
            _DocumentCountBadge(
              count: serviceCase.pendingDocuments,
              label: 'Missing',
              foreground: const Color(0xFFE86F00),
              background: const Color(0xFFFFF1E3),
            ),
            _DocumentCountBadge(
              count: serviceCase.approvedDocuments,
              label: 'Approved',
              foreground: const Color(0xFF138A4B),
              background: const Color(0xFFE8F7EE),
            ),
            _DocumentCountBadge(
              count: serviceCase.rejectedDocuments,
              label: 'Rejected',
              foreground: const Color(0xFFC81E3A),
              background: const Color(0xFFFDECEF),
            ),
          ],
        ),
        const SizedBox(height: 17),
        Row(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 7,
                  backgroundColor: const Color(0xFFE9EDF5),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF3478F6),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Text(
              '$received of $total received',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        _ResponsiveActionRow(
          secondary: OutlinedButton.icon(
            onPressed: () => context.go(
              '/my-services/${Uri.encodeComponent(serviceCase.id)}',
            ),
            icon: const Icon(Icons.preview_outlined, size: 19),
            label: const Text('Preview Documents'),
            style: _workspaceOutlinedButtonStyle(),
          ),
          primary: FilledButton.icon(
            onPressed: () => context.go(
              '/my-services/${Uri.encodeComponent(serviceCase.id)}',
            ),
            icon: const Icon(Icons.rate_review_outlined, size: 19),
            label: const Text('Review Documents'),
            style: _workspaceFilledButtonStyle(),
          ),
        ),
      ],
    );
  }
}

class _PaymentsBlock extends StatelessWidget {
  const _PaymentsBlock({required this.serviceCase});

  final InternalServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    final receiptStatus = serviceCase.uploadedDocuments > 0
        ? 'Receipt may require review'
        : 'No uploaded receipt';

    return _WorkspaceSection(
      title: 'Payments',
      icon: Icons.payments_outlined,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final details = Column(
              children: [
                _InfoLine(
                  label: 'Payment context',
                  value: 'Linked to ${serviceCase.id}',
                ),
                _InfoLine(label: 'Receipt status', value: receiptStatus),
              ],
            );

            final action = OutlinedButton.icon(
              onPressed: () => context.go('/payments'),
              icon: const Icon(Icons.receipt_long_outlined, size: 19),
              label: const Text('Review Payment'),
              style: _workspaceOutlinedButtonStyle(),
            );

            if (constraints.maxWidth < 520) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  details,
                  const SizedBox(height: 9),
                  SizedBox(height: 46, child: action),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: details),
                const SizedBox(width: 18),
                SizedBox(width: 190, height: 46, child: action),
              ],
            );
          },
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
      title: 'Activity Timeline',
      icon: Icons.schedule_rounded,
      trailing: TextButton.icon(
        onPressed: () =>
            context.go('/my-services/${Uri.encodeComponent(serviceCase.id)}'),
        label: const Text('View all'),
        icon: const Icon(Icons.chevron_right_rounded, size: 18),
        iconAlignment: IconAlignment.end,
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF155EEF),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900),
        ),
      ),
      children: [
        _TimelineLine(
          label: 'Service request created',
          value: serviceCase.createdAt,
          color: const Color(0xFF3478F6),
          showConnector: true,
        ),
        _TimelineLine(
          label: 'Last case update',
          value: serviceCase.updatedAt,
          color: const Color(0xFFFF7A1A),
          showConnector: true,
        ),
        _TimelineLine(
          label: 'Current status: ${serviceCase.status}',
          value: _timelineSupportingText(serviceCase),
          color: AppTheme.primaryRed,
          showConnector: false,
        ),
      ],
    );
  }

  String _timelineSupportingText(InternalServiceCase item) {
    if (item.uploadedDocuments > 0) {
      return '${item.uploadedDocuments} uploaded document(s) awaiting action';
    }
    if (item.pendingDocuments > 0) {
      return '${item.pendingDocuments} required document(s) still missing';
    }
    return 'Service case is up to date';
  }
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
                foreground: AppTheme.primaryRed,
                background: AppTheme.primaryRed.withValues(alpha: 0.08),
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

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, this.value, this.customValue})
    : assert(value != null || customValue != null);

  final String label;
  final String? value;
  final Widget? customValue;

  @override
  Widget build(BuildContext context) {
    if (customValue == null &&
        (value == null || value!.trim().isEmpty || value == '-')) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 106,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                height: 1.35,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child:
                customValue ??
                Text(
                  value!,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12.5,
                    height: 1.35,
                    fontWeight: FontWeight.w800,
                  ),
                ),
          ),
        ],
      ),
    );
  }
}

class _ResponsiveActionRow extends StatelessWidget {
  const _ResponsiveActionRow({required this.secondary, required this.primary});

  final Widget secondary;
  final Widget primary;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 430) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 48, child: secondary),
              const SizedBox(height: 10),
              SizedBox(height: 48, child: primary),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: SizedBox(height: 48, child: secondary)),
            const SizedBox(width: 12),
            Expanded(child: SizedBox(height: 48, child: primary)),
          ],
        );
      },
    );
  }
}

class _TimelineLine extends StatelessWidget {
  const _TimelineLine({
    required this.label,
    required this.value,
    required this.color,
    required this.showConnector,
  });

  final String label;
  final String value;
  final Color color;
  final bool showConnector;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 22,
            child: Column(
              children: [
                Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withValues(alpha: 0.18),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.18),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
                if (showConnector)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: const Color(0xFFDDE3EC),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceBadge extends StatelessWidget {
  const _WorkspaceBadge({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    final safeLabel = label.trim().isEmpty ? 'Not set' : label.trim();

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Text(
          safeLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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

class _DocumentCountBadge extends StatelessWidget {
  const _DocumentCountBadge({
    required this.count,
    required this.label,
    required this.foreground,
    required this.background,
  });

  final int count;
  final String label;
  final Color foreground;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        child: Text(
          '$count $label',
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

ButtonStyle _workspaceOutlinedButtonStyle() {
  return OutlinedButton.styleFrom(
    foregroundColor: AppTheme.primaryRed,
    side: const BorderSide(color: AppTheme.primaryRed, width: 1.2),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
  );
}

ButtonStyle _workspaceFilledButtonStyle() {
  return FilledButton.styleFrom(
    backgroundColor: AppTheme.primaryRed,
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
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
        color: AppTheme.primaryRed.withValues(alpha: 0.07),
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
                color: AppTheme.primaryRed,
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
          const Icon(Icons.inbox_rounded, color: AppTheme.primaryRed, size: 34),
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
