import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omc_app/core/network/dio_client.dart';
import 'package:omc_app/core/storage/secure_storage_service.dart';

void main() {
  late DioClient client;

  setUp(() {
    client = DioClient(
      secureStorageService: SecureStorageService(),
      dio: Dio(BaseOptions(baseUrl: 'https://erp.omchouse.com')),
    );
  });

  test('401 is a session-expired error', () {
    final error = client.parseError(_responseError(401));

    expect(error.statusCode, 401);
    expect(error.message, contains('session has expired'));
    expect(error.message, isNot(contains('password')));
  });

  test('403 is an authorization error and not a login error', () {
    final error = client.parseError(_responseError(403));

    expect(error.statusCode, 403);
    expect(error.message, contains('permission'));
    expect(error.message, isNot(contains('password')));
  });
}

DioException _responseError(int statusCode) {
  final request = RequestOptions(path: '/api/method/test');
  return DioException(
    requestOptions: request,
    type: DioExceptionType.badResponse,
    response: Response<dynamic>(
      requestOptions: request,
      statusCode: statusCode,
      data: {'message': 'unsafe backend detail'},
    ),
  );
}
