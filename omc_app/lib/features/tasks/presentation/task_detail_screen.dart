import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
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
  void _invalidateTask() {
    ref.invalidate(taskDetailProvider(widget.taskId));
    ref.invalidate(tasksProvider);
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
                onRetry: () {
                  ref.invalidate(taskDetailProvider(widget.taskId));
                },
                fallbackTitle: 'Task unavailable',
                fallbackMessage: 'This task could not be loaded right now.',
              ),
            ],
          ),
          data: (task) {
            if (task == null) {
              return const _MissingTask();
            }

            final canOpenLinkedCase =
                capabilities.canViewAnyServiceCase &&
                task.canViewLinkedServiceCase &&
                task.caseReference?.trim().isNotEmpty == true;

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
                  const _ReadOnlyNotice(),
                  const SizedBox(height: 14),
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
                  if (canOpenLinkedCase) ...[
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: () {
                        context.push(
                          '/my-services/'
                          '${Uri.encodeComponent(task.caseReference!.trim())}',
                        );
                      },
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
              const _Pill(label: 'Read-only', color: OmcPremium.system),
              if (task.assignedTo.trim().isNotEmpty)
                _Pill(
                  label: 'Assigned: ${task.assignedTo}',
                  color: OmcPremium.track,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyNotice extends StatelessWidget {
  const _ReadOnlyNotice();

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.visibility_outlined, color: AppTheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Read-only tracking',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'This screen reflects ERPNext Task data. '
                  'Task updates are managed in ERPNext.',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                    fontWeight: FontWeight.w600,
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

class _TaskDetails extends StatelessWidget {
  const _TaskDetails({required this.task});

  final TaskItem task;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, String)>[
      ('ERP status', task.erpStatus),
      if (task.workflowState.trim().isNotEmpty)
        ('Workflow state', task.workflowState),
      if (task.operationStatus.trim().isNotEmpty)
        ('Operation status', task.operationStatus),
      if (task.customerName?.trim().isNotEmpty == true)
        ('Customer', task.customerName!.trim()),
      if (task.taskType?.trim().isNotEmpty == true)
        ('Task type', task.taskType!.trim()),
      (
        'Assigned to',
        task.assignedTo.trim().isEmpty ? 'Unassigned' : task.assignedTo,
      ),
      if (task.source?.trim().isNotEmpty == true)
        ('Source', task.source!.trim()),
      if (task.company?.trim().isNotEmpty == true)
        ('Company', task.company!.trim()),
      ('Priority', task.priority),
      if (task.progress != null) ('Progress', _progressLabel(task.progress!)),
      if (task.expectedStartDate?.trim().isNotEmpty == true)
        ('Expected start', task.expectedStartDate!.trim()),
      if (task.expectedCompletionDate?.trim().isNotEmpty == true)
        ('Due date', task.expectedCompletionDate!.trim()),
      if (task.completedOn?.trim().isNotEmpty == true)
        ('Completed on', task.completedOn!.trim()),
      if (task.createdAt?.trim().isNotEmpty == true)
        ('Created', task.createdAt!.trim()),
      if (task.updatedAt?.trim().isNotEmpty == true)
        ('Updated', task.updatedAt!.trim()),
      if (task.serviceRequest?.trim().isNotEmpty == true)
        ('Service case', task.serviceRequest!.trim()),
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

String _progressLabel(double value) {
  if (value == value.roundToDouble()) {
    return '${value.toInt()}%';
  }
  return '${value.toStringAsFixed(1)}%';
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
          width: 102,
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
  switch (status.trim().toLowerCase()) {
    case 'completed':
      return OmcPremium.success;
    case 'cancelled':
      return OmcPremium.system;
    case 'working':
      return OmcPremium.track;
    case 'overdue':
      return OmcPremium.danger;
    default:
      return OmcPremium.tasks;
  }
}
