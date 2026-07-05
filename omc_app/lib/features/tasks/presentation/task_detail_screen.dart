import 'package:flutter/material.dart';

import '../../../core/widgets/premium_empty_state.dart';

class TaskDetailScreen extends StatelessWidget {
  const TaskDetailScreen({required this.taskId, super.key});

  final String taskId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Task Details')),
      body: PremiumEmptyState(
        icon: Icons.task_alt_rounded,
        title: 'Task detail foundation',
        message:
            'Task $taskId is ready for a backend detail endpoint. Status updates, assignment, and activity timeline will be connected next.',
      ),
    );
  }
}
