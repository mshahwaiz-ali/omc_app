import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'dio_web_credentials_stub.dart'
    if (dart.library.html) 'dio_web_credentials_web.dart';

import '../config/api_config.dart';
import '../storage/secure_storage_service.dart';
import 'api_error.dart';

class DioClient {
  DioClient({required SecureStorageService secureStorageService, Dio? dio})
    : this._(
        secureStorageService,
        dio ??
            Dio(
              BaseOptions(
                baseUrl: ApiConfig.baseUrl,
                connectTimeout: ApiConfig.connectTimeout,
                receiveTimeout: ApiConfig.receiveTimeout,
                sendTimeout: ApiConfig.sendTimeout,
                headers: const {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
              ),
            ),
      );

  DioClient._(this._secureStorageService, this._dio) {
    configureWebCredentials(_dio);
    _setupInterceptors();
  }

  final SecureStorageService _secureStorageService;
  final Dio _dio;

  Dio get instance => _dio;

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final sessionCookie = await _secureStorageService.readSessionCookie();
          final apiKey = await _secureStorageService.readApiKey();
          final apiSecret = await _secureStorageService.readApiSecret();

          if (!kIsWeb && sessionCookie != null && sessionCookie.isNotEmpty) {
            options.headers['Cookie'] = sessionCookie;
          }

          if (apiKey != null &&
              apiKey.isNotEmpty &&
              apiSecret != null &&
              apiSecret.isNotEmpty) {
            options.headers['Authorization'] = 'token $apiKey:$apiSecret';
          }

          handler.next(options);
        },
        onError: (error, handler) {
          handler.reject(error);
        },
      ),
    );
  }

  ApiError parseError(DioException error) {
    final response = error.response;
    final data = response?.data;

    if (response?.statusCode == 401 || response?.statusCode == 403) {
      return ApiError(
        message: 'Wrong email or password. Please try again.',
        statusCode: response?.statusCode,
        details: data,
      );
    }

    String message = _fallbackMessage(error);

    if (data is Map<String, dynamic>) {
      final serverMessage = _extractServerMessage(data);

      if (serverMessage != null && serverMessage.trim().isNotEmpty) {
        message = serverMessage;
      }
    }

    return ApiError(
      message: message,
      statusCode: response?.statusCode,
      details: data,
    );
  }

  String _fallbackMessage(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.connectionError:
        return 'Unable to reach the OMC server. Please check your connection and try again.';
      case DioExceptionType.badCertificate:
        return 'The server security certificate could not be verified.';
      case DioExceptionType.cancel:
        return 'The request was cancelled.';
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        final message = error.message;
        if (message != null && message.trim().isNotEmpty) {
          return _cleanMessage(message);
        }
        return 'Something went wrong. Please try again.';
    }
  }

  String? _extractServerMessage(Map<String, dynamic> data) {
    final candidates = [
      data['message'],
      data['_server_messages'],
      data['exception'],
      data['exc'],
    ];

    for (final candidate in candidates) {
      final message = _stringFromUnknown(candidate);
      if (message != null && message.trim().isNotEmpty) {
        return _cleanMessage(message);
      }
    }

    return null;
  }

  String? _stringFromUnknown(Object? value) {
    if (value == null) return null;

    if (value is String) return value;

    if (value is List) {
      final parts = value
          .map(_stringFromUnknown)
          .whereType<String>()
          .where((message) => message.trim().isNotEmpty)
          .toList();
      if (parts.isEmpty) return null;
      return parts.join('\n');
    }

    if (value is Map) {
      final message = value['message'] ?? value['title'] ?? value['exception'];
      return _stringFromUnknown(message);
    }

    return value.toString();
  }

  String _cleanMessage(String value) {
    return value
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
