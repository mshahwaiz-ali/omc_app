import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design_tokens.dart';
import '../../../app/theme.dart';
import '../../../core/widgets/app_state.dart';
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
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Task details')),
      body: SafeArea(
        top: false,
        child: taskAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => _TaskListView(
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
            if (task == null) return const _MissingTask();

            final canOpenLinkedCase =
                capabilities.canViewAnyServiceCase &&
                task.canViewLinkedServiceCase &&
                task.caseReference?.trim().isNotEmpty == true;

            return RefreshIndicator.adaptive(
              onRefresh: () async {
                _invalidateTask();
                await ref.read(taskDetailProvider(widget.taskId).future);
              },
              child: _TaskListView(
                children: [
                  _TaskHero(task: task),
                  if (task.description?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _DescriptionCard(description: task.description!.trim()),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  _AssignmentCard(task: task),
                  if (task.caseReference?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _LinkedCaseCard(
                      caseReference: task.caseReference!.trim(),
                      canOpen: canOpenLinkedCase,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  _TaskDetails(task: task),
                ],
              ),
            );
          },
        ),
      ),
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
        final horizontal = constraints.maxWidth >
                AppLayout.generalMaxWidth + inset * 2
            ? (constraints.maxWidth - AppLayout.generalMaxWidth) / 2
            : inset;
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: EdgeInsets.fromLTRB(horizontal, 16, horizontal, 80),
          children: children,
        );
      },
    );
  }
}

class _TaskHero extends StatelessWidget {
  const _TaskHero({required this.task});

  final TaskItem task;

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusBackground) = _statusPalette(task.status);
    final due = task.dueDateLabel.trim();

    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(task.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(
            task.id,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              _StatusBadge(
                label: task.status,
                color: statusColor,
                background: statusBackground,
              ),
              _StatusBadge(
                label: task.priority,
                color: AppTheme.processing,
                background: AppTheme.processingSoft,
              ),
              if (due.isNotEmpty)
                _StatusBadge(
                  label: 'Due $due',
                  color: _isOverdue(task) ? AppTheme.danger : AppTheme.processing,
                  background:
                      _isOverdue(task) ? AppTheme.dangerSoft : AppTheme.processingSoft,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppTheme.cardSoft,
              borderRadius: BorderRadius.circular(AppRadius.control),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.visibility_outlined,
                  size: 20,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    'Read-only ERPNext Task. Task updates are managed in ERPNext.',
                    style: Theme.of(context).textTheme.bodyMedium,
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

class _DescriptionCard extends StatelessWidget {
  const _DescriptionCard({required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Description', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.xs),
          Text(description, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  const _AssignmentCard({required this.task});

  final TaskItem task;

  @override
  Widget build(BuildContext context) {
    final assigned = task.assignedTo.trim().isEmpty
        ? 'Unassigned'
        : task.assignedTo.trim();
    final rows = <(String, String)>[
      ('Assigned to', assigned),
      if (task.customerName?.trim().isNotEmpty == true)
        ('Customer', task.customerName!.trim()),
      if (task.taskType?.trim().isNotEmpty == true)
        ('Task type', task.taskType!.trim()),
    ];

    return _DetailCard(title: 'Assignment', rows: rows);
  }
}

class _LinkedCaseCard extends StatelessWidget {
  const _LinkedCaseCard({required this.caseReference, required this.canOpen});

  final String caseReference;
  final bool canOpen;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Linked service case',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.xs),
          SelectableText(
            caseReference,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (canOpen)
            OutlinedButton.icon(
              onPressed: () => context.push(
                '/my-services/${Uri.encodeComponent(caseReference)}',
              ),
              icon: const Icon(Icons.folder_open_outlined),
              label: const Text('Open linked service case'),
            )
          else
            Text(
              'This task does not grant access to open the linked service case.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondary,
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

    return _DetailCard(title: 'Record details', rows: rows);
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.title, required this.rows});

  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          for (var index = 0; index < rows.length; index++) ...[
            _DetailRow(label: rows[index].$1, value: rows[index].$2),
            if (index != rows.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Divider(height: 1),
              ),
          ],
        ],
      ),
    );
  }
}

String _progressLabel(double value) {
  if (value == value.roundToDouble()) return '${value.toInt()}%';
  return '${value.toStringAsFixed(1)}%';
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final stack = constraints.maxWidth < 420 || textScale >= 1.5;
        final labelWidget = Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppTheme.textSecondary,
          ),
        );
        final valueWidget = SelectableText(
          value,
          style: Theme.of(context).textTheme.bodyMedium,
        );

        if (stack) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              labelWidget,
              const SizedBox(height: AppSpacing.xxs),
              valueWidget,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 140, child: labelWidget),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: valueWidget),
          ],
        );
      },
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
    required this.background,
  });

  final String label;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color),
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
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Text(
          'This task is no longer available.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

(Color, Color) _statusPalette(String status) {
  switch (status.trim().toLowerCase()) {
    case 'completed':
      return (AppTheme.success, AppTheme.successSoft);
    case 'cancelled':
      return (AppTheme.processing, AppTheme.processingSoft);
    case 'working':
      return (AppTheme.info, AppTheme.infoSoft);
    case 'overdue':
      return (AppTheme.danger, AppTheme.dangerSoft);
    default:
      return (AppTheme.processing, AppTheme.processingSoft);
  }
}

bool _isOverdue(TaskItem task) {
  final status = task.status.trim().toLowerCase().replaceAll('_', ' ');
  if (status == 'overdue') return true;
  if (status == 'completed' || status == 'cancelled') return false;
  final parsed = DateTime.tryParse(task.dueDateLabel.trim());
  if (parsed == null) return false;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final due = DateTime(parsed.year, parsed.month, parsed.day);
  return due.isBefore(today);
}
