import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';

class UserApi {
  final Dio _dio = ApiClient.dio;

  Future<Map<String, dynamic>> getNotifications() async {
    final r = await _dio.get('/user/notifications');
    return r.data;
  }

  Future<void> updateNotifications(Map<String, dynamic> body) async {
    await _dio.put('/user/notifications', data: body);
  }

  Future<void> postInitialFace(MultipartFile file) async {
    final form = FormData.fromMap({'file': file});
    await _dio.post('/user/initial-face', data: form);
  }

  Future<void> putInitialFace(MultipartFile file) async {
    final form = FormData.fromMap({'file': file});
    await _dio.put('/user/initial-face', data: form);
  }
}
