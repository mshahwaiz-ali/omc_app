import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
      appBar: AppBar(title: const Text('Task Details')),
      body: taskAsync.when(
        data: (task) {
          if (task == null) {
            return PremiumEmptyState(
              icon: Icons.task_alt_rounded,
              title: 'Task detail unavailable',
              message:
                  'Task $taskId is ready for the backend detail endpoint. Status updates, assignment, and activity timeline will appear once data is available.',
            );
          }

          return _TaskDetailBody(task: task);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
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
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _DetailHeaderCard(
          icon: Icons.task_alt_rounded,
          title: task.title,
          subtitle: task.assignedTo.isEmpty ? 'Unassigned' : task.assignedTo,
          statusLabel: task.status,
        ),
        const SizedBox(height: 16),
        _DetailInfoCard(
          title: 'Task',
          rows: [
            _InfoRow(label: 'Priority', value: task.priority),
            _InfoRow(
              label: 'Due date',
              value: task.dueDateLabel.isEmpty ? '-' : task.dueDateLabel,
            ),
            _InfoRow(
              label: 'Assigned',
              value: task.assignedTo.isEmpty ? '-' : task.assignedTo,
            ),
          ],
        ),
        const SizedBox(height: 16),
        _DetailInfoCard(
          title: 'Activity',
          rows: const [
            _InfoRow(label: 'Checklist', value: 'Backend-ready placeholder'),
            _InfoRow(label: 'Comments', value: 'Backend-ready placeholder'),
            _InfoRow(label: 'Updates', value: 'Backend-ready placeholder'),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Task ID: ${task.id}',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _DetailHeaderCard extends StatelessWidget {
  const _DetailHeaderCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.statusLabel,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String statusLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 26,
              child: Icon(icon),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleLarge),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Chip(label: Text(statusLabel)),
          ],
        ),
      ),
    );
  }
}

class _DetailInfoCard extends StatelessWidget {
  const _DetailInfoCard({required this.title, required this.rows});

  final String title;
  final List<_InfoRow> rows;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 14),
            ...rows.map(
              (row) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: row,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(value, style: theme.textTheme.bodyMedium),
        ),
      ],
    );
  }
}
