import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/app_back_header.dart';
import '../../../core/widgets/premium_card.dart';
import '../domain/internal_service_case.dart';
import 'internal_workspace_providers.dart';

const EdgeInsets _kCasesPadding = EdgeInsets.fromLTRB(20, 8, 20, 164);

const List<String> _statusFilters = [
  'All',
  'Active',
  'Open',
  'In Review',
  'In Progress',
  'Waiting Customer',
  'Waiting Payment',
  'Completed',
  'Cancelled',
];

const List<String> _documentFilters = [
  'All',
  'Needs Review',
  'Missing',
  'Approved',
  'Rejected',
];

class InternalServiceCasesScreen extends ConsumerStatefulWidget {
  const InternalServiceCasesScreen({super.key});

  @override
  ConsumerState<InternalServiceCasesScreen> createState() =>
      _InternalServiceCasesScreenState();
}

class _InternalServiceCasesScreenState
    extends ConsumerState<InternalServiceCasesScreen> {
  late final TextEditingController _searchController;
  String _statusFilter = 'All';
  String _documentFilter = 'All';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(
      text: ref.read(internalServiceCaseFiltersProvider).search,
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _updateSearch(String value) {
    ref.read(internalServiceCaseFiltersProvider.notifier).setFilters(
          InternalServiceCaseFilters(search: value),
        );
  }

  @override
  Widget build(BuildContext context) {
    final queueAsync = ref.watch(internalServiceCasesProvider);

    return Scaffold(
      body: Column(
        children: [
          const AppBackHeader(
            title: 'Service Requests',
            subtitle: 'Admin queue for customer-linked service work',
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () {
                ref.invalidate(internalServiceCasesProvider);
                return ref.read(internalServiceCasesProvider.future);
              },
              child: queueAsync.when(
                loading: () => const _CasesLoadingView(),
                error: (error, _) => _CasesErrorView(
                  message: _cleanErrorMessage(error),
                  onRetry: () => ref.invalidate(internalServiceCasesProvider),
                ),
                data: (queue) {
                  final visibleCases = _visibleCases(queue.cases);

                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: _kCasesPadding,
                    children: [
                      _SearchAndFilters(
                        controller: _searchController,
                        statusFilter: _statusFilter,
                        documentFilter: _documentFilter,
                        onSearchChanged: _updateSearch,
                        onStatusChanged: (value) =>
                            setState(() => _statusFilter = value),
                        onDocumentChanged: (value) =>
                            setState(() => _documentFilter = value),
                      ),
                      const SizedBox(height: 16),
                      _QueueSummary(cases: visibleCases),
                      const SizedBox(height: 16),
                      if (visibleCases.isEmpty)
                        const _EmptyCasesView()
                      else
                        for (final serviceCase in visibleCases)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _InternalCaseCard(serviceCase: serviceCase),
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

  List<InternalServiceCase> _visibleCases(List<InternalServiceCase> cases) {
    Iterable<InternalServiceCase> result = cases;

    if (_statusFilter != 'All') {
      result = result.where(_matchesStatusFilter);
    }

    if (_documentFilter != 'All') {
      result = result.where(_matchesDocumentFilter);
    }

    return result.toList(growable: false);
  }

  bool _matchesStatusFilter(InternalServiceCase item) {
    final status = item.status.toLowerCase();

    switch (_statusFilter) {
      case 'Active':
        return !_isClosedStatus(item.status);
      case 'Waiting Customer':
        return status.contains('waiting') && status.contains('customer');
      case 'Waiting Payment':
        return status.contains('waiting') && status.contains('payment');
      default:
        return status.contains(_statusFilter.toLowerCase());
    }
  }

  bool _matchesDocumentFilter(InternalServiceCase item) {
    switch (_documentFilter) {
      case 'Needs Review':
        return item.uploadedDocuments > 0;
      case 'Missing':
        return item.pendingDocuments > 0;
      case 'Approved':
        return item.approvedDocuments > 0;
      case 'Rejected':
        return item.rejectedDocuments > 0;
      default:
        return true;
    }
  }
}

class _SearchAndFilters extends StatelessWidget {
  const _SearchAndFilters({
    required this.controller,
    required this.statusFilter,
    required this.documentFilter,
    required this.onSearchChanged,
    required this.onStatusChanged,
    required this.onDocumentChanged,
  });

  final TextEditingController controller;
  final String statusFilter;
  final String documentFilter;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onDocumentChanged;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            onChanged: onSearchChanged,
            decoration: const InputDecoration(
              hintText: 'Search customer, service ID, CNIC, NTN or phone',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
          const SizedBox(height: 14),
          _FilterRow(
            title: 'Service status',
            selected: statusFilter,
            options: _statusFilters,
            onSelected: onStatusChanged,
          ),
          const SizedBox(height: 10),
          _FilterRow(
            title: 'Document state',
            selected: documentFilter,
            options: _documentFilters,
            onSelected: onDocumentChanged,
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.title,
    required this.selected,
    required this.options,
    required this.onSelected,
  });

  final String title;
  final String selected;
  final List<String> options;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final option in options)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(option),
                    selected: selected == option,
                    onSelected: (_) => onSelected(option),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QueueSummary extends StatelessWidget {
  const _QueueSummary({required this.cases});

  final List<InternalServiceCase> cases;

  @override
  Widget build(BuildContext context) {
    final uploadedDocuments = cases.fold<int>(
      0,
      (sum, item) => sum + item.uploadedDocuments,
    );
    final pendingDocuments = cases.fold<int>(
      0,
      (sum, item) => sum + item.pendingDocuments,
    );

    return Row(
      children: [
        Expanded(child: _SummaryPill(value: '${cases.length}', label: 'Cases')),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryPill(value: '$uploadedDocuments', label: 'Review'),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryPill(value: '$pendingDocuments', label: 'Missing'),
        ),
      ],
    );
  }
}

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.value, required this.label});

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

class _InternalCaseCard extends StatelessWidget {
  const _InternalCaseCard({required this.serviceCase});

  final InternalServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    final workspacePath =
        '/internal-workspace/service-cases/${Uri.encodeComponent(serviceCase.id)}';

    return PremiumCard(
      onTap: () => context.go(workspacePath),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.assignment_turned_in_rounded,
                  color: AppTheme.primaryRed,
                ),
              ),
              const SizedBox(width: 13),
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
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${serviceCase.displayService} · ${serviceCase.id}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusPill(label: serviceCase.status),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MiniTag(label: '${serviceCase.uploadedDocuments} review'),
              _MiniTag(label: '${serviceCase.pendingDocuments} missing'),
              _MiniTag(label: '${serviceCase.approvedDocuments} approved'),
              if (serviceCase.rejectedDocuments > 0)
                _MiniTag(label: '${serviceCase.rejectedDocuments} rejected'),
              if (serviceCase.priority.trim().isNotEmpty && serviceCase.priority != '-')
                _MiniTag(label: serviceCase.priority),
            ],
          ),
          const SizedBox(height: 12),
          _CaseInfoLine(
            icon: Icons.folder_copy_outlined,
            label: 'Documents',
            value: serviceCase.documentSummaryLabel,
          ),
          _CaseInfoLine(
            icon: Icons.update_rounded,
            label: 'Updated',
            value: serviceCase.updatedAt,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.go(workspacePath),
                  icon: const Icon(Icons.folder_open_outlined),
                  label: const Text('Open workspace'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => context.go(workspacePath),
                  icon: const Icon(Icons.rate_review_outlined),
                  label: const Text('Review'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CaseInfoLine extends StatelessWidget {
  const _CaseInfoLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
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
          Icon(icon, size: 17, color: AppTheme.primaryRed),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      height: 1.35,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  TextSpan(
                    text: value,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
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

class _CasesLoadingView extends StatelessWidget {
  const _CasesLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: _kCasesPadding,
      children: const [
        _LoadingCard(),
        SizedBox(height: 14),
        _LoadingCard(),
        SizedBox(height: 14),
        _LoadingCard(),
      ],
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppTheme.primaryRed.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LoadingBar(widthFactor: 0.75),
                SizedBox(height: 10),
                _LoadingBar(widthFactor: 0.50),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingBar extends StatelessWidget {
  const _LoadingBar({required this.widthFactor});

  final double widthFactor;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: 11,
        decoration: BoxDecoration(
          color: AppTheme.primaryRed.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _CasesErrorView extends StatelessWidget {
  const _CasesErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: _kCasesPadding,
      children: [
        PremiumCard(
          child: Column(
            children: [
              const Icon(Icons.cloud_off_rounded, color: AppTheme.primaryRed, size: 34),
              const SizedBox(height: 10),
              const Text(
                'Service requests unavailable',
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

class _EmptyCasesView extends StatelessWidget {
  const _EmptyCasesView();

  @override
  Widget build(BuildContext context) {
    return const PremiumCard(
      child: Column(
        children: [
          Icon(Icons.inbox_rounded, color: AppTheme.primaryRed, size: 34),
          SizedBox(height: 10),
          Text(
            'No matching service requests',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Adjust search or filters to find a customer service workspace.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

bool _isClosedStatus(String status) {
  final clean = status.toLowerCase();
  return clean.contains('complete') ||
      clean.contains('cancel') ||
      clean.contains('closed');
}

String _cleanErrorMessage(Object error) {
  if (error is ApiError && error.message.trim().isNotEmpty) {
    return error.message.trim();
  }

  final raw = error.toString().replaceFirst('ApiError:', '').trim();
  return raw.isEmpty ? 'The internal workspace could not load this data.' : raw;
}
