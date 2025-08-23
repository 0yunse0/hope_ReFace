import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';

class AuthApi {
  final Dio _dio = ApiClient.dio;

  Future<Map<String, dynamic>> signup(Map<String, dynamic> body) async {
    final r = await _dio.post('/auth/signup', data: body);
    return r.data;
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final r = await _dio.post('/auth/login', data: {'email': email, 'password': password});
    return r.data;
  }

  Future<void> logout() async => _dio.post('/auth/logout');

  Future<void> passwordReset(String email) async =>
      _dio.post('/auth/password-reset', data: {'email': email});

  Future<void> withdraw(String password) async =>
      _dio.delete('/auth/withdraw', data: {'password': password});
}
