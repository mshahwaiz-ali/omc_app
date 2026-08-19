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
  return ref.watch(tasksRepositoryProvider).fetchTasks();
});

final taskDetailProvider = FutureProvider.family<TaskItem?, String>((
  ref,
  taskId,
) {
  return ref.watch(tasksRepositoryProvider).fetchTaskDetail(taskId);
});

class TasksRepository {
  const TasksRepository(this._frappeClient);

  final FrappeClient _frappeClient;

  static const int _taskPageLength = 100;

  static const String _taskAssigneeOptionsMethod =
      'omc_app.api.task_assignment_read.get_task_assignee_options';
  static const String _updateTaskStatusMethod =
      'omc_app.api.task_write_guard.update_task_operation_status';
  static const String _assignTaskMethod =
      'omc_app.api.task_write_guard.assign_task';
  static const String _updateTaskDetailsMethod =
      'omc_app.api.task_write_guard.update_task_details';

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
          if (seenTaskIds.add(task.id)) tasks.add(task);
        }

        final pagination = _paginationFromResponse(response);
        final hasMore = pagination?['has_more'] == true;
        final nextStart = pagination?['next_start'];
        if (!hasMore || nextStart is! int || nextStart <= limitStart) break;
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

  Future<List<TaskAssigneeOption>> fetchTaskAssigneeOptions({
    String? search,
    int limit = 50,
  }) async {
    final response = await _frappeClient.getMethod(
      _taskAssigneeOptionsMethod,
      queryParameters: {
        if (search?.trim().isNotEmpty ?? false) 'search': search!.trim(),
        'limit': limit.clamp(1, 100),
      },
    );
    final payload = _messageMap(response);
    final raw = payload['assignees'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map(
          (item) => TaskAssigneeOption.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .where((item) => item.user.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> updateTaskStatus({
    required String taskId,
    required String status,
    String? remarks,
  }) async {
    final cleanTaskId = taskId.trim();
    final cleanStatus = status.trim();
    if (cleanTaskId.isEmpty || cleanStatus.isEmpty) {
      throw const ApiError(message: 'Task and work status are required.');
    }

    await _frappeClient.postMethod(
      _updateTaskStatusMethod,
      data: {
        'task_id': cleanTaskId,
        'operation_status': cleanStatus,
        if (remarks?.trim().isNotEmpty ?? false) 'remarks': remarks!.trim(),
      },
    );
  }

  Future<void> reassignTask({
    required String taskId,
    required String assignedTo,
    String? remarks,
  }) async {
    final cleanTaskId = taskId.trim();
    final cleanAssignee = assignedTo.trim();
    if (cleanTaskId.isEmpty || cleanAssignee.isEmpty) {
      throw const ApiError(message: 'Task and assignee are required.');
    }

    await _frappeClient.postMethod(
      _assignTaskMethod,
      data: {
        'task_id': cleanTaskId,
        'assigned_to': cleanAssignee,
        if (remarks?.trim().isNotEmpty ?? false) 'remarks': remarks!.trim(),
      },
    );
  }

  Future<void> updateTaskPlan({
    required String taskId,
    required String priority,
    String? expectedCompletionDate,
    String? remarks,
  }) async {
    final cleanTaskId = taskId.trim();
    final cleanPriority = priority.trim();
    final cleanDueDate = expectedCompletionDate?.trim() ?? '';
    if (cleanTaskId.isEmpty) {
      throw const ApiError(message: 'Task is required.');
    }

    await _frappeClient.postMethod(
      _updateTaskDetailsMethod,
      data: {
        'task_id': cleanTaskId,
        if (cleanPriority.isNotEmpty) 'priority': cleanPriority,
        // Empty means "unchanged" in the mobile UI. Do not accidentally clear
        // an existing due date when the manager only updates priority.
        if (cleanDueDate.isNotEmpty) 'due_date': cleanDueDate,
        if (remarks?.trim().isNotEmpty ?? false) 'remarks': remarks!.trim(),
      },
    );
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
        .whereType<Map>()
        .map((item) => TaskItem.fromJson(Map<String, dynamic>.from(item)))
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

    if (rawTask is! Map) return null;
    return TaskItem.fromJson(Map<String, dynamic>.from(rawTask));
  }

  Map<String, dynamic> _messageMap(Map<String, dynamic> response) {
    final message = response['message'];
    if (message is Map) return Map<String, dynamic>.from(message);
    return response;
  }
}
