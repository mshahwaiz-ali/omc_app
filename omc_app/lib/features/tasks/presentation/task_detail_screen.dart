import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/network/api_error.dart';
import '../../../core/resilience/app_failure.dart';
import '../../../core/widgets/app_state.dart';
import '../../../core/widgets/omc_premium.dart';
import '../../../core/widgets/premium_card.dart';
import '../../auth/application/auth_controller.dart';
import '../data/task_item.dart';
import '../data/tasks_repository.dart';

class TaskDetailScreen extends ConsumerStatefulWidget {
  const TaskDetailScreen({super.key, required this.taskId});

  final String taskId;

  @override
  ConsumerState<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends ConsumerState<TaskDetailScreen> {
  bool _submitting = false;

  void _invalidateTask() {
    ref.invalidate(taskDetailProvider(widget.taskId));
    ref.invalidate(tasksProvider);
  }

  Future<void> _runMutation(Future<void> Function() action, String success) async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      await action();
      if (!mounted) return;
      _invalidateTask();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success)),
      );
    } on ApiError catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (error) {
      if (!mounted) return;
      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Task update failed',
        fallbackMessage: 'The task could not be updated. Please try again.',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _applyTransition(
    TaskItem task,
    StaffTaskTransition transition,
  ) async {
    String? remarks;
    if (transition.requiresRemarks) {
      remarks = await _promptRemarks(
        title: transition.label,
        message: 'Add a short reason before changing this work status.',
        required: true,
      );
      if (remarks == null) return;
    } else if (transition.status == 'Completed') {
      final confirmed = await _confirm(
        title: 'Complete task?',
        message:
            'This marks the operational task as complete. Service lifecycle authority remains on the service request.',
        actionLabel: 'Complete task',
      );
      if (!confirmed) return;
    }

    await _runMutation(
      () => ref.read(tasksRepositoryProvider).updateTaskStatus(
            taskId: task.id,
            status: transition.status,
            remarks: remarks,
          ),
      'Work status updated to ${transition.label}.',
    );
  }

  Future<void> _openReassign(TaskItem task) async {
    if (_submitting) return;
    List<TaskAssigneeOption> options;
    try {
      options = await ref
          .read(tasksRepositoryProvider)
          .fetchTaskAssigneeOptions();
    } catch (error) {
      if (!mounted) return;
      final failure = AppFailureClassifier.classify(
        error,
        fallbackTitle: 'Staff list unavailable',
        fallbackMessage: 'Eligible task assignees could not be loaded.',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(failure.message)),
      );
      return;
    }
    if (!mounted) return;

    final selected = await showModalBottomSheet<TaskAssigneeOption>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _AssigneeSheet(
        options: options,
        currentUser: task.assignedTo,
      ),
    );
    if (!mounted || selected == null) return;

    final remarks = await _promptRemarks(
      title: 'Reassign task',
      message: 'Optional note for ${selected.label}.',
      required: false,
    );
    if (!mounted || remarks == null) return;

    await _runMutation(
      () => ref.read(tasksRepositoryProvider).reassignTask(
            taskId: task.id,
            assignedTo: selected.user,
            remarks: remarks.isEmpty ? null : remarks,
          ),
      'Task assigned to ${selected.label}.',
    );
  }

  Future<void> _openPlan(TaskItem task) async {
    if (_submitting) return;
    final result = await showModalBottomSheet<_TaskPlanSelection>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _TaskPlanSheet(task: task),
    );
    if (!mounted || result == null) return;

    await _runMutation(
      () => ref.read(tasksRepositoryProvider).updateTaskPlan(
            taskId: task.id,
            priority: result.priority,
            expectedCompletionDate: result.expectedCompletionDate,
            remarks: result.remarks,
          ),
      'Task plan updated.',
    );
  }

  Future<String?> _promptRemarks({
    required String title,
    required String message,
    required bool required,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<String?>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                autofocus: true,
                minLines: 2,
                maxLines: 4,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: required ? 'Reason' : 'Note (optional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: required && controller.text.trim().isEmpty
                  ? null
                  : () => Navigator.of(dialogContext).pop(controller.text.trim()),
              child: const Text('Continue'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    return result;
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String actionLabel,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(actionLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final taskAsync = ref.watch(taskDetailProvider(widget.taskId));
    final capabilities = ref.watch(authControllerProvider).capabilities;

    return Scaffold(
      backgroundColor: OmcPremium.canvas,
      appBar: AppBar(title: const Text('Task')), 
      body: SafeArea(
        top: false,
        child: taskAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(20),
            children: [
              AppErrorState.fromError(
                error: error,
                onRetry: () => ref.invalidate(taskDetailProvider(widget.taskId)),
                fallbackTitle: 'Task unavailable',
                fallbackMessage: 'This task could not be loaded right now.',
              ),
            ],
          ),
          data: (task) {
            if (task == null) {
              return const _MissingTask();
            }

            final canManage =
                capabilities.canManageTasks && task.serverCanManageTasks;
            final canUpdateAssigned =
                capabilities.canManageAssignedTasks &&
                task.serverCanManageAssignedTasks;
            final canChangeStatus =
                task.allowedTransitions.isNotEmpty &&
                (canManage || canUpdateAssigned);

            return RefreshIndicator.adaptive(
              onRefresh: () async {
                _invalidateTask();
                await ref.read(taskDetailProvider(widget.taskId).future);
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                ),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                children: [
                  _TaskHero(task: task),
                  const SizedBox(height: 14),
                  if (canChangeStatus) ...[
                    _StatusActions(
                      transitions: task.allowedTransitions,
                      busy: _submitting,
                      onSelected: (transition) =>
                          _applyTransition(task, transition),
                    ),
                    const SizedBox(height: 14),
                  ],
                  if (canManage) ...[
                    _ManagerActions(
                      busy: _submitting,
                      onReassign: () => _openReassign(task),
                      onPlan: () => _openPlan(task),
                    ),
                    const SizedBox(height: 14),
                  ],
                  _TaskDetails(task: task),
                  if (task.description?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 14),
                    PremiumCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Work notes',
                            style: TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            task.description!.trim(),
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12.5,
                              height: 1.45,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (task.caseReference?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () => context.push(
                        '/internal-workspace/service-cases/'
                        '${Uri.encodeComponent(task.caseReference!.trim())}',
                      ),
                      icon: const Icon(Icons.folder_open_outlined),
                      label: const Text('Open linked service case'),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TaskHero extends StatelessWidget {
  const _TaskHero({required this.task});
  final TaskItem task;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(task.status);
    return PremiumCard(
      padding: const EdgeInsets.all(18),
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
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(Icons.task_alt_rounded, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 19,
                        height: 1.18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      task.id,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _Pill(label: task.status, color: color),
              _Pill(label: task.priority, color: OmcPremium.tasks),
              if (task.assignedTo?.trim().isNotEmpty == true)
                _Pill(
                  label: 'Assigned: ${task.assignedTo}',
                  color: OmcPremium.system,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusActions extends StatelessWidget {
  const _StatusActions({
    required this.transitions,
    required this.busy,
    required this.onSelected,
  });

  final List<StaffTaskTransition> transitions;
  final bool busy;
  final ValueChanged<StaffTaskTransition> onSelected;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Work status',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Only transitions allowed by the backend workflow are shown.',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: transitions
                .map(
                  (transition) => FilledButton.tonalIcon(
                    onPressed: busy ? null : () => onSelected(transition),
                    icon: Icon(_transitionIcon(transition.status), size: 17),
                    label: Text(transition.label),
                  ),
                )
                .toList(growable: false),
          ),
        ],
      ),
    );
  }
}

class _ManagerActions extends StatelessWidget {
  const _ManagerActions({
    required this.busy,
    required this.onReassign,
    required this.onPlan,
  });

  final bool busy;
  final VoidCallback onReassign;
  final VoidCallback onPlan;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Manage task',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onReassign,
                  icon: const Icon(Icons.person_search_rounded),
                  label: const Text('Reassign'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : onPlan,
                  icon: const Icon(Icons.event_note_rounded),
                  label: const Text('Plan'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TaskDetails extends StatelessWidget {
  const _TaskDetails({required this.task});
  final TaskItem task;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('Customer', task.customerName ?? '-'),
      ('Assigned to', task.assignedTo ?? 'Unassigned'),
      ('Due date', task.expectedCompletionDate ?? 'Not set'),
      ('Completed on', task.completedOn ?? '-'),
      ('Created', task.createdAt ?? '-'),
      ('Updated', task.updatedAt ?? '-'),
    ];

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Task details',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          for (var index = 0; index < rows.length; index++) ...[
            _DetailRow(label: rows[index].$1, value: rows[index].$2),
            if (index != rows.length - 1) const Divider(height: 18),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 94,
          child: Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _AssigneeSheet extends StatefulWidget {
  const _AssigneeSheet({required this.options, required this.currentUser});

  final List<TaskAssigneeOption> options;
  final String? currentUser;

  @override
  State<_AssigneeSheet> createState() => _AssigneeSheetState();
}

class _AssigneeSheetState extends State<_AssigneeSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final visible = widget.options.where((item) {
      if (query.isEmpty) return true;
      return '${item.label} ${item.user} ${item.primaryRole}'
          .toLowerCase()
          .contains(query);
    }).toList(growable: false);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reassign task',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Only approved OMC staff with task authority are listed.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              onChanged: (value) => setState(() => _query = value),
              decoration: const InputDecoration(
                hintText: 'Search staff',
                prefixIcon: Icon(Icons.search_rounded),
              ),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: visible.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final option = visible[index];
                  final current =
                      option.user.trim().toLowerCase() ==
                      widget.currentUser?.trim().toLowerCase();
                  return ListTile(
                    enabled: !current,
                    leading: const CircleAvatar(
                      child: Icon(Icons.person_outline_rounded),
                    ),
                    title: Text(option.label),
                    subtitle: Text(
                      [
                        option.user,
                        if (option.primaryRole.isNotEmpty) option.primaryRole,
                      ].join(' • '),
                    ),
                    trailing: current
                        ? const Text('Current')
                        : const Icon(Icons.chevron_right_rounded),
                    onTap: current
                        ? null
                        : () => Navigator.of(context).pop(option),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskPlanSelection {
  const _TaskPlanSelection({
    required this.priority,
    required this.expectedCompletionDate,
    required this.remarks,
  });

  final String priority;
  final String expectedCompletionDate;
  final String? remarks;
}

class _TaskPlanSheet extends StatefulWidget {
  const _TaskPlanSheet({required this.task});
  final TaskItem task;

  @override
  State<_TaskPlanSheet> createState() => _TaskPlanSheetState();
}

class _TaskPlanSheetState extends State<_TaskPlanSheet> {
  late String _priority;
  DateTime? _date;
  final _remarksController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final current = widget.task.priority.trim();
    _priority = const {'Low', 'Medium', 'High', 'Urgent'}.contains(current)
        ? current
        : 'Medium';
    _date = DateTime.tryParse(widget.task.expectedCompletionDate ?? '');
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Plan task',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _priority,
              decoration: const InputDecoration(
                labelText: 'Priority',
                prefixIcon: Icon(Icons.flag_outlined),
              ),
              items: const [
                DropdownMenuItem(value: 'Low', child: Text('Low')),
                DropdownMenuItem(value: 'Medium', child: Text('Medium')),
                DropdownMenuItem(value: 'High', child: Text('High')),
                DropdownMenuItem(value: 'Urgent', child: Text('Urgent')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _priority = value);
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final selected = await showDatePicker(
                  context: context,
                  initialDate: _date ?? DateTime.now(),
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 3650)),
                );
                if (selected != null) setState(() => _date = selected);
              },
              icon: const Icon(Icons.event_outlined),
              label: Text(
                _date == null ? 'Set due date' : 'Due ${_dateLabel(_date!)}',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _remarksController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Planning note (optional)',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(
                  _TaskPlanSelection(
                    priority: _priority,
                    expectedCompletionDate:
                        _date == null ? '' : _apiDate(_date!),
                    remarks: _remarksController.text.trim().isEmpty
                        ? null
                        : _remarksController.text.trim(),
                  ),
                ),
                child: const Text('Save task plan'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.13)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _MissingTask extends StatelessWidget {
  const _MissingTask();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'This task is no longer available.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

Color _statusColor(String status) {
  final value = status.trim().toLowerCase();
  if (value == 'completed') return OmcPremium.success;
  if (value == 'cancelled') return OmcPremium.system;
  if (value.contains('working') || value.contains('progress')) {
    return OmcPremium.track;
  }
  if (value.contains('overdue')) return OmcPremium.danger;
  return OmcPremium.tasks;
}

IconData _transitionIcon(String status) {
  switch (status.trim().toLowerCase()) {
    case 'working':
      return Icons.play_arrow_rounded;
    case 'pending review':
      return Icons.fact_check_outlined;
    case 'completed':
      return Icons.check_rounded;
    case 'cancelled':
      return Icons.close_rounded;
    default:
      return Icons.arrow_forward_rounded;
  }
}

String _apiDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '${value.year}-$month-$day';
}

String _dateLabel(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$day/$month/${value.year}';
}
