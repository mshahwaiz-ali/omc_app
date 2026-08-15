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

  static const int _taskPageLength = 100;

  Future<List<TaskItem>> fetchTasks() async {
    try {
      final tasks = <TaskItem>[];
      final seenTaskIds = <String>{};
      var limitStart = 0;

      while (true) {
        final response = await _frappeClient.getMethod(
          ApiConfig.tasksMethod,
          queryParameters: {
            'limit_start': limitStart,
            'page_length': _taskPageLength,
          },
        );
        final page = _mapTasksResponse(response);
        for (final task in page) {
          if (seenTaskIds.add(task.id)) {
            tasks.add(task);
          }
        }

        final pagination = _paginationFromResponse(response);
        final hasMore = pagination?['has_more'] == true;
        final nextStart = pagination?['next_start'];
        if (!hasMore || nextStart is! int || nextStart <= limitStart) {
          break;
        }
        limitStart = nextStart;
      }

      return tasks;
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

  Map<String, dynamic>? _paginationFromResponse(Map<String, dynamic> data) {
    final message = data['message'];
    final container = message is Map<String, dynamic> ? message : data;
    final rawPagination = container['pagination'];
    if (rawPagination is! Map) return null;

    final hasMoreValue = rawPagination['has_more'];
    final nextStartValue = rawPagination['next_start'];
    final nextStart = nextStartValue is int
        ? nextStartValue
        : int.tryParse('$nextStartValue');

    return {
      'has_more':
          hasMoreValue == true || hasMoreValue == 1 || hasMoreValue == '1',
      'next_start': nextStart,
    };
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
