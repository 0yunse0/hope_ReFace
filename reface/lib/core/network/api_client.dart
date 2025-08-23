import 'package:dio/dio.dart';
import '../config/env.dart';
import 'interceptors.dart';

class ApiClient {
  ApiClient._();
  static final Dio dio = () {
    final d = Dio(BaseOptions(
      baseUrl: Env.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      headers: {'Content-Type': 'application/json'},
    ));
    d.interceptors.addAll([
      AuthInterceptor(),
      LogInterceptor(requestBody: true, responseBody: true),
    ]);
    return d;
  }();
}
