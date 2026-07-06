import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers/core_providers.dart';
import '../../../core/config/api_config.dart';
import '../../../core/network/api_error.dart';
import '../../../core/network/frappe_client.dart';
import 'task_item.dart';

final tasksRepositoryProvider = Provider<TasksRepository>((ref) {
  final frappeClient = ref.watch(frappeClientProvider);

  return TasksRepository(frappeClient);
});

final tasksProvider = FutureProvider<List<TaskItem>>((ref) {
  final repository = ref.watch(tasksRepositoryProvider);

  return repository.fetchTasks();
});

final taskDetailProvider = FutureProvider.family<TaskItem?, String>((
  ref,
  taskId,
) {
  final repository = ref.watch(tasksRepositoryProvider);

  return repository.fetchTaskDetail(taskId);
});

class TasksRepository {
  const TasksRepository(this._frappeClient);

  final FrappeClient _frappeClient;

  Future<List<TaskItem>> fetchTasks() async {
    try {
      final response = await _frappeClient.getMethod(ApiConfig.tasksMethod);
      return _mapTasksResponse(response);
    } on ApiError {
      rethrow;
    } catch (error) {
      throw ApiError(
        message: 'Tasks could not be loaded from the server right now.',
        code: 'tasks_unavailable',
        details: error,
      );
    }
  }

  Future<TaskItem?> fetchTaskDetail(String taskId) async {
    final cleanTaskId = taskId.trim();
    if (cleanTaskId.isEmpty) return null;

    try {
      final response = await _frappeClient.getMethod(
        ApiConfig.taskDetailMethod,
        queryParameters: {'task_id': cleanTaskId, 'name': cleanTaskId},
      );

      return _mapTaskDetailResponse(response);
    } on ApiError {
      rethrow;
    } catch (error) {
      throw ApiError(
        message: 'Task details could not be loaded from the server right now.',
        code: 'task_detail_unavailable',
        details: error,
      );
    }
  }

  List<TaskItem> _mapTasksResponse(Map<String, dynamic> data) {
    final message = data['message'];

    final rawTasks = message is List
        ? message
        : message is Map<String, dynamic>
        ? message['tasks'] ?? message['data'] ?? message['items']
        : data['tasks'] ?? data['data'] ?? data['items'];

    if (rawTasks is! List) return const [];

    return rawTasks
        .whereType<Map<String, dynamic>>()
        .map(TaskItem.fromJson)
        .toList(growable: false);
  }

  TaskItem? _mapTaskDetailResponse(Map<String, dynamic> data) {
    final message = data['message'];

    final rawTask = message is Map<String, dynamic>
        ? message['task'] ?? message['data'] ?? message['item'] ?? message
        : data['task'] ?? data['data'] ?? data['item'];

    if (rawTask is! Map<String, dynamic>) return null;

    return TaskItem.fromJson(rawTask);
  }
}
