// lib/services/training_service.dart
import 'package:dio/dio.dart';
import '../core/api_client.dart';

/// 훈련(Training) 관련 API 호출 모음
class TrainingService {
  final Dio _dio = ApiClient().dio;

  /// 세션 목록 조회
  Future<List<dynamic>> listSessions() async {
    final r = await _dio.get('/training/sessions');
    return r.data as List<dynamic>;
  }

  /// 특정 세션 상세 조회
  Future<Map<String, dynamic>> getSession(String sessionId) async {
    final r = await _dio.get('/training/sessions/$sessionId');
    return r.data as Map<String, dynamic>;
  }

  /// 새로운 세션 시작
  Future<Map<String, dynamic>> startSession({
    required String expression, // 예: "smile", "angry"
  }) async {
    final r = await _dio.post('/training/sessions', data: {
      'expression': expression,
    });
    return r.data as Map<String, dynamic>;
  }

  /// 세트 결과 업로드
  Future<void> uploadSetResult({
    required String sessionId,
    required int setIndex,
    required Map<String, dynamic> result,
  }) async {
    await _dio.post('/training/sessions/$sessionId/sets', data: {
      'setIndex': setIndex,
      'result': result,
    });
  }

  /// 세션 최종 진척도 저장
  Future<void> uploadProgress({
    required String sessionId,
    required double progress,
  }) async {
    await _dio.post('/training/sessions/$sessionId/progress', data: {
      'progress': progress,
    });
  }

  /// 훈련 통계 조회 (트렌드)
  Future<Map<String, dynamic>> getStatisticsTrend() async {
    final r = await _dio.get('/training/statistics/trend');
    return r.data as Map<String, dynamic>;
  }

  /// 훈련 통계 조회 (개요)
  Future<Map<String, dynamic>> getStatisticsOverview() async {
    final r = await _dio.get('/training/statistics/overview');
    return r.data as Map<String, dynamic>;
  }
}
