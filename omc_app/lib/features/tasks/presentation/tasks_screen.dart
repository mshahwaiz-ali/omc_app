import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
import '../../../app/theme.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/premium_card.dart';
import '../../../core/widgets/premium_empty_state.dart';
import '../data/task_item.dart';
import '../data/tasks_repository.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({this.openCreateOnLoad = false, super.key});

  /// Retained for route compatibility. Task creation is not available in OMC.
  final bool openCreateOnLoad;

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  static const _statuses = <String>[
    'All',
    'Open',
    'Working',
    'Overdue',
    'Completed',
    'Cancelled',
  ];

  static const _priorities = <String>[
    'All',
    'Low',
    'Normal',
    'Medium',
    'High',
    'Urgent',
  ];

  final _tasks = <TaskItem>[];
  String _query = '';
  String _statusFilter = 'All';
  String _priorityFilter = 'All';
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int? _nextStart;
  Object? _error;
  int _requestGeneration = 0;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _reload();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    final generation = ++_requestGeneration;
    setState(() {
      _loading = true;
      _loadingMore = false;
      _error = null;
    });

    try {
      final page = await ref
          .read(tasksRepositoryProvider)
          .fetchTasksPage(
            limitStart: 0,
            pageLength: 50,
            search: _query,
            status: _statusFilter,
            priority: _priorityFilter,
          );
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _tasks
          ..clear()
          ..addAll(page.tasks);
        _hasMore = page.hasMore;
        _nextStart = page.nextStart;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final nextStart = _nextStart;
    if (_loadingMore || !_hasMore || nextStart == null) return;
    final generation = _requestGeneration;
    setState(() => _loadingMore = true);

    try {
      final page = await ref
          .read(tasksRepositoryProvider)
          .fetchTasksPage(
            limitStart: nextStart,
            pageLength: 50,
            search: _query,
            status: _statusFilter,
            priority: _priorityFilter,
          );
      if (!mounted || generation != _requestGeneration) return;
      final seen = _tasks.map((task) => task.id).toSet();
      setState(() {
        for (final task in page.tasks) {
          if (seen.add(task.id)) _tasks.add(task);
        }
        _hasMore = page.hasMore;
        _nextStart = page.nextStart;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _error = error;
        _loadingMore = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_backendErrorMessage(error))));
    }
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value);
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _reload);
  }

  void _onStatusChanged(String value) {
    if (_statusFilter == value) return;
    _searchDebounce?.cancel();
    setState(() => _statusFilter = value);
    _reload();
  }

  Future<void> _showPriorityFilter() async {
    var selected = _priorityFilter;
    final result = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.xl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Priority filter',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'This filter is applied by the backend before paging.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: AppSpacing.xs,
                    children: [
                      for (final priority in _priorities)
                        ChoiceChip(
                          selected: selected == priority,
                          label: Text(priority),
                          onSelected: (_) =>
                              setSheetState(() => selected = priority),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(sheetContext).pop(selected),
                      child: const Text('Apply filter'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (!mounted || result == null || result == _priorityFilter) return;
    setState(() => _priorityFilter = result);
    await _reload();
  }

  void _clearFilters() {
    _searchDebounce?.cancel();
    setState(() {
      _query = '';
      _statusFilter = 'All';
      _priorityFilter = 'All';
    });
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        top: true,
        bottom: false,
        child: RefreshIndicator.adaptive(
          onRefresh: _reload,
          child: _loading && _tasks.isEmpty
              ? const _TasksLoadingView()
              : _error != null && _tasks.isEmpty
              ? _TasksErrorView(error: _error!, onRetry: _reload)
              : _TasksContent(
                  tasks: _tasks,
                  query: _query,
                  statusFilter: _statusFilter,
                  priorityFilter: _priorityFilter,
                  statuses: _statuses,
                  hasMore: _hasMore,
                  loadingMore: _loadingMore,
                  onQueryChanged: _onQueryChanged,
                  onStatusChanged: _onStatusChanged,
                  onOpenPriorityFilter: _showPriorityFilter,
                  onClearFilters: _clearFilters,
                  onLoadMore: _loadMore,
                ),
        ),
      ),
    );
  }
}

class _TasksContent extends StatelessWidget {
  const _TasksContent({
    required this.tasks,
    required this.query,
    required this.statusFilter,
    required this.priorityFilter,
    required this.statuses,
    required this.hasMore,
    required this.loadingMore,
    required this.onQueryChanged,
    required this.onStatusChanged,
    required this.onOpenPriorityFilter,
    required this.onClearFilters,
    required this.onLoadMore,
  });

  final List<TaskItem> tasks;
  final String query;
  final String statusFilter;
  final String priorityFilter;
  final List<String> statuses;
  final bool hasMore;
  final bool loadingMore;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onOpenPriorityFilter;
  final VoidCallback onClearFilters;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final hasFilters =
        query.trim().isNotEmpty ||
        statusFilter != 'All' ||
        priorityFilter != 'All';

    return LayoutBuilder(
      builder: (context, constraints) {
        final inset = AppLayout.pageInsetFor(constraints.maxWidth);
        final horizontal =
            constraints.maxWidth > AppLayout.generalMaxWidth + inset * 2
            ? (constraints.maxWidth - AppLayout.generalMaxWidth) / 2
            : inset;

        final leadingChildren = <Widget>[
          const _TasksPageHeader(),
          const SizedBox(height: AppSpacing.xl),
          _SearchAndPriority(
            query: query,
            onChanged: onQueryChanged,
            onOpenPriorityFilter: onOpenPriorityFilter,
            priorityFilter: priorityFilter,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('Status', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: AppSpacing.xs),
          _StatusTabs(
            statuses: statuses,
            selected: statusFilter,
            onSelected: onStatusChanged,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Search, status and priority filters are applied by the backend before paging.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
          ),
          if (hasFilters) ...[
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onClearFilters,
                child: const Text('Clear filters'),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          _ResultsHeading(count: tasks.length, hasMore: hasMore),
          const SizedBox(height: AppSpacing.sm),
          if (tasks.isEmpty)
            PremiumEmptyState(
              icon: Icons.assignment_outlined,
              title: hasFilters ? 'No matching tasks' : 'No tasks',
              message: hasFilters
                  ? 'No ERP Task matches the current backend search or filters.'
                  : 'No ERP Tasks are currently available.',
              actionLabel: hasFilters ? 'Clear filters' : null,
              onAction: hasFilters ? onClearFilters : null,
            ),
        ];

        return CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          slivers: [
            SliverPadding(
              padding: EdgeInsets.fromLTRB(horizontal, 18, horizontal, 0),
              sliver: SliverList(
                delegate: SliverChildListDelegate(leadingChildren),
              ),
            ),
            if (tasks.isNotEmpty)
              SliverPadding(
                padding: EdgeInsets.symmetric(horizontal: horizontal),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => Padding(
                      padding: EdgeInsets.only(
                        bottom: index == tasks.length - 1 ? 0 : AppSpacing.sm,
                      ),
                      child: _TaskCard(task: tasks[index]),
                    ),
                    childCount: tasks.length,
                  ),
                ),
              ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontal,
                tasks.isNotEmpty && hasMore ? AppSpacing.md : 0,
                horizontal,
                164,
              ),
              sliver: SliverToBoxAdapter(
                child: tasks.isNotEmpty && hasMore
                    ? SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: loadingMore ? null : onLoadMore,
                          icon: loadingMore
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.expand_more_rounded),
                          label: Text(
                            loadingMore
                                ? 'Loading more tasks'
                                : 'Load more tasks',
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TaskListView extends StatelessWidget {
  const _TaskListView({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final inset = AppLayout.pageInsetFor(constraints.maxWidth);
        final horizontal =
            constraints.maxWidth > AppLayout.generalMaxWidth + inset * 2
            ? (constraints.maxWidth - AppLayout.generalMaxWidth) / 2
            : inset;
        return ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: EdgeInsets.fromLTRB(horizontal, 18, horizontal, 164),
          children: children,
        );
      },
    );
  }
}

class _TasksPageHeader extends StatelessWidget {
  const _TasksPageHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Tasks', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'Read-only ERP Task tracking for internal staff.',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ],
    );
  }
}

class _SearchAndPriority extends StatefulWidget {
  const _SearchAndPriority({
    required this.query,
    required this.onChanged,
    required this.onOpenPriorityFilter,
    required this.priorityFilter,
  });

  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onOpenPriorityFilter;
  final String priorityFilter;

  @override
  State<_SearchAndPriority> createState() => _SearchAndPriorityState();
}

class _SearchAndPriorityState extends State<_SearchAndPriority> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
  }

  @override
  void didUpdateWidget(covariant _SearchAndPriority oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != widget.query) {
      _controller.value = TextEditingValue(
        text: widget.query,
        selection: TextSelection.collapsed(offset: widget.query.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = constraints.maxWidth < 360 || textScale >= 1.5;
        final search = TextField(
          controller: _controller,
          onChanged: widget.onChanged,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: 'Search tasks',
            hintText: 'Task ID, title or description',
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _controller.text.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Clear search',
                    onPressed: () {
                      _controller.clear();
                      widget.onChanged('');
                      setState(() {});
                    },
                    icon: const Icon(Icons.close_rounded),
                  ),
          ),
        );
        final priority = OutlinedButton.icon(
          onPressed: widget.onOpenPriorityFilter,
          icon: const Icon(Icons.flag_outlined),
          label: Text(
            widget.priorityFilter == 'All'
                ? 'Priority'
                : 'Priority: ${widget.priorityFilter}',
          ),
        );

        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              search,
              const SizedBox(height: AppSpacing.xs),
              priority,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: search),
            const SizedBox(width: AppSpacing.xs),
            priority,
          ],
        );
      },
    );
  }
}

class _StatusTabs extends StatelessWidget {
  const _StatusTabs({
    required this.statuses,
    required this.selected,
    required this.onSelected,
  });

  final List<String> statuses;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (final status in statuses) ...[
            ChoiceChip(
              selected: selected == status,
              label: Text(status),
              onSelected: (_) => onSelected(status),
            ),
            if (status != statuses.last) const SizedBox(width: AppSpacing.xs),
          ],
        ],
      ),
    );
  }
}

class _ResultsHeading extends StatelessWidget {
  const _ResultsHeading({required this.count, required this.hasMore});

  final int count;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            'Task queue',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            hasMore ? '$count loaded · more available' : '$count loaded',
            textAlign: TextAlign.end,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task});

  final TaskItem task;

  @override
  Widget build(BuildContext context) {
    final due = task.dueDateLabel.trim();
    final assigned = task.assignedTo.trim().isEmpty
        ? 'Unassigned'
        : task.assignedTo.trim();
    final contextRows = <_TaskContext>[
      if (task.customerName?.trim().isNotEmpty == true)
        _TaskContext('Customer', task.customerName!.trim()),
      if (task.taskType?.trim().isNotEmpty == true)
        _TaskContext('Type', task.taskType!.trim()),
      if (task.serviceRequest?.trim().isNotEmpty == true)
        _TaskContext('Service request', task.serviceRequest!.trim()),
      if (task.supportTicket?.trim().isNotEmpty == true)
        _TaskContext('Support ticket', task.supportTicket!.trim()),
    ];

    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      onTap: () => context.push('/tasks/${Uri.encodeComponent(task.id)}'),
      semanticLabel:
          '${task.title}. ${task.status}. Priority ${task.priority}. ${due.isNotEmpty ? 'Due $due.' : ''} Assigned $assigned. Open read-only task details.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(task.title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            task.id,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          _TaskStatusBadge(label: task.status),
          const SizedBox(height: AppSpacing.md),
          _DuePriorityRow(
            due: due,
            priority: task.priority,
            overdue: _isOverdue(task),
          ),
          const SizedBox(height: AppSpacing.md),
          _LabelValue(
            icon: Icons.person_outline_rounded,
            label: 'Assigned to',
            value: assigned,
          ),
          if (contextRows.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Divider(height: 1),
            ),
            Text(
              'Service context',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            for (var index = 0; index < contextRows.length; index++) ...[
              _LabelValue(
                icon: Icons.link_rounded,
                label: contextRows[index].label,
                value: contextRows[index].value,
              ),
              if (index != contextRows.length - 1)
                const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ],
      ),
    );
  }
}

class _DuePriorityRow extends StatelessWidget {
  const _DuePriorityRow({
    required this.due,
    required this.priority,
    required this.overdue,
  });

  final String due;
  final String priority;
  final bool overdue;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      _LabelValue(
        icon: Icons.calendar_today_outlined,
        label: 'Due',
        value: due.isEmpty ? 'Not added' : due,
        color: overdue ? AppTheme.danger : null,
      ),
      _LabelValue(
        icon: Icons.flag_outlined,
        label: 'Priority',
        value: priority.trim().isEmpty ? 'Not added' : priority,
      ),
    ];
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = constraints.maxWidth < 420 || textScale >= 1.5;
        if (stack) {
          return Column(
            children: [
              rows[0],
              const SizedBox(height: AppSpacing.sm),
              rows[1],
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: rows[0]),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: rows[1]),
          ],
        );
      },
    );
  }
}

class _LabelValue extends StatelessWidget {
  const _LabelValue({
    required this.icon,
    required this.label,
    required this.value,
    this.color,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppTheme.textPrimary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color ?? AppTheme.textSecondary),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: effectiveColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TaskContext {
  const _TaskContext(this.label, this.value);
  final String label;
  final String value;
}

class _TaskStatusBadge extends StatelessWidget {
  const _TaskStatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final value = _normalise(label);
    final (foreground, background) = switch (value) {
      'completed' => (AppTheme.success, AppTheme.successSoft),
      'cancelled' => (AppTheme.processing, AppTheme.processingSoft),
      'overdue' => (AppTheme.danger, AppTheme.dangerSoft),
      'working' => (AppTheme.info, AppTheme.infoSoft),
      _ => (AppTheme.processing, AppTheme.processingSoft),
    };

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: foreground.withValues(alpha: 0.24)),
        ),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelMedium?.copyWith(color: foreground),
        ),
      ),
    );
  }
}

class _TasksLoadingView extends StatelessWidget {
  const _TasksLoadingView();

  @override
  Widget build(BuildContext context) {
    return const _TaskListView(
      children: [
        _TasksPageHeader(),
        SizedBox(height: AppSpacing.xl),
        PremiumCard(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: Center(child: CircularProgressIndicator()),
        ),
      ],
    );
  }
}

class _TasksErrorView extends StatelessWidget {
  const _TasksErrorView({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _TaskListView(
      children: [
        const _TasksPageHeader(),
        const SizedBox(height: AppSpacing.xl),
        PremiumEmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Tasks unavailable',
          message: _backendErrorMessage(error),
          actionLabel: 'Try again',
          onAction: onRetry,
        ),
      ],
    );
  }
}

bool _isOverdue(TaskItem task) {
  final status = _normalise(task.status);
  if (status == 'overdue') return true;
  if (status == 'completed' || status == 'cancelled') return false;

  final parsed = DateTime.tryParse(task.dueDateLabel.trim());
  if (parsed == null) return false;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final due = DateTime(parsed.year, parsed.month, parsed.day);
  return due.isBefore(today);
}

String _normalise(String value) {
  return value.trim().toLowerCase().replaceAll('_', ' ');
}

String _backendErrorMessage(Object error) {
  return AppFailureClassifier.classify(
    error,
    fallbackTitle: 'Data unavailable',
    fallbackMessage: 'Could not load tasks right now. Please try again.',
  ).message;
}
