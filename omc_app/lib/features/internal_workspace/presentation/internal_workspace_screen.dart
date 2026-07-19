import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_empty_state.dart';
import '../domain/internal_service_case.dart';
import '../domain/internal_workspace_summary.dart';
import 'internal_workspace_providers.dart';

const EdgeInsets _kShellPagePadding = EdgeInsets.fromLTRB(20, 18, 20, 164);
const Color _ink = Color(0xFF111827);
const Color _slate = Color(0xFF64748B);
const Color _rose = Color(0xFFE11D48);
const Color _orange = Color(0xFFF97316);
const Color _green = Color(0xFF16A34A);
const Color _purple = Color(0xFF7C3AED);

class InternalWorkspaceScreen extends ConsumerWidget {
  const InternalWorkspaceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(internalWorkspaceSummaryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      body: RefreshIndicator(
        onRefresh: () {
          ref.invalidate(internalWorkspaceSummaryProvider);
          ref.invalidate(internalServiceCasesProvider);
          return ref.read(internalWorkspaceSummaryProvider.future);
        },
        child: summaryAsync.when(
          data: (summary) => _InternalWorkspaceContent(summary: summary),
          loading: () => const _InternalWorkspaceLoading(),
          error: (error, _) => _InternalWorkspaceUnavailable(
            message: _backendErrorMessage(error),
            onRetry: () => ref.invalidate(internalWorkspaceSummaryProvider),
          ),
        ),
      ),
    );
  }
}

String _backendErrorMessage(Object error) {
  return AppFailureClassifier.classify(
    error,
    fallbackTitle: 'Data unavailable',
    fallbackMessage:
        'Could not load internal workspace summary from the backend right now.',
  ).message;
}

class _InternalWorkspaceUnavailable extends StatelessWidget {
  const _InternalWorkspaceUnavailable({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: _kShellPagePadding,
      children: [
        PremiumEmptyState(
          icon: Icons.dashboard_customize_rounded,
          title: 'Workspace unavailable',
          message: message,
          actionLabel: 'Retry',
          onAction: onRetry,
        ),
      ],
    );
  }
}

class _InternalWorkspaceContent extends ConsumerWidget {
  const _InternalWorkspaceContent({required this.summary});

  final InternalWorkspaceSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueAsync = ref.watch(internalServiceCasesProvider);

    return Stack(
      children: [
        const Positioned.fill(child: _WorkspaceBackdrop()),
        ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: _kShellPagePadding,
          children: [
            _WorkspacePageHeader(
              onRefresh: () {
                ref.invalidate(internalWorkspaceSummaryProvider);
                ref.invalidate(internalServiceCasesProvider);
              },
            ),
            const SizedBox(height: 16),
            _CustomerSearchCard(
              onSearch: (value) {
                final query = value.trim();
                if (query.isEmpty) return;
                ref
                    .read(internalServiceCaseFiltersProvider.notifier)
                    .setFilters(InternalServiceCaseFilters(search: query));
                context.go('/internal-workspace/service-cases');
              },
            ),
            const SizedBox(height: 16),
            queueAsync.when(
              loading: () => const _LoadingPanel(height: 188),
              error: (_, _) => _OperationsSummaryCard(
                summary: summary,
                cases: const [],
                queueUnavailable: true,
              ),
              data: (queue) =>
                  _OperationsSummaryCard(summary: summary, cases: queue.cases),
            ),
            const SizedBox(height: 22),
            _SectionTitle(
              title: 'Priority Queue',
              actionLabel: 'View all',
              onAction: () => context.go('/internal-workspace/service-cases'),
            ),
            const SizedBox(height: 10),
            queueAsync.when(
              loading: () => const _PriorityQueueLoading(),
              error: (error, _) =>
                  _PriorityQueueFallback(message: _backendErrorMessage(error)),
              data: (queue) => _PriorityQueuePreview(
                items: _rankPriorityCases(queue.cases).take(3).toList(),
              ),
            ),
            const SizedBox(height: 22),
            const _SectionTitle(title: 'Work Queues'),
            const SizedBox(height: 12),
            queueAsync.when(
              loading: () => const _WorkQueuesLoading(),
              error: (_, _) => _WorkQueues(summary: summary, cases: const []),
              data: (queue) =>
                  _WorkQueues(summary: summary, cases: queue.cases),
            ),
            const SizedBox(height: 22),
            const _SectionTitle(title: 'Quick Actions'),
            const SizedBox(height: 12),
            const _QuickActions(),
          ],
        ),
      ],
    );
  }
}

class _WorkspacePageHeader extends StatelessWidget {
  const _WorkspacePageHeader({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Workspace',
                style: TextStyle(
                  color: _ink,
                  fontSize: 30,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.7,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Cases, customers and daily operations',
                style: TextStyle(
                  color: _slate,
                  fontSize: 13.5,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Material(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: const BorderSide(color: Color(0xFFE5EAF1)),
          ),
          child: IconButton(
            tooltip: 'Refresh workspace',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, color: _ink),
          ),
        ),
      ],
    );
  }
}

class _WorkspaceBackdrop extends StatelessWidget {
  const _WorkspaceBackdrop();
  @override
  Widget build(BuildContext context) => const DecoratedBox(
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFDFEFF), Color(0xFFF6F8FC), Color(0xFFFAFBFD)],
      ),
    ),
  );
}

class _CustomerSearchCard extends StatefulWidget {
  const _CustomerSearchCard({required this.onSearch});

  final ValueChanged<String> onSearch;

  @override
  State<_CustomerSearchCard> createState() => _CustomerSearchCardState();
}

class _CustomerSearchCardState extends State<_CustomerSearchCard> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      child: TextField(
        controller: _controller,
        textInputAction: TextInputAction.search,
        onSubmitted: widget.onSearch,
        decoration: InputDecoration(
          hintText: 'Search customer, phone, CNIC, NTN or service...',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: IconButton(
            tooltip: 'Search',
            onPressed: () => widget.onSearch(_controller.text),
            icon: const Icon(Icons.tune_rounded),
          ),
        ),
      ),
    );
  }
}

class _OperationsSummaryCard extends StatelessWidget {
  const _OperationsSummaryCard({
    required this.summary,
    required this.cases,
    this.queueUnavailable = false,
  });

  final InternalWorkspaceSummary summary;
  final List<InternalServiceCase> cases;
  final bool queueUnavailable;

  @override
  Widget build(BuildContext context) {
    final activeCases = cases.where(_isOpenCase).length;
    final documentIssues = cases.fold<int>(
      0,
      (total, item) => total + item.pendingDocuments + item.rejectedDocuments,
    );
    final needsAttention =
        cases.where(_caseNeedsAttention).length +
        documentIssues +
        summary.pendingPayments +
        summary.pendingTasks;

    return PremiumCard(
      padding: const EdgeInsets.fromLTRB(17, 17, 17, 14),
      onTap: () => context.go('/internal-workspace/service-cases'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(
                child: Text(
                  'Operations Today',
                  style: TextStyle(
                    color: _ink,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_rounded, size: 19, color: _slate),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  value: queueUnavailable ? '—' : '$activeCases',
                  label: 'Active cases',
                  color: _green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryMetric(
                  value: queueUnavailable ? '—' : '$needsAttention',
                  label: 'Need attention',
                  color: _rose,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFFE8ECF2)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _SummaryMetric(
                  value: '${summary.pendingPayments}',
                  label: 'Payments pending',
                  color: _orange,
                  compact: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryMetric(
                  value: '${summary.pendingTasks}',
                  label: 'Tasks due',
                  color: _purple,
                  compact: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          const Row(
            children: [
              Icon(Icons.view_list_rounded, size: 17, color: _slate),
              SizedBox(width: 7),
              Text(
                'Open full queue',
                style: TextStyle(
                  color: _ink,
                  fontSize: 13,
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

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.value,
    required this.label,
    required this.color,
    this.compact = false,
  });

  final String value;
  final String label;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: compact ? 8 : 10,
          height: compact ? 32 : 39,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  color: _ink,
                  fontSize: compact ? 20 : 25,
                  height: 1,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: _slate,
                  fontSize: 11.5,
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

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(onPressed: onAction, child: Text(actionLabel!)),
      ],
    );
  }
}

class _PriorityQueuePreview extends StatelessWidget {
  const _PriorityQueuePreview({required this.items});

  final List<InternalServiceCase> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const _PriorityQueueFallback(
        message: 'No service cases need attention in the current queue.',
      );
    }

    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _PriorityQueueTile(serviceCase: item),
          ),
      ],
    );
  }
}

class _PriorityQueueTile extends StatelessWidget {
  const _PriorityQueueTile({required this.serviceCase});

  final InternalServiceCase serviceCase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reason = _priorityReason(serviceCase);

    return PremiumCard(
      padding: const EdgeInsets.all(14),
      onTap: () => _openCase(context, serviceCase),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: reason.color.withValues(alpha: 0.09),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(reason.icon, color: reason.color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${serviceCase.displayCustomer} · ${serviceCase.displayService}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: _ink,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  serviceCase.id,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _slate,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${reason.label}${_waitingLabel(serviceCase)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: reason.color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: () => _openCase(context, serviceCase),
            style: OutlinedButton.styleFrom(
              foregroundColor: _ink,
              minimumSize: const Size(0, 38),
              padding: const EdgeInsets.symmetric(horizontal: 13),
              side: const BorderSide(color: Color(0xFFDCE2EA)),
            ),
            child: const Text('Review'),
          ),
        ],
      ),
    );
  }
}

void _openCase(BuildContext context, InternalServiceCase item) {
  context.go(
    '/internal-workspace/service-cases/${Uri.encodeComponent(item.id)}',
  );
}

class _PriorityQueueLoading extends StatelessWidget {
  const _PriorityQueueLoading();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        _LoadingPanel(height: 74),
        SizedBox(height: 10),
        _LoadingPanel(height: 74),
      ],
    );
  }
}

class _PriorityQueueFallback extends StatelessWidget {
  const _PriorityQueueFallback({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkQueues extends StatelessWidget {
  const _WorkQueues({required this.summary, required this.cases});

  final InternalWorkspaceSummary summary;
  final List<InternalServiceCase> cases;

  @override
  Widget build(BuildContext context) {
    final items = <_QueueItem>[
      _QueueItem(
        label: 'Service Cases',
        count: cases.where(_isOpenCase).length,
        icon: Icons.assignment_turned_in_rounded,
        color: _rose,
        route: '/internal-workspace/service-cases',
      ),
      _QueueItem(
        label: 'Documents',
        count: cases.fold<int>(
          0,
          (sum, item) => sum + item.pendingDocuments + item.rejectedDocuments,
        ),
        icon: Icons.folder_copy_rounded,
        color: _green,
        route: '/internal-workspace/documents',
      ),
      _QueueItem(
        label: 'Payments',
        count: summary.pendingPayments,
        icon: Icons.payments_rounded,
        color: _orange,
        route: '/internal-workspace/payments',
      ),
      _QueueItem(
        label: 'Customers',
        count: summary.activeCustomers,
        icon: Icons.groups_2_rounded,
        color: _purple,
        route: '/internal-workspace/customers',
      ),
      _QueueItem(
        label: 'Leads',
        count: summary.openLeads,
        icon: Icons.trending_up_rounded,
        color: const Color(0xFF2563EB),
        route: '/leads',
      ),
      _QueueItem(
        label: 'Tasks',
        count: summary.pendingTasks,
        icon: Icons.task_alt_rounded,
        color: const Color(0xFF0F9F8F),
        route: '/tasks',
      ),
    ];

    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.34,
      ),
      itemBuilder: (context, index) => _WorkQueueCard(item: items[index]),
    );
  }
}

class _QueueItem {
  const _QueueItem({
    required this.label,
    required this.count,
    required this.icon,
    required this.color,
    required this.route,
  });

  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final String route;
}

class _WorkQueueCard extends StatelessWidget {
  const _WorkQueueCard({required this.item});

  final _QueueItem item;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(14),
      onTap: () => context.go(item.route),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: item.color, size: 18),
              ),
              const Spacer(),
              const Icon(Icons.arrow_outward_rounded, color: _slate, size: 17),
            ],
          ),
          const Spacer(),
          Text(
            '${item.count}',
            style: const TextStyle(
              color: _ink,
              fontSize: 25,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: _slate,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkQueuesLoading extends StatelessWidget {
  const _WorkQueuesLoading();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: _LoadingPanel(height: 122)),
        SizedBox(width: 10),
        Expanded(child: _LoadingPanel(height: 122)),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final actions = <({String label, IconData icon, String route})>[
      (
        label: 'New service case',
        icon: Icons.add_circle_outline_rounded,
        route: '/services',
      ),
      (
        label: 'Customers',
        icon: Icons.person_search_rounded,
        route: '/internal-workspace/customers',
      ),
      (label: 'Leads', icon: Icons.add_chart_rounded, route: '/leads'),
      (
        label: 'Tasks',
        icon: Icons.playlist_add_check_circle_rounded,
        route: '/tasks',
      ),
    ];

    return SizedBox(
      height: 43,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: actions.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final action = actions[index];
          return OutlinedButton.icon(
            onPressed: () => context.go(action.route),
            icon: Icon(action.icon, size: 17),
            label: Text(action.label),
            style: OutlinedButton.styleFrom(
              foregroundColor: _ink,
              backgroundColor: Colors.white,
              side: const BorderSide(color: Color(0xFFDDE3EB)),
              padding: const EdgeInsets.symmetric(horizontal: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          );
        },
      ),
    );
  }
}

typedef _PriorityReason = ({String label, IconData icon, Color color});

List<InternalServiceCase> _rankPriorityCases(List<InternalServiceCase> cases) {
  final ranked = cases.where(_isOpenCase).toList();
  ranked.sort((a, b) {
    final score = _priorityScore(b).compareTo(_priorityScore(a));
    if (score != 0) return score;
    final aDate = _caseDate(a);
    final bDate = _caseDate(b);
    if (aDate == null && bDate == null) return 0;
    if (aDate == null) return 1;
    if (bDate == null) return -1;
    return aDate.compareTo(bDate);
  });
  return ranked;
}

int _priorityScore(InternalServiceCase item) {
  final priority = item.priority.toLowerCase();
  final status = item.status.toLowerCase();
  var score = 0;
  if (priority.contains('urgent')) {
    score += 100;
  } else if (priority.contains('high')) {
    score += 80;
  }
  if (item.rejectedDocuments > 0) score += 70;
  if (item.pendingDocuments > 0) score += 60;
  if (status.contains('review')) score += 45;
  if (status.contains('pending')) score += 30;
  if (status.contains('open')) score += 20;
  final date = _caseDate(item);
  if (date != null) {
    score += DateTime.now().difference(date).inDays.clamp(0, 30);
  }
  return score;
}

bool _caseNeedsAttention(InternalServiceCase item) {
  final priority = item.priority.toLowerCase();
  final status = item.status.toLowerCase();
  return priority.contains('urgent') ||
      priority.contains('high') ||
      item.pendingDocuments > 0 ||
      item.rejectedDocuments > 0 ||
      status.contains('review') ||
      status.contains('pending');
}

bool _isOpenCase(InternalServiceCase item) {
  final status = item.status.toLowerCase();
  return !status.contains('completed') &&
      !status.contains('closed') &&
      !status.contains('cancelled') &&
      !status.contains('canceled');
}

_PriorityReason _priorityReason(InternalServiceCase item) {
  final priority = item.priority.toLowerCase();
  final status = item.status.toLowerCase();

  if (item.rejectedDocuments > 0) {
    return (
      label:
          '${item.rejectedDocuments} rejected document${item.rejectedDocuments == 1 ? '' : 's'}',
      icon: Icons.error_outline_rounded,
      color: _rose,
    );
  }
  if (item.pendingDocuments > 0) {
    return (
      label: 'Missing documents',
      icon: Icons.description_outlined,
      color: _orange,
    );
  }
  if (priority.contains('urgent') || priority.contains('high')) {
    return (
      label: priority.contains('urgent') ? 'Urgent priority' : 'High priority',
      icon: Icons.priority_high_rounded,
      color: _rose,
    );
  }
  if (status.contains('review')) {
    return (
      label: 'Under review',
      icon: Icons.rate_review_outlined,
      color: _purple,
    );
  }
  if (status.contains('pending')) {
    return (
      label: item.status == '-' ? 'Pending action' : item.status,
      icon: Icons.schedule_rounded,
      color: _orange,
    );
  }
  return (
    label: item.status == '-' ? 'Open' : item.status,
    icon: Icons.inbox_outlined,
    color: _green,
  );
}

String _waitingLabel(InternalServiceCase item) {
  final date = _caseDate(item);
  if (date == null) return '';
  final days = DateTime.now().difference(date).inDays;
  if (days <= 0) return ' · updated today';
  if (days == 1) return ' · 1 day waiting';
  return ' · $days days waiting';
}

DateTime? _caseDate(InternalServiceCase item) {
  return DateTime.tryParse(item.updatedAt)?.toLocal() ??
      DateTime.tryParse(item.createdAt)?.toLocal();
}

// Reserved for the live activity feed once backend events are enabled.
// ignore: unused_element
class _ActivityPlaceholder extends StatelessWidget {
  const _ActivityPlaceholder({required this.onOpenCases});

  final VoidCallback onOpenCases;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Activity',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Activity timeline is ready in the UI structure. It will become live when backend activity events are exposed.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onOpenCases,
            icon: const Icon(Icons.assignment_rounded),
            label: const Text('Open service cases'),
          ),
        ],
      ),
    );
  }
}

class _InternalWorkspaceLoading extends StatelessWidget {
  const _InternalWorkspaceLoading();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: _kShellPagePadding,
      children: const [
        _LoadingPanel(height: 92),
        SizedBox(height: 14),
        _LoadingPanel(height: 78),
        SizedBox(height: 14),
        Row(
          children: [
            Expanded(child: _LoadingPanel(height: 92)),
            SizedBox(width: 10),
            Expanded(child: _LoadingPanel(height: 92)),
            SizedBox(width: 10),
            Expanded(child: _LoadingPanel(height: 92)),
          ],
        ),
        SizedBox(height: 18),
        _LoadingPanel(height: 74),
        SizedBox(height: 10),
        _LoadingPanel(height: 74),
      ],
    );
  }
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(24),
      ),
    );
  }
}
