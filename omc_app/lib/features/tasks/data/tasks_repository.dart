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

final taskAssignmentOptionsProvider =
    FutureProvider.family<TaskAssignmentOptions, String>((ref, taskId) {
      final repository = ref.watch(tasksRepositoryProvider);

      return repository.fetchAssignmentOptions(taskId);
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

  Future<TaskItem> updateOperationStatus({
    required String taskId,
    required String operationStatus,
  }) async {
    final cleanTaskId = taskId.trim();
    final cleanStatus = operationStatus.trim();
    if (cleanTaskId.isEmpty || cleanStatus.isEmpty) {
      throw const ApiError(message: 'Task and operation status are required.');
    }

    final response = await _frappeClient.postMethod(
      ApiConfig.updateTaskOperationStatusMethod,
      data: {'task_id': cleanTaskId, 'operation_status': cleanStatus},
    );
    return _mapMutationTask(response);
  }

  Future<TaskAssignmentOptions> fetchAssignmentOptions(String taskId) async {
    final cleanTaskId = taskId.trim();
    if (cleanTaskId.isEmpty) {
      throw const ApiError(message: 'Task is required.');
    }

    try {
      final response = await _frappeClient.getMethod(
        ApiConfig.taskAssignmentOptionsMethod,
        queryParameters: {'task_id': cleanTaskId},
      );

      final message = response['message'];
      final payload = message is Map
          ? Map<String, dynamic>.from(message)
          : response;

      return TaskAssignmentOptions.fromJson(payload);
    } on ApiError {
      rethrow;
    } catch (error) {
      throw ApiError(
        message: 'Task assignment options could not be loaded.',
        code: 'task_assignment_options_unavailable',
        details: error,
      );
    }
  }

  Future<TaskItem> assignTask({
    required String taskId,
    required String assignedTo,
  }) async {
    final cleanTaskId = taskId.trim();
    final cleanAssignee = assignedTo.trim();
    if (cleanTaskId.isEmpty || cleanAssignee.isEmpty) {
      throw const ApiError(message: 'Task and assignee are required.');
    }

    final response = await _frappeClient.postMethod(
      ApiConfig.assignTaskMethod,
      data: {'task_id': cleanTaskId, 'assigned_to': cleanAssignee},
    );
    return _mapMutationTask(response);
  }

  Future<TaskItem> updateTaskDetails({
    required String taskId,
    String? priority,
    String? dueDate,
  }) async {
    final cleanTaskId = taskId.trim();
    if (cleanTaskId.isEmpty) {
      throw const ApiError(message: 'Task is required.');
    }

    final response = await _frappeClient.postMethod(
      ApiConfig.updateTaskDetailsMethod,
      data: {
        'task_id': cleanTaskId,
        if (priority != null) 'priority': priority.trim(),
        if (dueDate != null) 'due_date': dueDate.trim(),
      },
    );
    return _mapMutationTask(response);
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

  TaskItem _mapMutationTask(Map<String, dynamic> data) {
    final message = data['message'];
    final rawTask = message is Map<String, dynamic>
        ? message['task'] ?? message['data'] ?? message
        : data['task'] ?? data['data'];

    if (rawTask is! Map<String, dynamic>) {
      throw const ApiError(message: 'Task update response was invalid.');
    }
    return TaskItem.fromJson(rawTask);
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

class TaskAssignmentOptions {
  const TaskAssignmentOptions({
    required this.taskId,
    required this.currentAssignee,
    required this.priorityOptions,
    required this.candidates,
  });

  final String taskId;
  final String currentAssignee;
  final List<String> priorityOptions;
  final List<TaskAssigneeCandidate> candidates;

  factory TaskAssignmentOptions.fromJson(Map<String, dynamic> json) {
    return TaskAssignmentOptions(
      taskId: _text(json['task_id']),
      currentAssignee: _text(json['current_assignee']),
      priorityOptions: (json['priority_options'] as List? ?? const [])
          .map(_text)
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
      candidates: (json['assignment_candidates'] as List? ?? const [])
          .whereType<Map>()
          .map(
            (item) =>
                TaskAssigneeCandidate.fromJson(Map<String, dynamic>.from(item)),
          )
          .where((candidate) => candidate.userId.isNotEmpty)
          .toList(growable: false),
    );
  }

  static String _text(dynamic value) => value?.toString().trim() ?? '';
}

class TaskAssigneeCandidate {
  const TaskAssigneeCandidate({required this.userId, required this.fullName});

  final String userId;
  final String fullName;

  factory TaskAssigneeCandidate.fromJson(Map<String, dynamic> json) {
    return TaskAssigneeCandidate(
      userId: TaskAssignmentOptions._text(json['user_id']),
      fullName: TaskAssignmentOptions._text(json['full_name']),
    );
  }

  String get label {
    if (fullName.isEmpty || fullName == userId) return userId;
    return '$fullName — $userId';
  }
}
