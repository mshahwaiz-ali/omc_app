import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/network/api_error.dart';
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

    if (widget.openCreateOnLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showCreateTaskSheet();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFD),
      body: RefreshIndicator(
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
            onAddTask: _showCreateTaskSheet,
          ),
          loading: () => _TasksLoadingView(onAddTask: _showCreateTaskSheet),
          error: (error, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 150),
            children: [
              const _TasksPageHeader(metaLabel: 'Unavailable', onAddTask: null),
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

  Future<void> _showCreateTaskSheet() async {
    final titleController = TextEditingController();
    final assignedController = TextEditingController();
    final dueDateController = TextEditingController();
    final descriptionController = TextEditingController();

    var priority = 'Normal';
    var saving = false;
    DateTime? selectedDueDate;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Colors.white,
      barrierColor: Colors.black.withValues(alpha: 0.30),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> chooseDueDate() async {
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: selectedDueDate ?? now,
                firstDate: DateTime(now.year - 1),
                lastDate: DateTime(now.year + 5),
              );

              if (picked == null) {
                return;
              }

              selectedDueDate = picked;
              dueDateController.text = _apiDate(picked);
              setSheetState(() {});
            }

            Future<void> submit() async {
              if (saving) {
                return;
              }

              final title = titleController.text.trim();

              if (title.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Enter a task title before continuing.'),
                  ),
                );
                return;
              }

              setSheetState(() => saving = true);

              try {
                await ref
                    .read(tasksRepositoryProvider)
                    .createTask(
                      title: title,
                      priority: priority,
                      dueDate: dueDateController.text,
                      assignedTo: assignedController.text,
                      description: descriptionController.text,
                    );

                ref.invalidate(tasksProvider);

                if (!sheetContext.mounted) {
                  return;
                }

                Navigator.of(sheetContext).pop();

                if (!mounted) {
                  return;
                }

                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('Task created successfully.')),
                );
              } catch (error) {
                if (!mounted) {
                  return;
                }

                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(content: Text(_backendErrorMessage(error))),
                );
              } finally {
                if (sheetContext.mounted) {
                  setSheetState(() => saving = false);
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 2,
                bottom: MediaQuery.viewInsetsOf(context).bottom + 22,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Assign task',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Create and assign a trackable work item.',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: titleController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Task title',
                        hintText: 'What needs to be done?',
                        prefixIcon: Icon(Icons.task_alt_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: priority,
                      decoration: const InputDecoration(
                        labelText: 'Priority',
                        prefixIcon: Icon(Icons.flag_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Low', child: Text('Low')),
                        DropdownMenuItem(
                          value: 'Normal',
                          child: Text('Normal'),
                        ),
                        DropdownMenuItem(
                          value: 'Medium',
                          child: Text('Medium'),
                        ),
                        DropdownMenuItem(value: 'High', child: Text('High')),
                        DropdownMenuItem(
                          value: 'Urgent',
                          child: Text('Urgent'),
                        ),
                      ],
                      onChanged: saving
                          ? null
                          : (value) {
                              if (value != null) {
                                setSheetState(() => priority = value);
                              }
                            },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: dueDateController,
                      readOnly: true,
                      onTap: saving ? null : chooseDueDate,
                      decoration: InputDecoration(
                        labelText: 'Due date',
                        hintText: 'Select a date',
                        prefixIcon: const Icon(Icons.event_outlined),
                        suffixIcon: selectedDueDate == null
                            ? const Icon(Icons.keyboard_arrow_down_rounded)
                            : IconButton(
                                tooltip: 'Clear due date',
                                onPressed: saving
                                    ? null
                                    : () {
                                        selectedDueDate = null;
                                        dueDateController.clear();
                                        setSheetState(() {});
                                      },
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: assignedController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Assign to',
                        hintText: 'User email or account ID',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      minLines: 3,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'Add instructions or useful context',
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.notes_rounded),
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: saving ? null : submit,
                        icon: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.add_task_rounded),
                        label: Text(
                          saving ? 'Creating task...' : 'Create task',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    titleController.dispose();
    assignedController.dispose();
    dueDateController.dispose();
    descriptionController.dispose();
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
  final VoidCallback onAddTask;

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTasks();
    final hasFilters =
        query.trim().isNotEmpty ||
        statusFilter != 'All' ||
        priorityFilter != 'All';

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 154),
      children: [
        _TasksPageHeader(
          metaLabel: tasks.isEmpty ? 'Empty' : '${tasks.length}',
          onAddTask: onAddTask,
        ),
        const SizedBox(height: 18),
        _SearchBar(
          onChanged: onQueryChanged,
          onOpenFilters: onOpenFilters,
          filtersActive: statusFilter != 'All' || priorityFilter != 'All',
        ),
        const SizedBox(height: 16),
        _StatusTabs(
          tasks: tasks,
          selected: statusFilter,
          onSelected: onStatusChanged,
        ),
        const SizedBox(height: 18),
        _TaskSummaryGrid(tasks: tasks),
        const SizedBox(height: 20),
        if (tasks.isEmpty)
          PremiumEmptyState(
            icon: Icons.assignment_outlined,
            title: 'No tasks yet',
            message: 'Create the first assignment to start tracking team work.',
            actionLabel: 'Add task',
            onAction: onAddTask,
          )
        else if (filtered.isEmpty)
          PremiumEmptyState(
            icon: Icons.filter_alt_off_rounded,
            title: 'No matching tasks',
            message: 'No task matches the current search and filter selection.',
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
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (hasFilters)
                TextButton.icon(
                  onPressed: onClearFilters,
                  icon: const Icon(Icons.refresh_rounded, size: 17),
                  label: const Text('Clear'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          for (final task in filtered) ...[
            _TaskCard(task: task),
            const SizedBox(height: 12),
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

  final String metaLabel;
  final VoidCallback? onAddTask;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tasks',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 30,
                      height: 1,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Track assigned work, due dates and priorities.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFECEF),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                metaLabel,
                style: const TextStyle(
                  color: Color(0xFFD90429),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        if (onAddTask != null) ...[
          const SizedBox(height: 20),
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: onAddTask,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD90429),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 22),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              icon: const Icon(Icons.add_rounded),
              label: const Text(
                'Add task',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.onChanged,
    required this.onOpenFilters,
    required this.filtersActive,
  });

  final ValueChanged<String> onChanged;
  final VoidCallback onOpenFilters;
  final bool filtersActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE4E8EF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x09111827),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(width: 16),
          const Icon(
            Icons.search_rounded,
            color: AppTheme.textPrimary,
            size: 25,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              onChanged: onChanged,
              decoration: const InputDecoration(
                hintText: 'Search task, assignee, status or case...',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          Container(
            width: 44,
            height: 44,
            margin: const EdgeInsets.only(right: 7),
            decoration: BoxDecoration(
              color: filtersActive
                  ? const Color(0xFFFFECEF)
                  : const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: filtersActive
                    ? const Color(0xFFFFC9D2)
                    : const Color(0xFFE4E8EF),
              ),
            ),
            child: IconButton(
              tooltip: 'Task filters',
              onPressed: onOpenFilters,
              icon: Icon(
                Icons.tune_rounded,
                color: filtersActive
                    ? const Color(0xFFD90429)
                    : AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
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
      color: selected ? const Color(0xFFFFE6EA) : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? const Color(0xFFFFD0D7)
                  : const Color(0xFFE4E8EF),
            ),
          ),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFFD90429)
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
                      ? const Color(0xFFD90429)
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 12) / 2;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _SummaryCard(
              width: width,
              icon: Icons.assignment_outlined,
              count: count('Open'),
              label: 'Open',
              caption: 'Needs action',
              color: const Color(0xFFD90429),
              tint: const Color(0xFFFFE8EC),
            ),
            _SummaryCard(
              width: width,
              icon: Icons.track_changes_rounded,
              count: count('In Progress'),
              label: 'In Progress',
              caption: 'Active work',
              color: const Color(0xFF155EEF),
              tint: const Color(0xFFE9F0FF),
            ),
            _SummaryCard(
              width: width,
              icon: Icons.check_circle_outline_rounded,
              count: count('Completed'),
              label: 'Completed',
              caption: 'Finished',
              color: const Color(0xFF079455),
              tint: const Color(0xFFE8F7EF),
            ),
            _SummaryCard(
              width: width,
              icon: Icons.cancel_outlined,
              count: count('Cancelled'),
              label: 'Cancelled',
              caption: 'Closed',
              color: const Color(0xFF667085),
              tint: const Color(0xFFF0F1F3),
            ),
          ],
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.width,
    required this.icon,
    required this.count,
    required this.label,
    required this.caption,
    required this.color,
    required this.tint,
  });

  final double width;
  final IconData icon;
  final int count;
  final String label;
  final String caption;
  final Color color;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFF0F2F5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08111827),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 47,
            height: 47,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 25),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 23,
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
                    color: AppTheme.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  caption,
                  style: TextStyle(
                    color: color,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
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

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task});

  final TaskItem task;

  @override
  Widget build(BuildContext context) {
    final visual = _taskVisual(task);
    final contextText =
        [task.customerProfile, task.serviceRequest, task.supportTicket]
            .whereType<String>()
            .where((value) => value.trim().isNotEmpty)
            .join('  •  ');

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () {
          context.push('/tasks/${Uri.encodeComponent(task.id)}');
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 14, 15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF0F2F5)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x07111827),
                blurRadius: 22,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: visual.tint,
                      borderRadius: BorderRadius.circular(17),
                    ),
                    child: Icon(visual.icon, color: visual.color, size: 27),
                  ),
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: visual.color,
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
                              fontSize: 16,
                              height: 1.2,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        _PriorityPill(priority: task.priority),
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
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    const SizedBox(height: 9),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: visual.tint,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Text(
                        task.id,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: visual.color,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _TaskMetadata(
                          icon: Icons.radio_button_checked_rounded,
                          label: task.status.isEmpty ? 'Open' : task.status,
                          color: visual.color,
                        ),
                        if (task.dueDateLabel.trim().isNotEmpty)
                          _TaskMetadata(
                            icon: Icons.event_outlined,
                            label: task.dueDateLabel,
                            color: _isOverdue(task)
                                ? const Color(0xFFD90429)
                                : AppTheme.textSecondary,
                          ),
                        _TaskMetadata(
                          icon: Icons.person_outline_rounded,
                          label: task.assignedTo.trim().isEmpty
                              ? 'Unassigned'
                              : task.assignedTo,
                          color: AppTheme.textSecondary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 7),
              const Padding(
                padding: EdgeInsets.only(top: 17),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: AppTheme.textPrimary,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PriorityPill extends StatelessWidget {
  const _PriorityPill({required this.priority});

  final String priority;

  @override
  Widget build(BuildContext context) {
    final clean = priority.trim().isEmpty ? 'Normal' : priority.trim();
    final color = _priorityColor(clean);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        clean,
        style: TextStyle(
          color: color,
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
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 16),
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
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _TasksLoadingView extends StatelessWidget {
  const _TasksLoadingView({required this.onAddTask});

  final VoidCallback onAddTask;

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
      selectedColor: const Color(0xFFFFE6EA),
      side: BorderSide(
        color: selected ? const Color(0xFFFFC8D1) : const Color(0xFFE4E8EF),
      ),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFFD90429) : AppTheme.textPrimary,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

({IconData icon, Color color, Color tint}) _taskVisual(TaskItem task) {
  final status = _normalise(task.status);

  if (status == 'completed' || status == 'closed') {
    return (
      icon: Icons.check_circle_outline_rounded,
      color: const Color(0xFF079455),
      tint: const Color(0xFFE8F7EF),
    );
  }

  if (status == 'cancelled' || status == 'canceled') {
    return (
      icon: Icons.cancel_outlined,
      color: const Color(0xFF667085),
      tint: const Color(0xFFF0F1F3),
    );
  }

  if (status == 'in progress' || status == 'working') {
    return (
      icon: Icons.track_changes_rounded,
      color: const Color(0xFF155EEF),
      tint: const Color(0xFFE9F0FF),
    );
  }

  final priority = _normalise(task.priority);

  if (priority == 'urgent' || priority == 'high') {
    return (
      icon: Icons.assignment_late_outlined,
      color: const Color(0xFFD90429),
      tint: const Color(0xFFFFE8EC),
    );
  }

  return (
    icon: Icons.assignment_outlined,
    color: const Color(0xFF7F56D9),
    tint: const Color(0xFFF2ECFF),
  );
}

Color _priorityColor(String priority) {
  switch (_normalise(priority)) {
    case 'urgent':
      return const Color(0xFFD90429);
    case 'high':
      return const Color(0xFFE5484D);
    case 'medium':
    case 'normal':
      return const Color(0xFFF26A21);
    case 'low':
      return const Color(0xFF079455);
    default:
      return const Color(0xFF667085);
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

String _apiDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}

String _normalise(String value) {
  return value.trim().toLowerCase().replaceAll('_', ' ');
}

String _backendErrorMessage(Object error) {
  if (error is ApiError && error.message.trim().isNotEmpty) {
    return error.message.trim();
  }

  return 'Could not load tasks right now. Please try again.';
}
