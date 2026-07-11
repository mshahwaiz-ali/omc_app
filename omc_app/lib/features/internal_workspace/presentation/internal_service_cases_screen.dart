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

const List<String> _primaryFilters = [
  'All',
  'Attention',
  'In Progress',
  'Completed',
];

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

  String _primaryFilter = 'All';
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
    ref
        .read(internalServiceCaseFiltersProvider.notifier)
        .setFilters(InternalServiceCaseFilters(search: value));
  }

  Future<void> _showFilters() async {
    var temporaryStatus = _statusFilter;
    var temporaryDocument = _documentFilter;

    final result = await showModalBottomSheet<_FilterSelection>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return _AdvancedFilterSheet(
              statusFilter: temporaryStatus,
              documentFilter: temporaryDocument,
              onStatusChanged: (value) {
                setModalState(() => temporaryStatus = value);
              },
              onDocumentChanged: (value) {
                setModalState(() => temporaryDocument = value);
              },
            );
          },
        );
      },
    );

    if (!mounted || result == null) return;

    setState(() {
      _statusFilter = result.status;
      _documentFilter = result.document;
    });
  }

  @override
  Widget build(BuildContext context) {
    final queueAsync = ref.watch(internalServiceCasesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FB),
      body: Column(
        children: [
          const AppBackHeader(
            title: 'Cases',
            subtitle: 'Review and manage customer service cases',
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
                  final activeCount = queue.cases
                      .where((item) => !_isClosedStatus(item.status))
                      .length;
                  final attentionCount = queue.cases
                      .where(_needsAttention)
                      .length;

                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: _kCasesPadding,
                    children: [
                      _QueueHeadline(
                        activeCount: activeCount,
                        attentionCount: attentionCount,
                      ),
                      const SizedBox(height: 18),
                      _SearchBar(
                        controller: _searchController,
                        onChanged: _updateSearch,
                        onFilterPressed: _showFilters,
                        filtersActive:
                            _statusFilter != 'All' || _documentFilter != 'All',
                      ),
                      const SizedBox(height: 18),
                      _PrimaryFilters(
                        selected: _primaryFilter,
                        onSelected: (value) {
                          setState(() => _primaryFilter = value);
                        },
                      ),
                      const SizedBox(height: 18),
                      _QueueSummary(cases: visibleCases),
                      const SizedBox(height: 18),
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

    switch (_primaryFilter) {
      case 'Attention':
        result = result.where(_needsAttention);
      case 'In Progress':
        result = result.where((item) {
          final status = item.status.toLowerCase();
          return status.contains('progress') ||
              status.contains('review') ||
              status.contains('waiting');
        });
      case 'Completed':
        result = result.where((item) => _isClosedStatus(item.status));
      case 'All':
        break;
    }

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

class _QueueHeadline extends StatelessWidget {
  const _QueueHeadline({
    required this.activeCount,
    required this.attentionCount,
  });

  final int activeCount;
  final int attentionCount;

  @override
  Widget build(BuildContext context) {
    return Text(
      '$activeCount active cases  •  $attentionCount need attention',
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 14,
        height: 1.2,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.onFilterPressed,
    required this.filtersActive,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onFilterPressed;
  final bool filtersActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 66,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE1E5ED)),
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
          const Icon(Icons.search_rounded, size: 27, color: Color(0xFF564B4B)),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: const InputDecoration(
                hintText: 'Search customer, request ID or service',
                hintStyle: TextStyle(
                  color: Color(0xFF77717A),
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
          IconButton(
            onPressed: onFilterPressed,
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(
                  Icons.tune_rounded,
                  color: Color(0xFF564B4B),
                  size: 27,
                ),
                if (filtersActive)
                  const Positioned(
                    right: -1,
                    top: -1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppTheme.primaryRed,
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox(width: 8, height: 8),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
    );
  }
}

class _PrimaryFilters extends StatelessWidget {
  const _PrimaryFilters({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final item in _primaryFilters)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _PrimaryFilterChip(
                label: item,
                selected: selected == item,
                onTap: () => onSelected(item),
              ),
            ),
        ],
      ),
    );
  }
}

class _PrimaryFilterChip extends StatelessWidget {
  const _PrimaryFilterChip({
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
          ? AppTheme.primaryRed.withValues(alpha: 0.12)
          : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? AppTheme.primaryRed.withValues(alpha: 0.18)
                  : const Color(0xFFD9DCE4),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: AppTheme.primaryRed,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? AppTheme.primaryRed
                      : const Color(0xFF625B60),
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QueueSummary extends StatelessWidget {
  const _QueueSummary({required this.cases});

  final List<InternalServiceCase> cases;

  @override
  Widget build(BuildContext context) {
    final reviewCount = cases.fold<int>(
      0,
      (sum, item) => sum + item.uploadedDocuments,
    );
    final missingCount = cases.fold<int>(
      0,
      (sum, item) => sum + item.pendingDocuments,
    );

    return PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      child: Row(
        children: [
          Expanded(
            child: _SummaryItem(
              icon: Icons.folder_open_rounded,
              label: 'Cases',
              value: '${cases.length}',
              color: const Color(0xFF2464D8),
            ),
          ),
          const _SummaryDivider(),
          Expanded(
            child: _SummaryItem(
              icon: Icons.error_outline_rounded,
              label: 'Need review',
              value: '$reviewCount',
              color: const Color(0xFFE99812),
            ),
          ),
          const _SummaryDivider(),
          Expanded(
            child: _SummaryItem(
              icon: Icons.description_outlined,
              label: 'Missing',
              value: '$missingCount',
              color: AppTheme.primaryRed,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 54,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      color: const Color(0xFFD9DFE8),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.09),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Icon(icon, color: color, size: 23),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 19,
                  height: 1,
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

class _InternalCaseCard extends StatelessWidget {
  const _InternalCaseCard({required this.serviceCase});

  final InternalServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    final workspacePath =
        '/internal-workspace/service-cases/${Uri.encodeComponent(serviceCase.id)}';

    final tone = _statusTone(serviceCase.status);
    final totalDocuments =
        serviceCase.pendingDocuments +
        serviceCase.uploadedDocuments +
        serviceCase.approvedDocuments +
        serviceCase.rejectedDocuments;

    final receivedDocuments =
        serviceCase.uploadedDocuments +
        serviceCase.approvedDocuments +
        serviceCase.rejectedDocuments;

    final progress = totalDocuments <= 0
        ? (_isClosedStatus(serviceCase.status) ? 1.0 : 0.0)
        : (receivedDocuments / totalDocuments).clamp(0.0, 1.0);

    final percentage = (progress * 100).round();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: () => context.go(workspacePath),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE5E7ED)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x080B1633),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Stack(
            children: [
              if (_needsAttention(serviceCase))
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 4,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryRed,
                      borderRadius: BorderRadius.horizontal(
                        left: Radius.circular(24),
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CaseHeader(serviceCase: serviceCase, tone: tone),
                    const SizedBox(height: 16),
                    _DocumentProgressPanel(
                      serviceCase: serviceCase,
                      progress: progress,
                      percentage: percentage,
                      tone: tone,
                    ),
                    const SizedBox(height: 13),
                    _CaseTags(serviceCase: serviceCase),
                    const SizedBox(height: 13),
                    _NextStepRow(serviceCase: serviceCase),
                    if (_needsAttention(serviceCase) &&
                        serviceCase.canReviewDocuments) ...[
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: () => context.go(workspacePath),
                          icon: const Icon(
                            Icons.find_in_page_outlined,
                            size: 19,
                          ),
                          label: const Text('Review documents'),
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 13,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CaseHeader extends StatelessWidget {
  const _CaseHeader({required this.serviceCase, required this.tone});

  final InternalServiceCase serviceCase;
  final _CaseTone tone;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: tone.color.withValues(alpha: 0.09),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.person_outline_rounded,
            color: tone.color,
            size: 26,
          ),
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
                  fontSize: 17,
                  height: 1.1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                serviceCase.displayService,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF4E678D),
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                serviceCase.id,
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
        const SizedBox(width: 10),
        _StatusPill(label: serviceCase.status, tone: tone),
      ],
    );
  }
}

class _DocumentProgressPanel extends StatelessWidget {
  const _DocumentProgressPanel({
    required this.serviceCase,
    required this.progress,
    required this.percentage,
    required this.tone,
  });

  final InternalServiceCase serviceCase;
  final double progress;
  final int percentage;
  final _CaseTone tone;

  @override
  Widget build(BuildContext context) {
    final totalDocuments =
        serviceCase.pendingDocuments +
        serviceCase.uploadedDocuments +
        serviceCase.approvedDocuments +
        serviceCase.rejectedDocuments;

    final receivedDocuments =
        serviceCase.uploadedDocuments +
        serviceCase.approvedDocuments +
        serviceCase.rejectedDocuments;

    final completed = _isClosedStatus(serviceCase.status);

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: tone.color.withValues(alpha: 0.055),
        borderRadius: BorderRadius.circular(17),
      ),
      child: completed
          ? Row(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  color: tone.color,
                  size: 25,
                ),
                const SizedBox(width: 11),
                const Expanded(
                  child: Text(
                    'All documents received and approved',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textPrimary,
                ),
              ],
            )
          : Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.description_outlined,
                      color: tone.color,
                      size: 23,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        totalDocuments > 0
                            ? 'Documents: $receivedDocuments of $totalDocuments received'
                            : serviceCase.documentSummaryLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (serviceCase.pendingDocuments > 0)
                      _SmallCountPill(
                        label: '${serviceCase.pendingDocuments} missing',
                        color: AppTheme.primaryRed,
                      ),
                  ],
                ),
                const SizedBox(height: 11),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 7,
                          value: progress,
                          backgroundColor: const Color(0xFFDDE2EA),
                          valueColor: AlwaysStoppedAnimation<Color>(tone.color),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '$percentage%',
                      style: const TextStyle(
                        color: Color(0xFF4E678D),
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _CaseTags extends StatelessWidget {
  const _CaseTags({required this.serviceCase});

  final InternalServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (serviceCase.pendingDocuments > 0)
                _MiniTag(
                  icon: Icons.description_outlined,
                  label: '${serviceCase.pendingDocuments} missing',
                  color: AppTheme.primaryRed,
                ),
              if (serviceCase.uploadedDocuments > 0)
                _MiniTag(
                  icon: Icons.rate_review_outlined,
                  label: '${serviceCase.uploadedDocuments} review',
                  color: const Color(0xFFDB8A00),
                ),
              if (serviceCase.priority.trim().isNotEmpty &&
                  serviceCase.priority != '-')
                _MiniTag(
                  icon: Icons.flag_outlined,
                  label: serviceCase.priority,
                  color: _priorityColor(serviceCase.priority),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.schedule_rounded,
              size: 17,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(width: 5),
            Text(
              serviceCase.updatedAt,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NextStepRow extends StatelessWidget {
  const _NextStepRow({required this.serviceCase});

  final InternalServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    final text = _nextStep(serviceCase);
    final color = _statusTone(serviceCase.status).color;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.arrow_forward_rounded, color: color, size: 22),
        const SizedBox(width: 9),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                const TextSpan(
                  text: 'Next step: ',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                TextSpan(
                  text: text,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    height: 1.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.tone});

  final String label;
  final _CaseTone tone;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: tone.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tone.color,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallCountPill extends StatelessWidget {
  const _SmallCountPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdvancedFilterSheet extends StatelessWidget {
  const _AdvancedFilterSheet({
    required this.statusFilter,
    required this.documentFilter,
    required this.onStatusChanged,
    required this.onDocumentChanged,
  });

  final String statusFilter;
  final String documentFilter;
  final ValueChanged<String> onStatusChanged;
  final ValueChanged<String> onDocumentChanged;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD9DCE3),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Filter service requests',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 20),
              const _FilterLabel('Service status'),
              const SizedBox(height: 9),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in _statusFilters)
                    ChoiceChip(
                      label: Text(option),
                      selected: statusFilter == option,
                      onSelected: (_) => onStatusChanged(option),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              const _FilterLabel('Document state'),
              const SizedBox(height: 9),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in _documentFilters)
                    ChoiceChip(
                      label: Text(option),
                      selected: documentFilter == option,
                      onSelected: (_) => onDocumentChanged(option),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop(
                          const _FilterSelection(
                            status: 'All',
                            document: 'All',
                          ),
                        );
                      },
                      child: const Text('Clear'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(context).pop(
                          _FilterSelection(
                            status: statusFilter,
                            document: documentFilter,
                          ),
                        );
                      },
                      child: const Text('Apply filters'),
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

class _FilterLabel extends StatelessWidget {
  const _FilterLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _FilterSelection {
  const _FilterSelection({required this.status, required this.document});

  final String status;
  final String document;
}

class _CasesLoadingView extends StatelessWidget {
  const _CasesLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: _kCasesPadding,
      children: const [
        _LoadingBar(widthFactor: 0.48, height: 14),
        SizedBox(height: 20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppTheme.primaryRed.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LoadingBar(widthFactor: 0.70),
                    SizedBox(height: 9),
                    _LoadingBar(widthFactor: 0.45),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _LoadingBar(widthFactor: 1, height: 68),
        ],
      ),
    );
  }
}

class _LoadingBar extends StatelessWidget {
  const _LoadingBar({required this.widthFactor, this.height = 11});

  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppTheme.primaryRed.withValues(alpha: 0.06),
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
              const Icon(
                Icons.cloud_off_rounded,
                color: AppTheme.primaryRed,
                size: 34,
              ),
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

class _CaseTone {
  const _CaseTone(this.color);

  final Color color;
}

_CaseTone _statusTone(String status) {
  final clean = status.toLowerCase();

  if (_isClosedStatus(status)) {
    return const _CaseTone(Color(0xFF2E9B58));
  }

  if (clean.contains('progress') ||
      clean.contains('review') ||
      clean.contains('waiting')) {
    return const _CaseTone(Color(0xFF2865C7));
  }

  return const _CaseTone(AppTheme.primaryRed);
}

Color _priorityColor(String priority) {
  final clean = priority.toLowerCase();

  if (clean.contains('high') || clean.contains('urgent')) {
    return AppTheme.primaryRed;
  }

  if (clean.contains('low')) {
    return const Color(0xFF2E9B58);
  }

  return const Color(0xFFE18B00);
}

bool _needsAttention(InternalServiceCase item) {
  final status = item.status.toLowerCase();

  return item.pendingDocuments > 0 ||
      item.uploadedDocuments > 0 ||
      item.rejectedDocuments > 0 ||
      status.contains('review') ||
      status.contains('open');
}

String _nextStep(InternalServiceCase item) {
  final status = item.status.toLowerCase();

  if (_isClosedStatus(item.status)) {
    return 'Service request completed';
  }

  if (item.rejectedDocuments > 0) {
    return 'Resolve rejected documents';
  }

  if (item.pendingDocuments > 0) {
    return 'Request missing documents';
  }

  if (item.uploadedDocuments > 0) {
    return 'Review submitted documents';
  }

  if (status.contains('waiting') && status.contains('customer')) {
    return 'Waiting for customer response';
  }

  if (status.contains('waiting') && status.contains('payment')) {
    return 'Confirm customer payment';
  }

  if (status.contains('progress')) {
    return 'Continue service processing';
  }

  return 'Open workspace and review case';
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
