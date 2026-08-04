enum ApiFailureCategory {
  authentication,
  authorization,
  validation,
  timeout,
  offline,
  configuration,
  server,
  malformedResponse,
  cancelled,
  unknown,
}

class ApiError implements Exception {
  const ApiError({
    required this.message,
    this.statusCode,
    this.code,
    this.details,
    this.category = ApiFailureCategory.unknown,
    this.retryable = false,
    this.fieldErrors = const {},
    this.correlationId,
    this.idempotencyResult,
  });

  final String message;
  final int? statusCode;
  final String? code;
  final Object? details;
  final ApiFailureCategory category;
  final bool retryable;
  final Map<String, String> fieldErrors;
  final String? correlationId;
  final Map<String, dynamic>? idempotencyResult;

  @override
  String toString() {
    return 'ApiError(message: $message, statusCode: $statusCode, code: $code)';
  }
}
