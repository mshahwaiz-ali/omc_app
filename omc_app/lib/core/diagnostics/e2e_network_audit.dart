import 'dart:collection';

import 'package:dio/dio.dart';

class E2eNetworkFailure {
  const E2eNetworkFailure({
    required this.method,
    required this.path,
    required this.status,
  });

  final String method;
  final String path;
  final String status;

  @override
  String toString() => '$method $path -> $status';
}

abstract final class E2eNetworkAudit {
  static const bool enabled = bool.fromEnvironment(
    'OMC_E2E_AUDIT',
    defaultValue: false,
  );

  static final List<E2eNetworkFailure> _failures = <E2eNetworkFailure>[];
  static final Set<RequestOptions> _pending =
      HashSet<RequestOptions>.identity();

  static List<E2eNetworkFailure> get failures {
    return List<E2eNetworkFailure>.unmodifiable(_failures);
  }

  static int get pendingRequestCount => enabled ? _pending.length : 0;

  static List<String> get pendingRequests {
    if (!enabled) return const <String>[];
    return _pending
        .map(
          (request) =>
              '${request.method.toUpperCase()} ${_safePath(request.path)}',
        )
        .toList(growable: false);
  }

  static void clear() {
    if (!enabled) return;
    _failures.clear();
    _pending.clear();
  }

  static void recordRequest(RequestOptions request) {
    if (enabled) _pending.add(request);
  }

  static void recordResponse(Response<dynamic> response) {
    if (!enabled) return;
    _pending.remove(response.requestOptions);
    final statusCode = response.statusCode ?? 0;
    if (statusCode < 400) return;
    _record(
      response.requestOptions,
      statusCode > 0 ? statusCode.toString() : 'unknown-response',
    );
  }

  static void recordError(DioException error) {
    if (!enabled) return;
    _pending.remove(error.requestOptions);
    if (error.type == DioExceptionType.cancel) return;
    final statusCode = error.response?.statusCode;
    _record(
      error.requestOptions,
      statusCode == null ? error.type.name : statusCode.toString(),
    );
  }

  static void _record(RequestOptions request, String status) {
    final failure = E2eNetworkFailure(
      method: request.method.toUpperCase(),
      path: _safePath(request.path),
      status: status,
    );
    if (!_failures.any(
      (existing) => existing.toString() == failure.toString(),
    )) {
      _failures.add(failure);
    }
  }

  static String _safePath(String value) {
    final parsed = Uri.tryParse(value);
    if (parsed != null && parsed.path.isNotEmpty) return parsed.path;
    return value.split('?').first;
  }
}
