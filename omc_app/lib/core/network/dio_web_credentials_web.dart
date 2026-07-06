import 'package:dio/browser.dart';
import 'package:dio/dio.dart';

void configureWebCredentials(Dio dio) {
  dio.httpClientAdapter = BrowserHttpClientAdapter()..withCredentials = true;
}
