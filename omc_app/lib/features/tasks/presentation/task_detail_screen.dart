import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/mutation_invalidation.dart';
import '../../../core/forms/dirty_form_controller.dart';
import '../../../core/widgets/premium_empty_state.dart';
import '../../../core/widgets/app_back_header.dart';
import '../../auth/application/auth_controller.dart';
import '../../crm/presentation/widgets/crm_detail_widgets.dart';
import '../data/task_item.dart';
import '../data/tasks_repository.dart';

class TaskDetailScreen extends ConsumerWidget {
  const TaskDetailScreen({required this.taskId, super.key});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskAsync = ref.watch(taskDetailProvider(taskId));
    final capabilities = ref.watch(authControllerProvider).capabilities;
    final canManageTasks = capabilities.canManageTasks;
    final canUpdateStatus =
        canManageTasks || capabilities.canManageAssignedTasks;

    return Scaffold(
      appBar: const AppBackHeader(title: 'Task', fallbackRoute: '/tasks'),
      body: taskAsync.when(
        data: (task) {
          if (task == null) {
            return PremiumEmptyState(
              icon: Icons.task_alt_rounded,
              title: 'Task detail unavailable',
              message:
                  'Status updates, assignment and activity timeline will appear here when task details are available.',
            );
          }

          return _TaskDetailBody(
            task: task,
            onUpdateStatus: canUpdateStatus
                ? () => _showOperationStatusSheet(context, ref, task)
                : null,
            onManageTask: canManageTasks
                ? () => _showManagerTaskSheet(context, ref, task)
                : null,
          );
        },
        loading: () => const _TaskDetailLoadingView(),
        error: (_, _) => PremiumEmptyState(
          icon: Icons.task_alt_rounded,
          title: 'Task detail unavailable',
          message:
              'Task $taskId could not be loaded right now. Please try again.',
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(taskDetailProvider(taskId)),
        ),
      ),
    );
  }

  Future<void> _showOperationStatusSheet(
    BuildContext context,
    WidgetRef ref,
    TaskItem task,
  ) async {
    final transitions = task.allowedTransitions;
    if (transitions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No status actions are currently available.'),
        ),
      );
      return;
    }

    final selected = await showModalBottomSheet<TaskTransition>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          const Text(
            'Update operation status',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          for (final transition in transitions)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(transition.label),
              subtitle: transition.requiresConfirmation
                  ? const Text('Confirmation required')
                  : null,
              trailing: transition.terminal
                  ? const Icon(Icons.task_alt_rounded)
                  : const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(sheetContext).pop(transition),
            ),
        ],
      ),
    );

    if (selected == null || !context.mounted) {
      return;
    }

    if (selected.requiresConfirmation) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(selected.label),
          content: const Text(
            'This action will complete the linked ERP Task and may complete '
            'the service request after all blockers are validated.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Confirm'),
            ),
          ],
        ),
      );

      if (confirmed != true || !context.mounted) return;
    }

    try {
      await ref
          .read(tasksRepositoryProvider)
          .updateOperationStatus(
            taskId: task.id,
            operationStatus: selected.value,
          );
      invalidateTaskMutation(ref, taskId: task.id, caseId: task.serviceRequest);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Task status updated to ${selected.label}.')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Task status could not be updated: $error')),
      );
    }
  }

  Future<void> _showManagerTaskSheet(
    BuildContext context,
    WidgetRef ref,
    TaskItem task,
  ) async {
    TaskAssignmentOptions assignmentOptions;

    try {
      assignmentOptions = await ref.read(
        taskAssignmentOptionsProvider(task.id).future,
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Task assignment options could not be loaded: $error'),
        ),
      );
      return;
    }

    if (!context.mounted) return;

    final dueDateController = TextEditingController(text: task.dueDateLabel);
    final dirtyFormController = DirtyFormController();

    void markDirty() => dirtyFormController.markDirty();

    dueDateController.addListener(markDirty);

    var selectedAssignee = assignmentOptions.currentAssignee.isNotEmpty
        ? assignmentOptions.currentAssignee
        : task.assignedTo.trim();
    final availablePriorities = assignmentOptions.priorityOptions;
    var priority = availablePriorities.contains(task.priority.trim())
        ? task.priority.trim()
        : availablePriorities.isNotEmpty
        ? availablePriorities.first
        : task.priority.trim();
    var saving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> submit() async {
              if (saving) return;
              dirtyFormController.beginSubmitting();
              setSheetState(() => saving = true);

              try {
                final repository = ref.read(tasksRepositoryProvider);
                final cleanAssignee = selectedAssignee.trim();
                final cleanDueDate = dueDateController.text.trim();

                if (cleanAssignee.isNotEmpty &&
                    cleanAssignee != task.assignedTo.trim()) {
                  await repository.assignTask(
                    taskId: task.id,
                    assignedTo: cleanAssignee,
                  );
                }

                final planningChanged =
                    priority != task.priority.trim() ||
                    cleanDueDate != task.dueDateLabel.trim();

                if (planningChanged) {
                  await repository.updateTaskDetails(
                    taskId: task.id,
                    priority: priority,
                    dueDate: cleanDueDate,
                  );
                }

                invalidateTaskMutation(
                  ref,
                  taskId: task.id,
                  caseId: task.serviceRequest,
                );

                dirtyFormController.submissionSucceeded();
                if (!sheetContext.mounted) return;
                Navigator.of(sheetContext).pop();

                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Task planning updated.')),
                );
              } catch (error) {
                dirtyFormController.submissionFailed();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Task could not be updated: $error')),
                );
              } finally {
                if (sheetContext.mounted) {
                  setSheetState(() => saving = false);
                }
              }
            }

            return UnsavedChangesGuard(
              controller: dirtyFormController,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  4,
                  20,
                  MediaQuery.viewInsetsOf(context).bottom + 24,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Manage task',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue:
                            assignmentOptions.candidates.any(
                              (candidate) =>
                                  candidate.userId == selectedAssignee,
                            )
                            ? selectedAssignee
                            : null,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Assigned user',
                          hintText: 'Select an eligible staff member',
                        ),
                        items: assignmentOptions.candidates
                            .map(
                              (candidate) => DropdownMenuItem<String>(
                                value: candidate.userId,
                                child: Text(
                                  candidate.label,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(growable: false),
                        onChanged:
                            saving || assignmentOptions.candidates.isEmpty
                            ? null
                            : (value) {
                                if (value == null ||
                                    value == selectedAssignee) {
                                  return;
                                }
                                selectedAssignee = value;
                                dirtyFormController.markDirty();
                                setSheetState(() {});
                              },
                      ),
                      if (assignmentOptions.candidates.isEmpty) ...[
                        const SizedBox(height: 8),
                        const Text(
                          'No eligible internal staff members are currently available.',
                        ),
                      ],
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: priority,
                        decoration: const InputDecoration(
                          labelText: 'Priority',
                        ),
                        items: assignmentOptions.priorityOptions
                            .map(
                              (value) => DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: saving
                            ? null
                            : (value) {
                                if (value != null) {
                                  dirtyFormController.markDirty();
                                  setSheetState(() => priority = value);
                                }
                              },
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        controller: dueDateController,
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Due date',
                          hintText: 'Select a date',
                          suffixIcon: IconButton(
                            tooltip: 'Select due date',
                            icon: const Icon(Icons.calendar_month_rounded),
                            onPressed: saving
                                ? null
                                : () async {
                                    final currentValue = DateTime.tryParse(
                                      dueDateController.text.trim(),
                                    );

                                    final selectedDate = await showDatePicker(
                                      context: sheetContext,
                                      initialDate:
                                          currentValue ?? DateTime.now(),
                                      firstDate: DateTime.now(),
                                      lastDate: DateTime(
                                        DateTime.now().year + 5,
                                      ),
                                    );

                                    if (selectedDate == null) return;

                                    final formattedDate =
                                        '${selectedDate.year.toString().padLeft(4, '0')}-'
                                        '${selectedDate.month.toString().padLeft(2, '0')}-'
                                        '${selectedDate.day.toString().padLeft(2, '0')}';

                                    dueDateController.text = formattedDate;
                                    dirtyFormController.markDirty();
                                    setSheetState(() {});
                                  },
                          ),
                        ),
                        onTap: saving
                            ? null
                            : () async {
                                final currentValue = DateTime.tryParse(
                                  dueDateController.text.trim(),
                                );

                                final selectedDate = await showDatePicker(
                                  context: sheetContext,
                                  initialDate: currentValue ?? DateTime.now(),
                                  firstDate: DateTime.now(),
                                  lastDate: DateTime(DateTime.now().year + 5),
                                );

                                if (selectedDate == null) return;

                                final formattedDate =
                                    '${selectedDate.year.toString().padLeft(4, '0')}-'
                                    '${selectedDate.month.toString().padLeft(2, '0')}-'
                                    '${selectedDate.day.toString().padLeft(2, '0')}';

                                dueDateController.text = formattedDate;
                                dirtyFormController.markDirty();
                                setSheetState(() {});
                              },
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: saving ? null : submit,
                          icon: saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save_rounded),
                          label: Text(saving ? 'Saving...' : 'Save changes'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    dueDateController.removeListener(markDirty);
    dirtyFormController.dispose();
    dueDateController.dispose();
  }
}

class _TaskDetailBody extends StatelessWidget {
  const _TaskDetailBody({
    required this.task,
    this.onUpdateStatus,
    this.onManageTask,
  });

  final TaskItem task;
  final VoidCallback? onUpdateStatus;
  final VoidCallback? onManageTask;

  @override
  Widget build(BuildContext context) {
    final referenceRows = <CrmInfoRow>[
      CrmInfoRow(label: 'Task ID', value: task.id),
    ];

    if (task.customerProfile != null) {
      referenceRows.add(
        CrmInfoRow(label: 'Customer', value: task.customerProfile!),
      );
    }

    if (task.serviceRequest != null) {
      referenceRows.add(
        CrmInfoRow(label: 'Service request', value: task.serviceRequest!),
      );
    }

    if (task.supportTicket != null) {
      referenceRows.add(
        CrmInfoRow(label: 'Support ticket', value: task.supportTicket!),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
      children: [
        CrmDetailHeaderCard(
          icon: Icons.task_alt_rounded,
          title: task.title,
          subtitle: task.assignedTo.isEmpty ? 'Unassigned' : task.assignedTo,
          statusLabel: task.status,
        ),
        const SizedBox(height: 16),
        CrmDetailInfoCard(
          title: 'Overview',
          rows: [
            CrmInfoRow(
              label: 'Workflow status',
              value: _valueOrDash(task.status),
            ),
            CrmInfoRow(
              label: 'ERP task state',
              value: _valueOrDash(task.erpStatus),
            ),
            if (task.operationStatus.isNotEmpty)
              CrmInfoRow(
                label: 'Operation status',
                value: task.operationStatus,
              ),
            CrmInfoRow(label: 'Priority', value: _valueOrDash(task.priority)),
            CrmInfoRow(
              label: 'Due date',
              value: _valueOrDash(task.dueDateLabel),
            ),
            CrmInfoRow(label: 'Assigned', value: _valueOrDash(task.assignedTo)),
            if (task.completedOnLabel != null)
              CrmInfoRow(label: 'Completed on', value: task.completedOnLabel!),
            if (task.updatedAtLabel != null)
              CrmInfoRow(label: 'Last updated', value: task.updatedAtLabel!),
            if (task.createdAtLabel != null)
              CrmInfoRow(label: 'Created', value: task.createdAtLabel!),
          ],
        ),
        if (task.description != null) ...[
          const SizedBox(height: 16),
          CrmDetailInfoCard(
            title: 'Description',
            rows: [CrmInfoRow(label: 'Details', value: task.description!)],
          ),
        ],
        if (onUpdateStatus != null || onManageTask != null) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (onUpdateStatus != null)
                FilledButton.icon(
                  onPressed: onUpdateStatus,
                  icon: const Icon(Icons.sync_alt_rounded),
                  label: const Text('Update operation status'),
                ),
              if (onManageTask != null)
                OutlinedButton.icon(
                  onPressed: onManageTask,
                  icon: const Icon(Icons.manage_accounts_rounded),
                  label: const Text('Manage task'),
                ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        CrmDetailInfoCard(title: 'Reference', rows: referenceRows),
        if (task.serviceRequest != null || task.supportTicket != null) ...[
          const SizedBox(height: 16),
          _TaskReferenceActions(task: task),
        ],
      ],
    );
  }
}

class _TaskReferenceActions extends StatelessWidget {
  const _TaskReferenceActions({required this.task});

  final TaskItem task;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        if (task.serviceRequest != null)
          OutlinedButton.icon(
            onPressed: () => context.push(
              '/internal-workspace/service-cases/'
              '${Uri.encodeComponent(task.serviceRequest!)}',
            ),
            icon: const Icon(Icons.assignment_outlined),
            label: const Text('Open service case'),
          ),
        if (task.supportTicket != null)
          OutlinedButton.icon(
            onPressed: () => context.push(
              '/support-tickets/${Uri.encodeComponent(task.supportTicket!)}',
            ),
            icon: const Icon(Icons.support_agent_rounded),
            label: const Text('Open ticket'),
          ),
      ],
    );
  }
}

String _valueOrDash(String value) {
  final trimmed = value.trim();
  return trimmed.isEmpty ? '-' : trimmed;
}

class _TaskDetailLoadingView extends StatelessWidget {
  const _TaskDetailLoadingView();

  @override
  Widget build(BuildContext context) {
    return const CrmDetailLoadingView(
      icon: Icons.task_alt_rounded,
      title: 'Loading task',
      message: 'Fetching assignment, priority and activity context.',
    );
  }
}
