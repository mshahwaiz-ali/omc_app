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

  final bool openCreateOnLoad;

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  String _query = '';
  String _statusFilter = 'All';
  String _priorityFilter = 'All';

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(tasksProvider);
            await ref.read(tasksProvider.future);
          },
          child: tasksAsync.when(
            data: (tasks) => _TasksContent(
              tasks: tasks,
              query: _query,
              statusFilter: _statusFilter,
              priorityFilter: _priorityFilter,
              onQueryChanged: (value) {
                setState(() => _query = value);
              },
              onStatusChanged: (value) {
                setState(() => _statusFilter = value);
              },
              onOpenFilters: () => _showFilterSheet(tasks),
              onClearFilters: _clearFilters,
              onAddTask: null,
            ),
            loading: () => _TasksLoadingView(onAddTask: null),
            error: (error, _) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 150),
              children: [
                const _TasksPageHeader(
                  metaLabel: 'Unavailable',
                  onAddTask: null,
                ),
                const SizedBox(height: 28),
                PremiumEmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Tasks unavailable',
                  message: _backendErrorMessage(error),
                  actionLabel: 'Try again',
                  onAction: () => ref.invalidate(tasksProvider),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      _query = '';
      _statusFilter = 'All';
      _priorityFilter = 'All';
    });
  }

  Future<void> _showFilterSheet(List<TaskItem> tasks) async {
    var selectedStatus = _statusFilter;
    var selectedPriority = _priorityFilter;

    final result =
        await showModalBottomSheet<({String status, String priority})>(
          context: context,
          useSafeArea: true,
          showDragHandle: true,
          backgroundColor: Colors.white,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          builder: (sheetContext) {
            return StatefulBuilder(
              builder: (context, setSheetState) {
                const statuses = [
                  'All',
                  'Open',
                  'In Progress',
                  'Completed',
                  'Cancelled',
                ];
                const priorities = [
                  'All',
                  'Low',
                  'Normal',
                  'Medium',
                  'High',
                  'Urgent',
                ];

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Filter tasks',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 21,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Narrow the list by workflow status or priority.',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 22),
                      const _FilterLabel('Status'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final status in statuses)
                            _FilterChoice(
                              label: status,
                              count: status == 'All'
                                  ? tasks.length
                                  : tasks
                                        .where(
                                          (task) =>
                                              _normalise(task.status) ==
                                              _normalise(status),
                                        )
                                        .length,
                              selected: selectedStatus == status,
                              onTap: () {
                                setSheetState(() => selectedStatus = status);
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      const _FilterLabel('Priority'),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final priority in priorities)
                            _FilterChoice(
                              label: priority,
                              selected: selectedPriority == priority,
                              onTap: () {
                                setSheetState(
                                  () => selectedPriority = priority,
                                );
                              },
                            ),
                        ],
                      ),
                      const SizedBox(height: 26),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                setSheetState(() {
                                  selectedStatus = 'All';
                                  selectedPriority = 'All';
                                });
                              },
                              child: const Text('Reset'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton(
                              onPressed: () {
                                Navigator.of(sheetContext).pop((
                                  status: selectedStatus,
                                  priority: selectedPriority,
                                ));
                              },
                              child: const Text('Apply filters'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );

    if (result == null || !mounted) {
      return;
    }

    setState(() {
      _statusFilter = result.status;
      _priorityFilter = result.priority;
    });
  }
}

class _TasksContent extends StatelessWidget {
  const _TasksContent({
    required this.tasks,
    required this.query,
    required this.statusFilter,
    required this.priorityFilter,
    required this.onQueryChanged,
    required this.onStatusChanged,
    required this.onOpenFilters,
    required this.onClearFilters,
    required this.onAddTask,
  });

  final List<TaskItem> tasks;
  final String query;
  final String statusFilter;
  final String priorityFilter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onOpenFilters;
  final VoidCallback onClearFilters;
  final VoidCallback? onAddTask;

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTasks();
    final hasFilters =
        query.trim().isNotEmpty ||
        statusFilter != 'All' ||
        priorityFilter != 'All';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 154),
      children: [
        _TasksPageHeader(
          metaLabel: tasks.isEmpty ? 'Empty' : '${tasks.length}',
          onAddTask: onAddTask,
        ),
        if (tasks.isEmpty) ...[
          const SizedBox(height: 24),
          PremiumEmptyState(
            icon: Icons.assignment_outlined,
            title: 'No tasks yet',
            message: 'No ERP tasks are currently available for your account.',
            actionLabel: null,
            onAction: onAddTask,
          ),
        ] else ...[
          const SizedBox(height: 16),
          _SearchBar(
            query: query,
            onChanged: onQueryChanged,
            onOpenFilters: onOpenFilters,
            filtersActive: statusFilter != 'All' || priorityFilter != 'All',
          ),
          const SizedBox(height: 12),
          _StatusTabs(
            tasks: tasks,
            selected: statusFilter,
            onSelected: onStatusChanged,
          ),
          const SizedBox(height: 14),
          _TaskSummaryGrid(tasks: tasks),
          const SizedBox(height: 16),
          if (filtered.isEmpty)
            PremiumEmptyState(
              icon: Icons.filter_alt_off_rounded,
              title: 'No matching tasks',
              message:
                  'No task matches the current search and filter selection.',
              actionLabel: hasFilters ? 'Clear filters' : null,
              onAction: hasFilters ? onClearFilters : null,
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${filtered.length} ${filtered.length == 1 ? 'task' : 'tasks'}',
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
            const SizedBox(height: 8),
            for (final task in filtered) ...[
              _TaskCard(task: task),
              const SizedBox(height: 10),
            ],
          ],
        ],
      ],
    );
  }

  List<TaskItem> _filteredTasks() {
    final cleanQuery = query.trim().toLowerCase();

    return tasks
        .where((task) {
          if (statusFilter != 'All' &&
              _normalise(task.status) != _normalise(statusFilter)) {
            return false;
          }

          if (priorityFilter != 'All' &&
              _normalise(task.priority) != _normalise(priorityFilter)) {
            return false;
          }

          if (cleanQuery.isEmpty) {
            return true;
          }

          final haystack = [
            task.title,
            task.id,
            task.status,
            task.priority,
            task.assignedTo,
            task.customerProfile,
            task.serviceRequest,
            task.supportTicket,
          ].whereType<String>().join(' ').toLowerCase();

          return haystack.contains(cleanQuery);
        })
        .toList(growable: false);
  }
}

class _TasksPageHeader extends StatelessWidget {
  const _TasksPageHeader({required this.metaLabel, required this.onAddTask});

  final String? metaLabel;
  final VoidCallback? onAddTask;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
                      'Track assignments, deadlines and team priorities.',
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
            if (metaLabel != null) ...[
              const SizedBox(width: 10),
              _TaskHeaderCountBadge(label: metaLabel!),
            ],
          ],
        ),
        if (onAddTask != null) ...[
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: onAddTask,
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.add_rounded, size: 21),
            label: const Text(
              'Add task',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
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
      constraints: const BoxConstraints(minWidth: 66),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
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
    if (widget.query != _controller.text) {
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
            onChanged: (value) {
              widget.onChanged(value);
              setState(() {});
            },
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search task, assignee, status or case...',
              hintStyle: const TextStyle(
                color: Color(0xFF7B8AA4),
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: const Padding(
                padding: EdgeInsets.only(left: 8, right: 4),
                child: Icon(
                  Icons.search_rounded,
                  color: Color(0xFF172033),
                  size: 25,
                ),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 52,
                minHeight: 54,
              ),
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
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 18,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(color: Color(0xFFE5EAF1)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: const BorderSide(
                  color: AppTheme.primary,
                  width: 1.4,
                ),
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
                      ? AppTheme.primary.withValues(alpha: 0.28)
                      : const Color(0xFFE5EAF1),
                ),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(
                    Icons.tune_rounded,
                    color: widget.filtersActive
                        ? AppTheme.primary
                        : const Color(0xFF172033),
                  ),
                  if (widget.filtersActive)
                    const Positioned(
                      right: 10,
                      top: 10,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: SizedBox(width: 7, height: 7),
                      ),
                    ),
                ],
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
    required this.tasks,
    required this.selected,
    required this.onSelected,
  });

  final List<TaskItem> tasks;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    const statuses = ['All', 'Open', 'In Progress', 'Completed', 'Cancelled'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final status in statuses) ...[
            _StatusTab(
              label: status,
              count: status == 'All'
                  ? tasks.length
                  : tasks
                        .where(
                          (task) =>
                              _normalise(task.status) == _normalise(status),
                        )
                        .length,
              selected: selected == status,
              onTap: () => onSelected(status),
            ),
            const SizedBox(width: 9),
          ],
        ],
      ),
    );
  }
}

class _StatusTab extends StatelessWidget {
  const _StatusTab({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.primarySoft : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected
                  ? const Color(0xFFF3A7B8)
                  : const Color(0xFFE4E8EF),
            ),
          ),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFFE11D48)
                      : AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                constraints: const BoxConstraints(minWidth: 24),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: selected
                      ? const Color(0xFFE11D48)
                      : const Color(0xFFF0F2F5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$count',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? Colors.white : AppTheme.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TaskSummaryGrid extends StatelessWidget {
  const _TaskSummaryGrid({required this.tasks});

  final List<TaskItem> tasks;

  @override
  Widget build(BuildContext context) {
    int count(String status) {
      return tasks
          .where((task) => _normalise(task.status) == _normalise(status))
          .length;
    }

    final active = count('Open') + count('In Progress');
    final completed = count('Completed');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE9EDF3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _TaskStat(value: '${tasks.length}', label: 'Total'),
          ),
          const _TaskStatDivider(),
          Expanded(
            child: _TaskStat(value: '$active', label: 'Active'),
          ),
          const _TaskStatDivider(),
          Expanded(
            child: _TaskStat(value: '$completed', label: 'Completed'),
          ),
        ],
      ),
    );
  }
}

class _TaskStat extends StatelessWidget {
  const _TaskStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 21,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
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

class _TaskStatDivider extends StatelessWidget {
  const _TaskStatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 34, color: const Color(0xFFE9EDF3));
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task});

  final TaskItem task;

  @override
  Widget build(BuildContext context) {
    final contextText =
        [task.customerProfile, task.serviceRequest, task.supportTicket]
            .whereType<String>()
            .where((value) => value.trim().isNotEmpty)
            .join('  •  ');

    final status = task.status.trim().isEmpty ? 'Open' : task.status.trim();
    final priority = task.priority.trim().isEmpty
        ? 'Normal'
        : task.priority.trim();

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
                              letterSpacing: -0.15,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppTheme.textSecondary,
                          size: 21,
                        ),
                      ],
                    ),
                    if (contextText.isNotEmpty) ...[
                      const SizedBox(height: 5),
                      Text(
                        contextText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _TaskStatusBadge(label: status),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            task.id,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 11),
                    Wrap(
                      spacing: 14,
                      runSpacing: 8,
                      children: [
                        if (task.dueDateLabel.trim().isNotEmpty)
                          _TaskMetadata(
                            icon: Icons.calendar_today_outlined,
                            label: task.dueDateLabel,
                            isAttention: _isOverdue(task),
                          ),
                        _TaskMetadata(
                          icon: Icons.person_outline_rounded,
                          label: task.assignedTo.trim().isEmpty
                              ? 'Unassigned'
                              : task.assignedTo,
                        ),
                        _TaskMetadata(
                          icon: Icons.flag_outlined,
                          label: priority,
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
    final normalized = _normalise(label);
    final muted =
        normalized == 'completed' ||
        normalized == 'cancelled' ||
        normalized == 'canceled' ||
        normalized == 'closed';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: muted ? const Color(0xFFF3F5F7) : AppTheme.primarySoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: muted ? AppTheme.textSecondary : AppTheme.primary,
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
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 5),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 190),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: isAttention ? FontWeight.w700 : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _TasksLoadingView extends StatelessWidget {
  const _TasksLoadingView({required this.onAddTask});

  final VoidCallback? onAddTask;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 154),
      children: [
        _TasksPageHeader(metaLabel: 'Loading', onAddTask: onAddTask),
        const SizedBox(height: 22),
        const LinearProgressIndicator(minHeight: 3),
        const SizedBox(height: 22),
        for (var index = 0; index < 4; index++) ...[
          const _TaskLoadingCard(),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _TaskLoadingCard extends StatelessWidget {
  const _TaskLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 118,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0F2F5)),
      ),
      alignment: Alignment.center,
      child: const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2.3),
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
        color: AppTheme.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _FilterChoice extends StatelessWidget {
  const _FilterChoice({
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
    return ChoiceChip(
      selected: selected,
      onSelected: (_) => onTap(),
      label: Text(count == null ? label : '$label  $count'),
      selectedColor: AppTheme.primarySoft,
      side: BorderSide(
        color: selected
            ? AppTheme.primary.withValues(alpha: 0.28)
            : const Color(0xFFE4E8EF),
      ),
      labelStyle: TextStyle(
        color: selected ? AppTheme.primary : AppTheme.textPrimary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

bool _isOverdue(TaskItem task) {
  final status = _normalise(task.status);

  if (status == 'completed' ||
      status == 'cancelled' ||
      status == 'canceled' ||
      status == 'closed') {
    return false;
  }

  final parsed = DateTime.tryParse(task.dueDateLabel.trim());

  if (parsed == null) {
    return false;
  }

  final today = DateTime.now();
  final currentDate = DateTime(today.year, today.month, today.day);
  final dueDate = DateTime(parsed.year, parsed.month, parsed.day);

  return dueDate.isBefore(currentDate);
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
