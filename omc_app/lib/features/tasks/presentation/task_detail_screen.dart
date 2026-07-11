import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/premium_empty_state.dart';
import '../../../core/widgets/app_back_header.dart';
import '../../crm/presentation/widgets/crm_detail_widgets.dart';
import '../data/task_item.dart';
import '../data/tasks_repository.dart';

class TaskDetailScreen extends ConsumerWidget {
  const TaskDetailScreen({required this.taskId, super.key});

  final String taskId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskAsync = ref.watch(taskDetailProvider(taskId));

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

          return _TaskDetailBody(task: task);
        },
        loading: () => const _TaskDetailLoadingView(),
        error: (_, _) => PremiumEmptyState(
          icon: Icons.task_alt_rounded,
          title: 'Task detail unavailable',
          message:
              'Task $taskId could not be loaded right now. Please try again later.',
        ),
      ),
    );
  }
}

class _TaskDetailBody extends StatelessWidget {
  const _TaskDetailBody({required this.task});

  final TaskItem task;

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
            CrmInfoRow(label: 'Status', value: _valueOrDash(task.status)),
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
        const SizedBox(height: 16),
        const CrmActivityTimelineCard(
          title: 'Task timeline',
          emptyMessage:
              'No task activity yet. Checklist changes, comments, assignments and status updates will appear here when activity is available.',
        ),
        const SizedBox(height: 16),
        const CrmDetailInfoCard(
          title: 'Activity',
          rows: [
            CrmInfoRow(label: 'Checklist', value: 'No checklist items yet'),
            CrmInfoRow(label: 'Comments', value: 'No comments yet'),
            CrmInfoRow(label: 'Updates', value: 'No updates recorded yet'),
          ],
        ),
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
              '/my-services/${Uri.encodeComponent(task.serviceRequest!)}',
            ),
            icon: const Icon(Icons.assignment_outlined),
            label: const Text('Open service'),
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
