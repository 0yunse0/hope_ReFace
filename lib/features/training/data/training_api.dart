import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';

class TrainingApi {
  final Dio _dio = ApiClient.dio;

  Future<List<dynamic>> listSessions({int page = 1}) async {
    final r = await _dio.get('/training/sessions', queryParameters: {'page': page});
    return (r.data as List);
  }

  Future<Map<String, dynamic>> getSession(String id) async {
    final r = await _dio.get('/training/sessions/$id');
    return (r.data as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> createSession(Map<String, dynamic> body) async {
    final r = await _dio.post('/training/sessions', data: body);
    return (r.data as Map<String, dynamic>);
  }

  Future<void> saveSet(String id, Map<String, dynamic> setBody) async {
    await _dio.post('/training/sessions/$id/sets', data: setBody);
  }

  Future<Map<String, dynamic>> progress(String id, Map<String, dynamic> body) async {
    final r = await _dio.post('/training/sessions/$id/progress', data: body);
    return r.data;
  }

  Future<Map<String, dynamic>> overview() async {
    final r = await _dio.get('/training/statistics/overview');
    return r.data;
  }

  Future<List<dynamic>> trend() async {
    final r = await _dio.get('/training/statistics/trend');
    return (r.data as List);
  }

  Future<Response<dynamic>> exportRecords() async {
    // 필요 시 responseType.bytes 로 파일 다운로드 처리
    return _dio.get('/training/export', options: Options(responseType: ResponseType.bytes));
  }

  Future<List<String>> expressions() async {
    final r = await _dio.get('/training/expressions');
    return (r.data as List).cast<String>();
  }
}