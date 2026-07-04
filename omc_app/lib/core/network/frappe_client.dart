import 'package:dio/dio.dart';

import '../config/api_config.dart';
import 'api_error.dart';
import 'dio_client.dart';

class FrappeLoginResult {
  const FrappeLoginResult({required this.data, this.sessionCookie});

  final Map<String, dynamic> data;
  final String? sessionCookie;
}

class FrappeClient {
  const FrappeClient(this._dioClient);

  final DioClient _dioClient;

  Future<Map<String, dynamic>> getMethod(
    String method, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dioClient.instance.get<Map<String, dynamic>>(
        '${ApiConfig.apiMethodPath}/$method',
        queryParameters: queryParameters,
      );

      return _readResponseMap(response.data);
    } on DioException catch (error) {
      throw _dioClient.parseError(error);
    } catch (error) {
      throw _unknownApiError(error);
    }
  }

  Future<Map<String, dynamic>> postMethod(
    String method, {
    Object? data,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _dioClient.instance.post<Map<String, dynamic>>(
        '${ApiConfig.apiMethodPath}/$method',
        data: data,
        queryParameters: queryParameters,
      );

      return _readResponseMap(response.data);
    } on DioException catch (error) {
      throw _dioClient.parseError(error);
    } catch (error) {
      throw _unknownApiError(error);
    }
  }

  Future<Map<String, dynamic>> getResource(
    String resource, {
    String? id,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final path = id == null
          ? '${ApiConfig.apiResourcePath}/$resource'
          : '${ApiConfig.apiResourcePath}/$resource/$id';

      final response = await _dioClient.instance.get<Map<String, dynamic>>(
        path,
        queryParameters: queryParameters,
      );

      return _readResponseMap(response.data);
    } on DioException catch (error) {
      throw _dioClient.parseError(error);
    } catch (error) {
      throw _unknownApiError(error);
    }
  }

  Future<Map<String, dynamic>> postResource(
    String resource, {
    required Object data,
  }) async {
    try {
      final response = await _dioClient.instance.post<Map<String, dynamic>>(
        '${ApiConfig.apiResourcePath}/$resource',
        data: data,
      );

      return _readResponseMap(response.data);
    } on DioException catch (error) {
      throw _dioClient.parseError(error);
    } catch (error) {
      throw _unknownApiError(error);
    }
  }

  Future<FrappeLoginResult> loginWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _dioClient.instance.post<Map<String, dynamic>>(
        '${ApiConfig.apiMethodPath}/${ApiConfig.loginMethod}',
        data: {'usr': email, 'pwd': password},
      );

      final data = _readResponseMap(response.data);
      final sessionCookie = _extractCookieHeader(
        response.headers['set-cookie'],
      );

      return FrappeLoginResult(
        data: data,
        sessionCookie: sessionCookie ?? _extractCookieFromBody(data),
      );
    } on DioException catch (error) {
      throw _dioClient.parseError(error);
    } catch (error) {
      throw _unknownApiError(error);
    }
  }

  Future<Map<String, dynamic>> uploadFile({
    required String filePath,
    required String fileName,
    required String doctype,
    required String docname,
    bool isPrivate = true,
  }) async {
    try {
      final formData = FormData.fromMap({
        'doctype': doctype,
        'docname': docname,
        'is_private': isPrivate ? 1 : 0,
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
      });

      final response = await _dioClient.instance.post<Map<String, dynamic>>(
        '${ApiConfig.apiMethodPath}/${ApiConfig.uploadFileMethod}',
        data: formData,
        options: Options(contentType: Headers.multipartFormDataContentType),
      );

      return _readResponseMap(response.data);
    } on DioException catch (error) {
      throw _dioClient.parseError(error);
    } catch (error) {
      throw _unknownApiError(error);
    }
  }

  Map<String, dynamic> _readResponseMap(Map<String, dynamic>? data) {
    if (data == null) return <String, dynamic>{};

    final exception = data['exception'];
    if (exception is String && exception.trim().isNotEmpty) {
      throw ApiError(message: _cleanMessage(exception), details: data);
    }

    return data;
  }

  String? _extractCookieHeader(List<String>? setCookieHeaders) {
    if (setCookieHeaders == null || setCookieHeaders.isEmpty) return null;

    final cookieParts = <String>[];

    for (final header in setCookieHeaders) {
      final firstSegment = header.split(';').first.trim();
      if (firstSegment.contains('=')) {
        cookieParts.add(firstSegment);
      }
    }

    if (cookieParts.isEmpty) return null;
    return cookieParts.join('; ');
  }

  String? _extractCookieFromBody(Map<String, dynamic> data) {
    final possibleCookie = data['session_cookie'] ?? data['cookie'];
    if (possibleCookie is String && possibleCookie.trim().isNotEmpty) {
      return possibleCookie.trim();
    }

    final sid = data['sid'];
    if (sid is String && sid.trim().isNotEmpty) {
      return 'sid=${sid.trim()}';
    }

    final message = data['message'];
    if (message is Map<String, dynamic>) {
      final nestedCookie = message['session_cookie'] ?? message['cookie'];
      if (nestedCookie is String && nestedCookie.trim().isNotEmpty) {
        return nestedCookie.trim();
      }

      final nestedSid = message['sid'];
      if (nestedSid is String && nestedSid.trim().isNotEmpty) {
        return 'sid=${nestedSid.trim()}';
      }
    }

    return null;
  }

  ApiError _unknownApiError(Object error) {
    if (error is ApiError) return error;

    return ApiError(
      message: 'Something went wrong while talking to the OMC server.',
      details: error,
    );
  }

  String _cleanMessage(String value) {
    return value
        .replaceAll(RegExp(r'<[^>]*>'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}
