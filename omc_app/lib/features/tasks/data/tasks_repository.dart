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

  Future<TaskItem> createTask({
    required String title,
    String? status,
    String? priority,
    String? dueDate,
    String? assignedTo,
    String? description,
  }) async {
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty) {
      throw const ApiError(message: 'Task title is required.');
    }

    try {
      final response = await _frappeClient.postResource(
        'OMC Task',
        data: {
          'title': cleanTitle,
          'status': status?.trim().isNotEmpty == true ? status!.trim() : 'Open',
          'priority': priority?.trim().isNotEmpty == true
              ? priority!.trim()
              : 'Normal',
          'due_date': dueDate?.trim() ?? '',
          'assigned_to': assignedTo?.trim() ?? '',
          'description': description?.trim() ?? '',
        },
      );

      final rawTask = response['data'];
      if (rawTask is Map<String, dynamic>) {
        return TaskItem.fromJson(rawTask);
      }

      refetch:
      {
        final tasks = await fetchTasks();
        if (tasks.isNotEmpty) return tasks.first;
        break refetch;
      }

      throw const ApiError(message: 'Task was created but response was empty.');
    } on ApiError {
      rethrow;
    } catch (error) {
      throw ApiError(
        message: 'Task could not be created right now.',
        code: 'task_create_failed',
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
        ? message['tasks'] ??
              message['task_list'] ??
              message['data'] ??
              message['items'] ??
              message['rows'] ??
              message['results'] ??
              message['records']
        : data['tasks'] ??
              data['task_list'] ??
              data['data'] ??
              data['items'] ??
              data['rows'] ??
              data['results'] ??
              data['records'];

    if (rawTasks is! List) return const [];

    return rawTasks
        .whereType<Map<String, dynamic>>()
        .map(TaskItem.fromJson)
        .toList(growable: false);
  }

  TaskItem? _mapTaskDetailResponse(Map<String, dynamic> data) {
    final message = data['message'];

    final rawTask = message is Map<String, dynamic>
        ? message['task'] ??
              message['task_detail'] ??
              message['data'] ??
              message['item'] ??
              message['record'] ??
              message
        : data['task'] ??
              data['task_detail'] ??
              data['data'] ??
              data['item'] ??
              data['record'];

    if (rawTask is! Map<String, dynamic>) return null;

    return TaskItem.fromJson(rawTask);
  }
}
