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

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(tasksProvider);

    return Scaffold(
      body: tasksAsync.when(
        data: (tasks) {
          if (tasks.isEmpty) {
            return const PremiumEmptyState(
              icon: Icons.task_alt_rounded,
              title: 'No tasks yet',
              message:
                  'Assigned work items will appear here when tasks are available.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(tasksProvider);
              await ref.read(tasksProvider.future);
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return PremiumListHeader(
                    icon: Icons.task_alt_rounded,
                    title: 'Tasks',
                    subtitle: 'Track assigned work, due dates and priorities.',
                    metaLabel: '${tasks.length} total',
                  );
                }

                return _TaskCard(task: tasks[index - 1]);
              },
              separatorBuilder: (_, index) =>
                  SizedBox(height: index == 0 ? 18 : 12),
              itemCount: tasks.length + 1,
            ),
          );
        },
        loading: () => const _TasksLoadingView(),
        error: (error, _) => PremiumEmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Tasks unavailable',
          message: _backendErrorMessage(error),
          actionLabel: 'Retry',
          onAction: () => ref.invalidate(tasksProvider),
        ),
      ),
    );
  }
}

String _backendErrorMessage(Object error) {
  if (error is ApiError && error.message.trim().isNotEmpty) {
    return error.message.trim();
  }

  return 'Could not load tasks right now. Please try again.';
}

class _TasksLoadingView extends StatelessWidget {
  const _TasksLoadingView();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      itemBuilder: (context, index) {
        if (index == 0) {
          return const PremiumListHeader(
            icon: Icons.task_alt_rounded,
            title: 'Tasks',
            subtitle: 'Track assigned work, due dates and priorities.',
            metaLabel: 'Loading',
          );
        }

        return const PremiumListCard(
          icon: Icons.task_alt_rounded,
          title: 'Loading task',
          subtitle: 'Fetching latest assignment details',
          children: [
            PremiumInfoChip(
              icon: Icons.radio_button_checked_rounded,
              label: 'Status',
            ),
            PremiumInfoChip(icon: Icons.flag_rounded, label: 'Priority'),
            PremiumInfoChip(icon: Icons.event_rounded, label: 'Due date'),
          ],
        );
      },
      separatorBuilder: (_, index) => SizedBox(height: index == 0 ? 18 : 12),
      itemCount: 4,
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
