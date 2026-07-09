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
                        onFilterChanged: (value) => setState(() => _selectedFilter = value),
                      ),
                      const SizedBox(height: 14),
                      _OperationsSummary(area: widget.area, cases: cases),
                      const SizedBox(height: 16),
                      if (cases.isEmpty)
                        _OperationsEmpty(title: config.emptyTitle, message: config.emptyMessage)
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
      result = result.where((item) => _matchesAreaFilter(item, _selectedFilter));
    }

    return result.toList(growable: false);
  }

  bool _matchesAreaFilter(InternalServiceCase item, String filter) {
    switch (widget.area) {
      case InternalOperationArea.customers:
        if (filter == 'Has pending docs') return item.pendingDocuments > 0;
        if (filter == 'Has uploaded docs') return item.uploadedDocuments > 0;
        if (filter == 'Active') return !_isClosedStatus(item.status);
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
        if (filter == 'Overdue') return item.status.toLowerCase().contains('waiting');
        return true;
    }
  }
}

bool _isClosedStatus(String status) {
  final clean = status.toLowerCase();
  return clean.contains('complete') || clean.contains('cancel') || clean.contains('closed');
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
            onAction: () => context.go('/my-services/${Uri.encodeComponent(caseId)}'),
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
                          onAction: () => context.go('/my-services/${Uri.encodeComponent(caseId)}'),
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
                      _CustomerBlock(serviceCase: serviceCase),
                      const SizedBox(height: 14),
                      _StatusProgressBlock(serviceCase: serviceCase),
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
          filters: ['All', 'Active', 'Has pending docs', 'Has uploaded docs', 'Completed'],
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
          filters: ['Needs Review', 'Uploaded', 'Missing', 'Approved', 'Rejected', 'All'],
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
          filters: ['Pending', 'Receipt Uploaded', 'Received', 'Rejected', 'Overdue', 'All'],
          emptyTitle: 'No payments in this filter',
          emptyMessage: 'Use another filter or open service cases for payment actions.',
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
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            onChanged: onSearchChanged,
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: const Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final filter in filters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: selectedFilter == filter,
                      onSelected: (_) => onFilterChanged(filter),
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

class _OperationsSummary extends StatelessWidget {
  const _OperationsSummary({required this.area, required this.cases});

  final InternalOperationArea area;
  final List<InternalServiceCase> cases;

  @override
  Widget build(BuildContext context) {
    final uploaded = cases.fold<int>(0, (sum, item) => sum + item.uploadedDocuments);
    final pending = cases.fold<int>(0, (sum, item) => sum + item.pendingDocuments);
    final approved = cases.fold<int>(0, (sum, item) => sum + item.approvedDocuments);

    return Row(
      children: [
        Expanded(child: _OpsMetric(value: '${cases.length}', label: area == InternalOperationArea.customers ? 'Customers' : 'Services')),
        const SizedBox(width: 10),
        Expanded(child: _OpsMetric(value: '$uploaded', label: 'Uploaded')),
        const SizedBox(width: 10),
        Expanded(child: _OpsMetric(value: area == InternalOperationArea.payments ? '$pending' : '$approved', label: area == InternalOperationArea.payments ? 'Pending' : 'Approved')),
      ],
    );
  }
}

class _OpsMetric extends StatelessWidget {
  const _OpsMetric({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      child: Column(
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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

class _OperationsCaseCard extends StatelessWidget {
  const _OperationsCaseCard({required this.area, required this.serviceCase});

  final InternalOperationArea area;
  final InternalServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    final title = area == InternalOperationArea.payments
        ? 'Payment control'
        : area == InternalOperationArea.documents
            ? serviceCase.documentSummaryLabel
            : serviceCase.displayCustomer;
    final subtitle = area == InternalOperationArea.customers
        ? '${serviceCase.displayService} · ${serviceCase.id}'
        : '${serviceCase.displayCustomer} · ${serviceCase.displayService} · ${serviceCase.id}';

    return PremiumCard(
      onTap: () => context.go('/internal-workspace/service-cases/${Uri.encodeComponent(serviceCase.id)}'),
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
                      title,
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
              if (serviceCase.rejectedDocuments > 0) _MiniTag(label: '${serviceCase.rejectedDocuments} rejected'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.go('/internal-workspace/service-cases/${Uri.encodeComponent(serviceCase.id)}'),
                  icon: const Icon(Icons.visibility_outlined),
                  label: Text(area == InternalOperationArea.customers ? 'Open 360' : 'Open service'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => context.go('/my-services/${Uri.encodeComponent(serviceCase.id)}'),
                  icon: const Icon(Icons.rate_review_outlined),
                  label: Text(area == InternalOperationArea.payments ? 'Review' : 'Actions'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
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

class _ServiceWorkspaceHeader extends StatelessWidget {
  const _ServiceWorkspaceHeader({required this.serviceCase});

  final InternalServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  serviceCase.displayService,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.35,
                  ),
                ),
              ),
              _StatusPill(label: serviceCase.status),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            '${serviceCase.id} · ${serviceCase.displayCustomer}',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => context.go('/my-services/${Uri.encodeComponent(serviceCase.id)}'),
              icon: const Icon(Icons.admin_panel_settings_outlined),
              label: const Text('Open live review/actions'),
            ),
          ),
        ],
      ),
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
    return _WorkspaceSection(
      title: 'Status & Progress',
      icon: Icons.timeline_rounded,
      children: [
        _InfoLine(label: 'Current status', value: serviceCase.status),
        _InfoLine(label: 'Priority', value: serviceCase.priority),
        _InfoLine(label: 'Next step', value: _nextStep(serviceCase)),
      ],
    );
  }

  String _nextStep(InternalServiceCase item) {
    if (item.uploadedDocuments > 0) return 'Review uploaded customer documents';
    if (item.pendingDocuments > 0) return 'Ask customer for missing documents';
    if (!_isClosedStatus(item.status)) return 'Continue internal processing';
    return 'Case is closed or complete';
  }
}

class _DocumentsBlock extends StatelessWidget {
  const _DocumentsBlock({required this.serviceCase});

  final InternalServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    return _WorkspaceSection(
      title: 'Required Documents',
      icon: Icons.folder_copy_outlined,
      children: [
        _InfoLine(label: 'Summary', value: serviceCase.documentSummaryLabel),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _MiniTag(label: '${serviceCase.pendingDocuments} missing'),
            _MiniTag(label: '${serviceCase.uploadedDocuments} uploaded'),
            _MiniTag(label: '${serviceCase.approvedDocuments} approved'),
            _MiniTag(label: '${serviceCase.rejectedDocuments} rejected'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.go('/my-services/${Uri.encodeComponent(serviceCase.id)}'),
                icon: const Icon(Icons.preview_outlined),
                label: const Text('Preview'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => context.go('/my-services/${Uri.encodeComponent(serviceCase.id)}'),
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text('Review'),
              ),
            ),
          ],
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
    return _WorkspaceSection(
      title: 'Payments',
      icon: Icons.payments_outlined,
      children: [
        _InfoLine(label: 'Payment context', value: 'Linked to ${serviceCase.id}'),
        _InfoLine(label: 'Receipt status', value: serviceCase.uploadedDocuments > 0 ? 'Needs review if receipt is uploaded' : 'No uploaded receipt in queue summary'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => context.go('/payments'),
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Payments'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                onPressed: () => context.go('/my-services/${Uri.encodeComponent(serviceCase.id)}'),
                icon: const Icon(Icons.verified_outlined),
                label: const Text('Open case'),
              ),
            ),
          ],
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
      icon: Icons.history_rounded,
      children: [
        _TimelineLine(label: 'Case created', value: serviceCase.createdAt),
        _TimelineLine(label: 'Last updated', value: serviceCase.updatedAt),
        _TimelineLine(label: 'Current state', value: serviceCase.status),
      ],
    );
  }
}

class _WorkspaceSection extends StatelessWidget {
  const _WorkspaceSection({required this.title, required this.icon, required this.children});

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primaryRed, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    if (value.trim().isEmpty || value == '-') return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: AppTheme.textPrimary,
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

class _TimelineLine extends StatelessWidget {
  const _TimelineLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: const BoxDecoration(
              color: AppTheme.primaryRed,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: _InfoLine(label: label, value: value)),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.primaryRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: AppTheme.primaryRed,
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.primaryRed.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: const TextStyle(
            color: AppTheme.primaryRed,
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
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
  const _OperationsError({required this.title, required this.message, required this.onRetry});

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
              const Icon(Icons.cloud_off_rounded, color: AppTheme.primaryRed, size: 34),
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
