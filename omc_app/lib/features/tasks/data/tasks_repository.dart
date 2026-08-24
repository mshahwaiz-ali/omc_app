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

/// Compatibility/refresh provider for the default first page.
/// The Tasks screen performs filtered pagination through fetchTasksPage.
final tasksProvider = FutureProvider<TaskPage>((ref) {
  return ref.watch(tasksRepositoryProvider).fetchTasksPage();
});

final taskDetailProvider = FutureProvider.family<TaskItem?, String>((
  ref,
  taskId,
) {
  return ref.watch(tasksRepositoryProvider).fetchTaskDetail(taskId);
});

class TaskPage {
  const TaskPage({
    required this.tasks,
    required this.limitStart,
    required this.pageLength,
    required this.hasMore,
    required this.nextStart,
  });

  final List<TaskItem> tasks;
  final int limitStart;
  final int pageLength;
  final bool hasMore;
  final int? nextStart;
}

class TasksRepository {
  const TasksRepository(this._frappeClient);

  final FrappeClient _frappeClient;

  static const int _taskPageLength = 50;

  Future<TaskPage> fetchTasksPage({
    int limitStart = 0,
    int pageLength = _taskPageLength,
    String? search,
    String? status,
    String? priority,
  }) async {
    final start = limitStart < 0 ? 0 : limitStart;
    final limit = pageLength < 1
        ? 1
        : pageLength > 100
        ? 100
        : pageLength;

    final cleanSearch = search?.trim() ?? '';
    final cleanStatus = status?.trim() ?? '';
    final cleanPriority = priority?.trim() ?? '';

    try {
      final response = await _frappeClient.getMethod(
        ApiConfig.tasksMethod,
        queryParameters: {
          'limit_start': start,
          'page_length': limit,
          if (cleanSearch.isNotEmpty) 'search': cleanSearch,
          if (cleanStatus.isNotEmpty && cleanStatus != 'All')
            'status': cleanStatus,
          if (cleanPriority.isNotEmpty && cleanPriority != 'All')
            'priority': cleanPriority,
        },
      );

      final tasks = _mapTasksResponse(response);
      final pagination = _paginationFromResponse(response);

      final hasMore = pagination?.hasMore ?? tasks.length >= limit;
      final inferredNext = start + tasks.length;
      final nextStart = hasMore
          ? (pagination?.nextStart ?? inferredNext)
          : null;

      return TaskPage(
        tasks: tasks,
        limitStart: start,
        pageLength: limit,
        hasMore: hasMore,
        nextStart: nextStart,
      );
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

  _TaskPagination? _paginationFromResponse(Map<String, dynamic> data) {
    final message = data['message'];
    final container = message is Map
        ? Map<String, dynamic>.from(message)
        : data;

    final rawPagination = container['pagination'];
    if (rawPagination is! Map) return null;

    final pagination = Map<String, dynamic>.from(rawPagination);
    final hasMoreValue = pagination['has_more'];
    final nextStartValue = pagination['next_start'];

    final hasMore =
        hasMoreValue == true ||
        hasMoreValue == 1 ||
        hasMoreValue?.toString().trim().toLowerCase() == 'true' ||
        hasMoreValue?.toString().trim() == '1';

    final nextStart = nextStartValue is int
        ? nextStartValue
        : int.tryParse(nextStartValue?.toString() ?? '');

    return _TaskPagination(hasMore: hasMore, nextStart: nextStart);
  }

  List<TaskItem> _mapTasksResponse(Map<String, dynamic> data) {
    final message = data['message'];

    final rawTasks = message is List
        ? message
        : message is Map
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
        .where((item) => item.id.isNotEmpty)
        .toList(growable: false);
  }

  TaskItem? _mapTaskDetailResponse(Map<String, dynamic> data) {
    final message = data['message'];

    final rawTask = message is Map
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
}

class _TaskPagination {
  const _TaskPagination({required this.hasMore, required this.nextStart});

  final bool hasMore;
  final int? nextStart;
}
