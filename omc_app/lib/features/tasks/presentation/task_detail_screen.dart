import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/widgets/app_back_header.dart';
import '../../../core/widgets/premium_empty_state.dart';
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
            return const PremiumEmptyState(
              icon: Icons.task_alt_rounded,
              title: 'Task unavailable',
              message:
                  'This ERP task is not currently available for your account.',
            );
          }

          return _TaskDetailBody(task: task);
        },
        loading: () => const _TaskDetailLoadingView(),
        error: (_, _) => PremiumEmptyState(
          icon: Icons.task_alt_rounded,
          title: 'Task unavailable',
          message:
              'Task $taskId could not be loaded right now. Please try again.',
          actionLabel: 'Try again',
          onAction: () => ref.invalidate(taskDetailProvider(taskId)),
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
    final status = _valueOrFallback(task.status, 'Open');
    final priority = _valueOrFallback(task.priority, 'Normal');
    final assigned = _valueOrFallback(task.assignedTo, 'Unassigned');

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 34),
      children: [
        _TaskHeroCard(task: task, status: status, assigned: assigned),
        const SizedBox(height: 16),
        _TaskSectionCard(
          title: 'Task overview',
          children: [
            _TaskInfoRow(
              icon: Icons.person_outline_rounded,
              label: 'Assigned to',
              value: assigned,
            ),
            _TaskInfoRow(
              icon: Icons.flag_outlined,
              label: 'Priority',
              value: priority,
            ),
            _TaskInfoRow(
              icon: Icons.calendar_today_outlined,
              label: 'Due date',
              value: _valueOrFallback(task.dueDateLabel, 'Not set'),
            ),
            if (task.operationStatus.trim().isNotEmpty)
              _TaskInfoRow(
                icon: Icons.timeline_rounded,
                label: 'Operation status',
                value: task.operationStatus,
              ),
            if (task.erpStatus.trim().isNotEmpty &&
                task.erpStatus.trim() != task.status.trim())
              _TaskInfoRow(
                icon: Icons.account_tree_outlined,
                label: 'ERP task state',
                value: task.erpStatus,
              ),
            if (task.completedOnLabel != null)
              _TaskInfoRow(
                icon: Icons.check_circle_outline_rounded,
                label: 'Completed',
                value: task.completedOnLabel!,
              ),
          ],
        ),
        if (task.description?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 16),
          _TaskSectionCard(
            title: 'Description',
            children: [
              Text(
                task.description!.trim(),
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  height: 1.55,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 16),
        _TaskSectionCard(
          title: 'References',
          children: [
            _TaskInfoRow(
              icon: Icons.tag_rounded,
              label: 'Task ID',
              value: task.id,
            ),
            if (task.customerProfile?.trim().isNotEmpty == true)
              _TaskInfoRow(
                icon: Icons.person_outline_rounded,
                label: 'Customer',
                value: task.customerProfile!,
              ),
            if (task.serviceRequest?.trim().isNotEmpty == true)
              _TaskInfoRow(
                icon: Icons.assignment_outlined,
                label: 'Service request',
                value: task.serviceRequest!,
              ),
            if (task.supportTicket?.trim().isNotEmpty == true)
              _TaskInfoRow(
                icon: Icons.support_agent_outlined,
                label: 'Support ticket',
                value: task.supportTicket!,
              ),
          ],
        ),
        if (task.serviceRequest != null || task.supportTicket != null) ...[
          const SizedBox(height: 16),
          _TaskReferenceActions(task: task),
        ],
        if (task.updatedAtLabel != null || task.createdAtLabel != null) ...[
          const SizedBox(height: 18),
          _TaskAuditLine(task: task),
        ],
      ],
    );
  }
}

class _TaskHeroCard extends StatelessWidget {
  const _TaskHeroCard({
    required this.task,
    required this.status,
    required this.assigned,
  });

  final TaskItem task;
  final String status;
  final String assigned;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8ECF2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppTheme.primarySoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.task_alt_rounded,
              color: AppTheme.primary,
              size: 25,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task.title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 19,
                    height: 1.2,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.35,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  assigned,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                _TaskStatusBadge(label: status),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskSectionCard extends StatelessWidget {
  const _TaskSectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 17, 18, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE9EDF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1)
              const Divider(height: 25, color: Color(0xFFEEF1F5)),
          ],
        ],
      ),
    );
  }
}

class _TaskInfoRow extends StatelessWidget {
  const _TaskInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F7FA),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 17, color: AppTheme.textSecondary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 13.5,
                  height: 1.35,
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

class _TaskStatusBadge extends StatelessWidget {
  const _TaskStatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final normalized = label.trim().toLowerCase();

    final muted =
        normalized == 'completed' ||
        normalized == 'cancelled' ||
        normalized == 'canceled' ||
        normalized == 'closed';

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: muted ? const Color(0xFFF3F5F7) : AppTheme.primarySoft,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: muted ? AppTheme.textSecondary : AppTheme.primary,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
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
            icon: const Icon(Icons.support_agent_outlined),
            label: const Text('Open ticket'),
          ),
      ],
    );
  }
}

class _TaskAuditLine extends StatelessWidget {
  const _TaskAuditLine({required this.task});

  final TaskItem task;

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (task.createdAtLabel != null) 'Created ${task.createdAtLabel}',
      if (task.updatedAtLabel != null) 'Updated ${task.updatedAtLabel}',
    ];

    return Text(
      parts.join('  •  '),
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontSize: 10.5,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

String _valueOrFallback(String value, String fallback) {
  final clean = value.trim();
  return clean.isEmpty ? fallback : clean;
}

class _TaskDetailLoadingView extends StatelessWidget {
  const _TaskDetailLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 34),
      children: [
        Container(
          height: 128,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: const Color(0xFFE8ECF2)),
          ),
          alignment: Alignment.center,
          child: const CircularProgressIndicator(strokeWidth: 2.3),
        ),
      ],
    );
  }
}
