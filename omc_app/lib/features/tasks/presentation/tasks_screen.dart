import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/premium_empty_state.dart';
import '../../../core/widgets/premium_info_chip.dart';
import '../../../core/widgets/premium_list_card.dart';
import '../data/task_item.dart';
import '../data/tasks_repository.dart';

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      body: tasksAsync.when(
        data: (tasks) {
          if (tasks.isEmpty) {
            return const PremiumEmptyState(
              icon: Icons.task_alt_rounded,
              title: 'No tasks yet',
              message:
                  'Assigned work items will appear here once the backend returns tasks.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(tasksProvider);
              await ref.read(tasksProvider.future);
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemBuilder: (context, index) {
                return _TaskCard(task: tasks[index]);
              },
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemCount: tasks.length,
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => PremiumEmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Tasks unavailable',
          message: error.toString(),
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(tasksProvider),
        ),
      ),
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
      onTap: () {
        context.push('/tasks/${Uri.encodeComponent(task.id)}');
      },
      children: [
        PremiumInfoChip(
          icon: Icons.radio_button_checked_rounded,
          label: task.status.isEmpty ? 'Open' : task.status,
        ),
        PremiumInfoChip(
          icon: Icons.flag_rounded,
          label: task.priority.isEmpty ? 'Normal' : task.priority,
        ),
        if (task.dueDateLabel.isNotEmpty)
          PremiumInfoChip(icon: Icons.event_rounded, label: task.dueDateLabel),
        if (task.assignedTo.isNotEmpty)
          PremiumInfoChip(icon: Icons.person_rounded, label: task.assignedTo),
      ],
    );
  }
}
