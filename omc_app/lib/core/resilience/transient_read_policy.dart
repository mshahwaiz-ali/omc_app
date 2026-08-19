import '../network/api_error.dart';

class TransientReadPolicy {
  const TransientReadPolicy._();

  static bool canReuseLastSuccessful(Object error) {
    if (error is! ApiError) return false;

    final status = error.statusCode ?? 0;
    if (status == 401 || status == 403) return false;

    switch (error.category) {
      case ApiFailureCategory.authentication:
      case ApiFailureCategory.authorization:
      case ApiFailureCategory.validation:
      case ApiFailureCategory.configuration:
      case ApiFailureCategory.malformedResponse:
      case ApiFailureCategory.cancelled:
        return false;
      case ApiFailureCategory.timeout:
      case ApiFailureCategory.offline:
      case ApiFailureCategory.server:
        return true;
      case ApiFailureCategory.unknown:
        break;
    }

    if (status == 408 || status == 429 || status >= 500) return true;
    return error.retryable;
  }
}
