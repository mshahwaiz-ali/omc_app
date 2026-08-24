import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/resilience/app_failure.dart';
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
      if (mounted) {
        _reload();
      }
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

    setState(() {
      _loadingMore = true;
    });

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
          if (seen.add(task.id)) {
            _tasks.add(task);
          }
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
    setState(() {
      _query = value;
    });

    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), _reload);
  }

  void _onStatusChanged(String value) {
    if (_statusFilter == value) return;

    _searchDebounce?.cancel();

    setState(() {
      _statusFilter = value;
    });

    _reload();
  }

  Future<void> _showPriorityFilter() async {
    var selected = _priorityFilter;

    final result = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Priority',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'Filter the ERP Task list by priority.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final priority in _priorities)
                        ChoiceChip(
                          selected: selected == priority,
                          label: Text(priority),
                          onSelected: (_) {
                            setSheetState(() {
                              selected = priority;
                            });
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop(selected);
                      },
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

    setState(() {
      _priorityFilter = result;
    });

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
      backgroundColor: const Color(0xFFF8FAFD),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
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

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _TasksPageHeader(
                  metaLabel: hasMore ? '${tasks.length}+' : '${tasks.length}',
                ),
                const SizedBox(height: 16),
                _SearchBar(
                  query: query,
                  onChanged: onQueryChanged,
                  onOpenFilters: onOpenPriorityFilter,
                  filtersActive: priorityFilter != 'All',
                ),
                const SizedBox(height: 12),
                _StatusTabs(
                  statuses: statuses,
                  selected: statusFilter,
                  onSelected: onStatusChanged,
                ),
                if (priorityFilter != 'All') ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                        Icons.flag_outlined,
                        size: 16,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Priority: $priorityFilter',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),
                if (tasks.isEmpty)
                  PremiumEmptyState(
                    icon: Icons.assignment_outlined,
                    title: hasFilters ? 'No matching tasks' : 'No tasks',
                    message: hasFilters
                        ? 'No ERP Task matches the current search or filters.'
                        : 'No ERP Tasks are currently available.',
                    actionLabel: hasFilters ? 'Clear filters' : null,
                    onAction: hasFilters ? onClearFilters : null,
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          hasMore
                              ? '${tasks.length} tasks loaded'
                              : '${tasks.length} '
                                    '${tasks.length == 1 ? 'task' : 'tasks'}',
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      if (hasFilters)
                        TextButton(
                          onPressed: onClearFilters,
                          child: const Text('Clear filters'),
                        ),
                    ],
                  ),
                if (tasks.isNotEmpty) const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        if (tasks.isNotEmpty)
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _TaskCard(task: tasks[index]),
                ),
                childCount: tasks.length,
              ),
            ),
          ),
        if (tasks.isNotEmpty && hasMore)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: OutlinedButton.icon(
                onPressed: loadingMore ? null : onLoadMore,
                icon: loadingMore
                    ? const SizedBox(
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.expand_more_rounded),
                label: Text(loadingMore ? 'Loading more...' : 'Load more'),
              ),
            ),
          ),
        const SliverToBoxAdapter(child: SizedBox(height: 154)),
      ],
    );
  }
}

class _TasksPageHeader extends StatelessWidget {
  const _TasksPageHeader({required this.metaLabel});

  final String metaLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TaskHeaderBackButton(
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/more');
            }
          },
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tasks',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: const Color(0xFF10182D),
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.7,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Read-only ERP Task tracking for internal staff.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        _TaskHeaderCountBadge(label: metaLabel),
      ],
    );
  }
}

class _TaskHeaderBackButton extends StatelessWidget {
  const _TaskHeaderBackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: const BorderSide(color: Color(0xFFE8ECF3)),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(15),
        child: const SizedBox(
          width: 46,
          height: 46,
          child: Icon(Icons.arrow_back_rounded, color: Color(0xFF111827)),
        ),
      ),
    );
  }
}

class _TaskHeaderCountBadge extends StatelessWidget {
  const _TaskHeaderCountBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 58),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: AppTheme.primarySoft,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _SearchBar extends StatefulWidget {
  const _SearchBar({
    required this.query,
    required this.onChanged,
    required this.onOpenFilters,
    required this.filtersActive,
  });

  final String query;
  final ValueChanged<String> onChanged;
  final VoidCallback onOpenFilters;
  final bool filtersActive;

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
  }

  @override
  void didUpdateWidget(covariant _SearchBar oldWidget) {
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
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            onChanged: widget.onChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search task ID, title or description...',
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
              filled: true,
              fillColor: Colors.white,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: Color(0xFFE5EAF1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: const BorderSide(color: AppTheme.primary),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: widget.filtersActive ? AppTheme.primarySoft : Colors.white,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: widget.onOpenFilters,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.filtersActive
                      ? AppTheme.primary.withValues(alpha: 0.3)
                      : const Color(0xFFE5EAF1),
                ),
              ),
              child: Icon(
                Icons.tune_rounded,
                color: widget.filtersActive
                    ? AppTheme.primary
                    : const Color(0xFF172033),
              ),
            ),
          ),
        ),
      ],
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
      child: Row(
        children: [
          for (final status in statuses) ...[
            ChoiceChip(
              selected: selected == status,
              label: Text(status),
              onSelected: (_) => onSelected(status),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task});

  final TaskItem task;

  @override
  Widget build(BuildContext context) {
    final contextText =
        [
              task.customerName,
              task.taskType,
              task.serviceRequest,
              task.supportTicket,
            ]
            .whereType<String>()
            .where((value) => value.trim().isNotEmpty)
            .join('  •  ');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: () {
          context.push('/tasks/${Uri.encodeComponent(task.id)}');
        },
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 15, 14, 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE9EDF3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primarySoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.task_alt_rounded,
                  color: AppTheme.primary,
                  size: 22,
                ),
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
                            task.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 15.5,
                              height: 1.25,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppTheme.textSecondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      task.id,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (contextText.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        contextText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _TaskStatusBadge(label: task.status),
                        _TaskMetadata(
                          icon: Icons.person_outline_rounded,
                          label: task.assignedTo.trim().isEmpty
                              ? 'Unassigned'
                              : task.assignedTo,
                        ),
                        _TaskMetadata(
                          icon: Icons.flag_outlined,
                          label: task.priority,
                        ),
                        if (task.dueDateLabel.trim().isNotEmpty)
                          _TaskMetadata(
                            icon: Icons.calendar_today_outlined,
                            label: task.dueDateLabel,
                            isAttention: _isOverdue(task),
                          ),
                      ],
                    ),
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

class _TaskStatusBadge extends StatelessWidget {
  const _TaskStatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final value = _normalise(label);

    final background = switch (value) {
      'completed' => const Color(0xFFE8F7EE),
      'cancelled' => const Color(0xFFF3F5F7),
      'overdue' => const Color(0xFFFDECEC),
      'working' => const Color(0xFFEAF2FF),
      _ => AppTheme.primarySoft,
    };

    final foreground = switch (value) {
      'completed' => const Color(0xFF15803D),
      'cancelled' => AppTheme.textSecondary,
      'overdue' => const Color(0xFFB42318),
      'working' => const Color(0xFF1D4ED8),
      _ => AppTheme.primary,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _TaskMetadata extends StatelessWidget {
  const _TaskMetadata({
    required this.icon,
    required this.label,
    this.isAttention = false,
  });

  final IconData icon;
  final String label;
  final bool isAttention;

  @override
  Widget build(BuildContext context) {
    final color = isAttention
        ? const Color(0xFFB42318)
        : AppTheme.textSecondary;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 180),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _TasksLoadingView extends StatelessWidget {
  const _TasksLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 154),
      children: const [
        _TasksPageHeader(metaLabel: '...'),
        SizedBox(height: 22),
        LinearProgressIndicator(minHeight: 3),
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
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 154),
      children: [
        const _TasksPageHeader(metaLabel: '!'),
        const SizedBox(height: 24),
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
