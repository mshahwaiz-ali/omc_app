import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/network/api_error.dart';
import '../../../core/widgets/app_back_header.dart';
import '../../../core/widgets/premium_card.dart';
import '../domain/internal_service_case.dart';
import 'internal_workspace_providers.dart';

const EdgeInsets _kCasesPadding = EdgeInsets.fromLTRB(20, 12, 20, 148);

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

  String _searchQuery = '';
  String _primaryFilter = 'All';
  String _statusFilter = 'All';
  String _documentFilter = 'All';

  @override
  void initState() {
    super.initState();

    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _updateSearch(String value) {
    setState(() => _searchQuery = value);
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
                      _CasesOverview(
                        activeCount: activeCount,
                        attentionCount: attentionCount,
                        visibleCount: visibleCases.length,
                      ),
                      const SizedBox(height: 14),
                      _SearchBar(
                        controller: _searchController,
                        onChanged: _updateSearch,
                        onFilterPressed: _showFilters,
                        filtersActive:
                            _statusFilter != 'All' || _documentFilter != 'All',
                      ),
                      const SizedBox(height: 14),
                      _PrimaryFilters(
                        selected: _primaryFilter,
                        onSelected: (value) {
                          setState(() => _primaryFilter = value);
                        },
                      ),
                      if (_statusFilter != 'All' ||
                          _documentFilter != 'All') ...[
                        const SizedBox(height: 12),
                        _AppliedFiltersNotice(
                          status: _statusFilter,
                          document: _documentFilter,
                          onClear: () {
                            setState(() {
                              _statusFilter = 'All';
                              _documentFilter = 'All';
                            });
                          },
                        ),
                      ],
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
    final query = _searchQuery.trim().toLowerCase();

    if (query.isNotEmpty) {
      result = result.where((item) {
        final searchable = [
          item.id,
          item.customerName,
          item.customerProfile,
          item.serviceTitle,
          item.status,
          item.priority,
        ].join(' ').toLowerCase();

        return searchable.contains(query);
      });
    }

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

class _CasesOverview extends StatelessWidget {
  const _CasesOverview({
    required this.activeCount,
    required this.attentionCount,
    required this.visibleCount,
  });

  final int activeCount;
  final int attentionCount;
  final int visibleCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 14, 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6E8ED)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFFF1F3F7),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.work_outline_rounded,
              size: 22,
              color: Color(0xFF35383F),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$visibleCount ${visibleCount == 1 ? 'case' : 'cases'} shown',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '$activeCount active  •  $attentionCount need attention',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (attentionCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E5),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$attentionCount priority',
                style: const TextStyle(
                  color: Color(0xFFA76100),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
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
      height: 54,
      padding: const EdgeInsets.only(left: 15, right: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE1E4EA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, size: 22, color: Color(0xFF6D7179)),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
              decoration: const InputDecoration(
                hintText: 'Search customer, case or service',
                hintStyle: TextStyle(
                  color: Color(0xFF8A8E96),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Material(
            color: filtersActive
                ? AppTheme.primaryRed.withValues(alpha: 0.08)
                : const Color(0xFFF2F3F6),
            borderRadius: BorderRadius.circular(13),
            child: InkWell(
              onTap: onFilterPressed,
              borderRadius: BorderRadius.circular(13),
              child: SizedBox(
                width: 42,
                height: 42,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      Icons.tune_rounded,
                      size: 21,
                      color: filtersActive
                          ? AppTheme.primaryRed
                          : const Color(0xFF555961),
                    ),
                    if (filtersActive)
                      const Positioned(
                        right: 8,
                        top: 8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppTheme.primaryRed,
                            shape: BoxShape.circle,
                          ),
                          child: SizedBox(width: 6, height: 6),
                        ),
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

class _PrimaryFilters extends StatelessWidget {
  const _PrimaryFilters({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 45,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFEDEFF3),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          for (final item in _primaryFilters)
            Expanded(
              child: _SegmentItem(
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

class _SegmentItem extends StatelessWidget {
  const _SegmentItem({
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
      color: selected ? Colors.white : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          alignment: Alignment.center,
          decoration: selected
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x0D111827),
                      blurRadius: 7,
                      offset: Offset(0, 2),
                    ),
                  ],
                )
              : null,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                color: selected
                    ? AppTheme.textPrimary
                    : const Color(0xFF727780),
                fontSize: 11,
                fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppliedFiltersNotice extends StatelessWidget {
  const _AppliedFiltersNotice({
    required this.status,
    required this.document,
    required this.onClear,
  });

  final String status;
  final String document;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final labels = <String>[
      if (status != 'All') status,
      if (document != 'All') document,
    ];

    return Row(
      children: [
        const Icon(
          Icons.filter_alt_outlined,
          size: 17,
          color: AppTheme.textSecondary,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            labels.join('  •  '),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        TextButton(
          onPressed: onClear,
          style: TextButton.styleFrom(
            foregroundColor: AppTheme.textPrimary,
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
          child: const Text(
            'Clear',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
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

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        onTap: () => context.go(workspacePath),
        borderRadius: BorderRadius.circular(19),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: const Color(0xFFE5E7EC)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x080B1633),
                blurRadius: 14,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _CaseHeader(serviceCase: serviceCase, tone: tone),
              const SizedBox(height: 14),
              _DocumentProgressPanel(
                serviceCase: serviceCase,
                progress: progress,
                receivedDocuments: receivedDocuments,
                totalDocuments: totalDocuments,
                tone: tone,
              ),
              const SizedBox(height: 12),
              _CaseMetaRow(serviceCase: serviceCase),
              const SizedBox(height: 12),
              _NextStepRow(serviceCase: serviceCase),
              if (_needsAttention(serviceCase) &&
                  serviceCase.canReviewDocuments) ...[
                const SizedBox(height: 12),
                _ReviewAction(onTap: () => context.go(workspacePath)),
              ],
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
          width: 43,
          height: 43,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F3F6),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            Icons.person_outline_rounded,
            color: tone.color,
            size: 22,
          ),
        ),
        const SizedBox(width: 11),
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
                  fontSize: 15,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                serviceCase.displayService,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF53647A),
                  fontSize: 12,
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
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _StatusPill(label: serviceCase.status, tone: tone),
      ],
    );
  }
}

class _DocumentProgressPanel extends StatelessWidget {
  const _DocumentProgressPanel({
    required this.serviceCase,
    required this.progress,
    required this.receivedDocuments,
    required this.totalDocuments,
    required this.tone,
  });

  final InternalServiceCase serviceCase;
  final double progress;
  final int receivedDocuments;
  final int totalDocuments;
  final _CaseTone tone;

  @override
  Widget build(BuildContext context) {
    final completed = _isClosedStatus(serviceCase.status);
    final percentage = (progress * 100).round();

    return Container(
      padding: const EdgeInsets.fromLTRB(13, 12, 13, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFEBEDF1)),
      ),
      child: completed
          ? Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF198754),
                  size: 21,
                ),
                const SizedBox(width: 9),
                const Expanded(
                  child: Text(
                    'Documents completed',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Color(0xFF858A92),
                ),
              ],
            )
          : Column(
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.description_outlined,
                      color: Color(0xFF59616D),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        totalDocuments > 0
                            ? '$receivedDocuments of $totalDocuments documents received'
                            : serviceCase.documentSummaryLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (serviceCase.pendingDocuments > 0)
                      Text(
                        '${serviceCase.pendingDocuments} missing',
                        style: const TextStyle(
                          color: Color(0xFFA76100),
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          minHeight: 5,
                          value: progress,
                          backgroundColor: const Color(0xFFE1E4E9),
                          valueColor: AlwaysStoppedAnimation<Color>(tone.color),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '$percentage%',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _CaseMetaRow extends StatelessWidget {
  const _CaseMetaRow({required this.serviceCase});

  final InternalServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    final hasPriority =
        serviceCase.priority.trim().isNotEmpty && serviceCase.priority != '-';

    return Row(
      children: [
        if (hasPriority)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            decoration: BoxDecoration(
              color: _priorityColor(
                serviceCase.priority,
              ).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.flag_outlined,
                  size: 14,
                  color: _priorityColor(serviceCase.priority),
                ),
                const SizedBox(width: 5),
                Text(
                  serviceCase.priority,
                  style: TextStyle(
                    color: _priorityColor(serviceCase.priority),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        const Spacer(),
        const Icon(
          Icons.schedule_rounded,
          size: 15,
          color: AppTheme.textSecondary,
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            serviceCase.updatedAt,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 27,
          height: 27,
          decoration: BoxDecoration(
            color: const Color(0xFFF0F2F5),
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(
            Icons.arrow_forward_rounded,
            size: 15,
            color: Color(0xFF555A63),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text.rich(
              TextSpan(
                children: [
                  const TextSpan(
                    text: 'Next: ',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  TextSpan(
                    text: _nextStep(serviceCase),
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              style: const TextStyle(fontSize: 11, height: 1.35),
            ),
          ),
        ),
      ],
    );
  }
}

class _ReviewAction extends StatelessWidget {
  const _ReviewAction({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF1F3F6),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          child: Row(
            children: [
              Icon(
                Icons.find_in_page_outlined,
                size: 18,
                color: Color(0xFF3E434B),
              ),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Review uploaded documents',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Color(0xFF777C84),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.tone});

  final String label;
  final _CaseTone tone;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 105),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: tone.color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: tone.color,
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
        ),
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
        margin: const EdgeInsets.fromLTRB(10, 10, 10, 12),
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD7DAE0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Filter cases',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Narrow the queue by service or document status.',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 20),
              const _FilterLabel('SERVICE STATUS'),
              const SizedBox(height: 9),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in _statusFilters)
                    _FilterOption(
                      label: option,
                      selected: statusFilter == option,
                      onTap: () => onStatusChanged(option),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              const _FilterLabel('DOCUMENT STATE'),
              const SizedBox(height: 9),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final option in _documentFilters)
                    _FilterOption(
                      label: option,
                      selected: documentFilter == option,
                      onTap: () => onDocumentChanged(option),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        Navigator.of(context).pop(
                          const _FilterSelection(
                            status: 'All',
                            document: 'All',
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.textPrimary,
                        backgroundColor: const Color(0xFFF0F2F5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Clear',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
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
                      style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.textPrimary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Apply filters',
                        style: TextStyle(fontWeight: FontWeight.w900),
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

class _FilterOption extends StatelessWidget {
  const _FilterOption({
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
          ? AppTheme.primaryRed.withValues(alpha: 0.08)
          : const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(
                  Icons.check_rounded,
                  size: 15,
                  color: AppTheme.primaryRed,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? AppTheme.primaryRed
                      : const Color(0xFF575C65),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
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
