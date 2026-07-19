import 'dart:async';

import 'package:dio/dio.dart';

import '../network/api_error.dart';

enum AppFailureType {
  offline,
  timeout,
  unauthorized,
  forbidden,
  notFound,
  configuration,
  validation,
  serverUnavailable,
  malformedResponse,
  unknown,
}

class AppFailure {
  const AppFailure({
    required this.type,
    required this.title,
    required this.message,
    required this.canRetry,
  });

  final AppFailureType type;
  final String title;
  final String message;
  final bool canRetry;
}

class AppFailureClassifier {
  const AppFailureClassifier._();

  static AppFailure classify(
    Object error, {
    String? fallbackTitle,
    String? fallbackMessage,
  }) {
    if (error is TimeoutException) {
      return _failure(AppFailureType.timeout);
    }

    if (error is FormatException || error is TypeError) {
      return _failure(AppFailureType.malformedResponse);
    }

    if (error is DioException) {
      return _fromDio(error);
    }

    if (error is ApiError) {
      return _fromApiError(error);
    }

    final text = _normalized(error.toString());
    final inferred = _inferFromText(text);
    if (inferred != null) return _failure(inferred);

    return AppFailure(
      type: AppFailureType.unknown,
      title: fallbackTitle ?? 'Something went wrong',
      message:
          fallbackMessage ??
          'We could not complete this request. Please try again.',
      canRetry: true,
    );
  }

  static AppFailure _fromDio(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return _failure(AppFailureType.timeout);
      case DioExceptionType.connectionError:
      case DioExceptionType.badCertificate:
        return _failure(AppFailureType.offline);
      case DioExceptionType.badResponse:
        return _fromStatusAndText(
          error.response?.statusCode,
          _normalized(error.response?.data?.toString() ?? error.message ?? ''),
        );
      case DioExceptionType.cancel:
        return const AppFailure(
          type: AppFailureType.unknown,
          title: 'Request cancelled',
          message: 'The request was cancelled before it completed.',
          canRetry: true,
        );
      case DioExceptionType.unknown:
        final inferred = _inferFromText(_normalized(error.message ?? ''));
        return _failure(inferred ?? AppFailureType.unknown);
    }
  }

  static AppFailure _fromApiError(ApiError error) {
    final combined = _normalized(
      '${error.code ?? ''} ${error.message} ${error.details ?? ''}',
    );
    return _fromStatusAndText(error.statusCode, combined);
  }

  static AppFailure _fromStatusAndText(int? statusCode, String text) {
    if (statusCode == 401) return _failure(AppFailureType.unauthorized);
    if (statusCode == 403) return _failure(AppFailureType.forbidden);
    if (statusCode == 404) return _failure(AppFailureType.notFound);
    if (statusCode != null && statusCode >= 500) {
      return _failure(AppFailureType.serverUnavailable);
    }

    final inferred = _inferFromText(text);
    return _failure(inferred ?? AppFailureType.unknown);
  }

  static AppFailureType? _inferFromText(String text) {
    if (text.isEmpty) return null;

    if (_containsAny(text, const [
      'socketexception',
      'connection refused',
      'connection error',
      'network is unreachable',
      'failed host lookup',
      'no internet',
      'offline',
      'unable to reach',
      'bad certificate',
    ])) {
      return AppFailureType.offline;
    }

    if (_containsAny(text, const [
      'timeout',
      'timed out',
      'deadline exceeded',
    ])) {
      return AppFailureType.timeout;
    }

    if (_containsAny(text, const [
      'session expired',
      'authentication required',
      'login required',
      'unauthorized',
      'not logged in',
    ])) {
      return AppFailureType.unauthorized;
    }

    if (_containsAny(text, const [
      'permission denied',
      'not permitted',
      'forbidden',
      'do not have permission',
      'not assigned',
      'access denied',
    ])) {
      return AppFailureType.forbidden;
    }

    if (_containsAny(text, const [
      'not found',
      'does not exist',
      'missing record',
      'unknown document',
    ])) {
      return AppFailureType.notFound;
    }

    if (_containsAny(text, const [
      'not configured',
      'configuration is missing',
      'missing configuration',
      'no active tax year',
      'no active tax slab',
      'no payment account',
      'feature is disabled',
      'currently disabled',
    ])) {
      return AppFailureType.configuration;
    }

    if (_containsAny(text, const [
      'validationerror',
      'validation error',
      'invalid value',
      'is required',
      'must be',
      'cannot be',
    ])) {
      return AppFailureType.validation;
    }

    if (_containsAny(text, const [
      'format exception',
      'formatexception',
      'malformed',
      'invalid response',
      'unexpected response',
      'typeerror',
      'type error',
    ])) {
      return AppFailureType.malformedResponse;
    }

    if (_containsAny(text, const [
      'internal server error',
      'service unavailable',
      'bad gateway',
      'gateway timeout',
      'server unavailable',
    ])) {
      return AppFailureType.serverUnavailable;
    }

    return null;
  }

  static AppFailure _failure(AppFailureType type) {
    return switch (type) {
      AppFailureType.offline => const AppFailure(
        type: AppFailureType.offline,
        title: 'Connection unavailable',
        message: 'Check your internet connection and try again.',
        canRetry: true,
      ),
      AppFailureType.timeout => const AppFailure(
        type: AppFailureType.timeout,
        title: 'Request timed out',
        message: 'The server took too long to respond. Please try again.',
        canRetry: true,
      ),
      AppFailureType.unauthorized => const AppFailure(
        type: AppFailureType.unauthorized,
        title: 'Session expired',
        message: 'Please sign in again to continue.',
        canRetry: false,
      ),
      AppFailureType.forbidden => const AppFailure(
        type: AppFailureType.forbidden,
        title: 'Access unavailable',
        message: 'Your account does not have access to this item.',
        canRetry: false,
      ),
      AppFailureType.notFound => const AppFailure(
        type: AppFailureType.notFound,
        title: 'Item unavailable',
        message: 'This item may have been removed or is no longer available.',
        canRetry: false,
      ),
      AppFailureType.configuration => const AppFailure(
        type: AppFailureType.configuration,
        title: 'Setup is incomplete',
        message:
            'This feature is not configured yet. Please contact OMC support.',
        canRetry: false,
      ),
      AppFailureType.validation => const AppFailure(
        type: AppFailureType.validation,
        title: 'Check the entered information',
        message:
            'Some information is missing or invalid. Review it and try again.',
        canRetry: false,
      ),
      AppFailureType.serverUnavailable => const AppFailure(
        type: AppFailureType.serverUnavailable,
        title: 'Service temporarily unavailable',
        message: 'The OMC server is unavailable right now. Please try again.',
        canRetry: true,
      ),
      AppFailureType.malformedResponse => const AppFailure(
        type: AppFailureType.malformedResponse,
        title: 'Unable to read server response',
        message:
            'The server returned incomplete information. Please try again.',
        canRetry: true,
      ),
      AppFailureType.unknown => const AppFailure(
        type: AppFailureType.unknown,
        title: 'Something went wrong',
        message: 'We could not complete this request. Please try again.',
        canRetry: true,
      ),
    };
  }

  static String _normalized(String value) => value.trim().toLowerCase();

  static bool _containsAny(String value, List<String> needles) {
    return needles.any(value.contains);
  }
}
