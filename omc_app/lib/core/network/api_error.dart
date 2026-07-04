class ApiError implements Exception {
  const ApiError({
    required this.message,
    this.statusCode,
    this.code,
    this.details,
  });

  final String message;
  final int? statusCode;
  final String? code;
  final Object? details;

  @override
  String toString() {
    return 'ApiError(message: $message, statusCode: $statusCode, code: $code)';
  }
}
