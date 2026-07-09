import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_error.dart';
import '../../../core/widgets/premium_empty_state.dart';
import '../../../core/widgets/premium_info_chip.dart';
import '../../../core/widgets/premium_list_header.dart';
import '../../../core/widgets/premium_list_card.dart';
import '../data/task_item.dart';
import '../data/tasks_repository.dart';

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  String _query = '';
  String _statusFilter = 'All';

  @override
  Widget build(BuildContext context) {
    final tasksAsync = ref.watch(tasksProvider);

    return Scaffold(
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
            onQueryChanged: (value) => setState(() => _query = value),
            onStatusChanged: (value) => setState(() => _statusFilter = value),
            onAddTask: _showCreateTaskSheet,
          ),
          loading: () => _TasksLoadingView(onAddTask: _showCreateTaskSheet),
          error: (error, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              PremiumEmptyState(
                icon: Icons.error_outline_rounded,
                title: 'Tasks unavailable',
                message: _backendErrorMessage(error),
                actionLabel: 'Retry',
                onAction: () => ref.invalidate(tasksProvider),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateTaskSheet() async {
    final titleController = TextEditingController();
    final assignedController = TextEditingController();
    final dueDateController = TextEditingController();
    final descriptionController = TextEditingController();
    var priority = 'Normal';
    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> submit() async {
              if (saving) return;
              final title = titleController.text.trim();
              if (title.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Task title is required.')),
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
                if (!sheetContext.mounted) return;
                Navigator.of(sheetContext).pop();
                if (!context.mounted) return;
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Task created.')));
              } catch (error) {
                final message = _backendErrorMessage(error);
                if (!mounted) return;
                ScaffoldMessenger.of(
                  this.context,
                ).showSnackBar(SnackBar(content: Text(message)));
              } finally {
                if (mounted) setSheetState(() => saving = false);
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 18,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Add Task',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: titleController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Task title',
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: priority,
                      decoration: const InputDecoration(labelText: 'Priority'),
                      items: const [
                        DropdownMenuItem(value: 'Low', child: Text('Low')),
                        DropdownMenuItem(
                          value: 'Normal',
                          child: Text('Normal'),
                        ),
                        DropdownMenuItem(value: 'High', child: Text('High')),
                        DropdownMenuItem(
                          value: 'Urgent',
                          child: Text('Urgent'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setSheetState(() => priority = value);
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: dueDateController,
                      keyboardType: TextInputType.datetime,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Due date',
                        hintText: 'YYYY-MM-DD',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: assignedController,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Assigned to',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: descriptionController,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: saving ? null : submit,
                        icon: saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.add_rounded),
                        label: Text(saving ? 'Saving...' : 'Create task'),
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

String _backendErrorMessage(Object error) {
  if (error is ApiError && error.message.trim().isNotEmpty) {
    return error.message.trim();
  }

  return 'Could not load tasks right now. Please try again.';
}

class _TasksContent extends StatelessWidget {
  const _TasksContent({
    required this.tasks,
    required this.query,
    required this.statusFilter,
    required this.onQueryChanged,
    required this.onStatusChanged,
    required this.onAddTask,
  });

  final List<TaskItem> tasks;
  final String query;
  final String statusFilter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onStatusChanged;
  final VoidCallback onAddTask;

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTasks();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 164),
      children: [
        _HeaderWithAction(
          icon: Icons.task_alt_rounded,
          title: 'Tasks',
          subtitle: 'Track assigned work, due dates and priorities.',
          metaLabel: tasks.isEmpty
              ? 'Empty'
              : '${filtered.length}/${tasks.length}',
          actionLabel: 'Add task',
          onAction: onAddTask,
        ),
        const SizedBox(height: 14),
        _TaskFilters(
          query: query,
          statusFilter: statusFilter,
          onQueryChanged: onQueryChanged,
          onStatusChanged: onStatusChanged,
        ),
        const SizedBox(height: 14),
        if (tasks.isEmpty)
          PremiumEmptyState(
            icon: Icons.task_alt_rounded,
            title: 'No tasks yet',
            message:
                'Add the first work item or pull down to refresh backend data.',
            actionLabel: 'Add task',
            onAction: onAddTask,
          )
        else if (filtered.isEmpty)
          const PremiumEmptyState(
            icon: Icons.filter_alt_off_rounded,
            title: 'No matching tasks',
            message: 'Clear search or select another status filter.',
          )
        else
          for (final task in filtered) ...[
            _TaskCard(task: task),
            const SizedBox(height: 12),
          ],
      ],
    );
  }

  List<TaskItem> _filteredTasks() {
    final cleanQuery = query.trim().toLowerCase();
    return tasks
        .where((task) {
          if (statusFilter != 'All' &&
              task.status.toLowerCase() != statusFilter.toLowerCase()) {
            return false;
          }
          if (cleanQuery.isEmpty) return true;
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

class _HeaderWithAction extends StatelessWidget {
  const _HeaderWithAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.metaLabel,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String metaLabel;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PremiumListHeader(
          icon: icon,
          title: title,
          subtitle: subtitle,
          metaLabel: metaLabel,
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: onAction,
            icon: const Icon(Icons.add_rounded),
            label: Text(actionLabel),
          ),
        ),
      ],
    );
  }
}

class _TaskFilters extends StatelessWidget {
  const _TaskFilters({
    required this.query,
    required this.statusFilter,
    required this.onQueryChanged,
    required this.onStatusChanged,
  });

  final String query;
  final String statusFilter;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    const statuses = ['All', 'Open', 'In Progress', 'Completed', 'Cancelled'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          onChanged: onQueryChanged,
          decoration: const InputDecoration(
            hintText: 'Search task, assignee, status or case',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 10),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final status in statuses)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(status),
                    selected: statusFilter == status,
                    onSelected: (_) => onStatusChanged(status),
                  ),
                ),
            ],
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
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 164),
      children: [
        _HeaderWithAction(
          icon: Icons.task_alt_rounded,
          title: 'Tasks',
          subtitle: 'Track assigned work, due dates and priorities.',
          metaLabel: 'Loading',
          actionLabel: 'Add task',
          onAction: onAddTask,
        ),
        const SizedBox(height: 14),
        const LinearProgressIndicator(minHeight: 3),
      ],
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({required this.task});

  final TaskItem task;

  @override
  Widget build(BuildContext context) {
    return PremiumListCard(
      icon: Icons.task_alt_rounded,
      title: task.title,
      subtitle: task.id,
      trailing: PremiumInfoChip(
        label: task.priority.isEmpty ? 'Normal' : task.priority,
      ),
      onTap: () {
        context.push('/tasks/${Uri.encodeComponent(task.id)}');
      },
      children: [
        PremiumInfoChip(
          icon: Icons.radio_button_checked_rounded,
          label: task.status.isEmpty ? 'Open' : task.status,
        ),
        if (task.dueDateLabel.isNotEmpty)
          PremiumInfoChip(icon: Icons.event_rounded, label: task.dueDateLabel),
        if (task.assignedTo.isNotEmpty)
          PremiumInfoChip(icon: Icons.person_rounded, label: task.assignedTo),
        if (task.serviceRequest != null)
          PremiumInfoChip(
            icon: Icons.assignment_rounded,
            label: task.serviceRequest!,
          ),
      ],
    );
  }
}
