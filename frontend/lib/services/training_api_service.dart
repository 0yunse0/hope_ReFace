// ## 파일: lib/services/training_api_service.dart ##

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

import '../config/app_config.dart';

class TrainingApiService {
  final http.Client _client;
  TrainingApiService({http.Client? client}) : _client = client ?? http.Client();

  // ---------------------- Helpers ----------------------

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final base = Uri.parse('${AppConfig.apiBaseUrl}$path');
    if (query == null || query.isEmpty) return base;

    final qp = <String, String>{};
    query.forEach((k, v) {
      if (v == null) return;
      final s = '$v';
      if (s.isEmpty) return;
      qp[k] = s;
    });
    return base.replace(queryParameters: qp);
  }

  Future<Map<String, String>> _headers({bool forceRefresh = false}) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken(forceRefresh);
      return {
        'Content-Type': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };
    } catch (_) {
      return {'Content-Type': 'application/json'};
    }
  }

  void _ok(String m) => print('\x1B[32m[OK] $m\x1B[0m');
  void _err(String m) => print('\x1B[31m[ERR] $m\x1B[0m');
  void _401() => print('\x1B[33m[401] retry with fresh token\x1B[0m');

  // ---------------------- Endpoints ----------------------

  Future<Map<String, dynamic>> fetchSessions({
    String? expr,
    String? status,
    DateTime? from,
    DateTime? to,
    int pageSize = 20,
    String? pageToken,
  }) async {
    final url = _uri('/training/sessions', {
      if (expr != null) 'expr': expr,
      if (status != null) 'status': status,
      if (from != null) 'from': from.toIso8601String(),
      if (to != null) 'to': to.toIso8601String(),
      'pageSize': pageSize,
      if (pageToken != null) 'pageToken': pageToken,
    });

    var res = await _client
        .get(url, headers: await _headers())
        .timeout(const Duration(seconds: 20));

    if (res.statusCode == 401) {
      _401();
      res = await _client
          .get(url, headers: await _headers(forceRefresh: true))
          .timeout(const Duration(seconds: 20));
    }

    if (res.statusCode == 200) {
      _ok('fetchSessions 200');
      final decoded = jsonDecode(res.body);
      if (decoded is Map<String, dynamic>) {
        decoded.putIfAbsent('sessions', () => decoded['items'] ?? const []);
        decoded.putIfAbsent('nextPageToken', () => decoded['nextToken']);
        return decoded;
      }
      return {'sessions': decoded, 'nextPageToken': null};
    }

    _err('fetchSessions ${res.statusCode} ${res.body}');
    throw Exception('세션 목록 실패 (${res.statusCode})');
  }

  Future<String> startSession(String expr) async {
    final url = _uri('/training/sessions');
    final body = jsonEncode({'expr': expr});

    var res = await _client
        .post(url, headers: await _headers(), body: body)
        .timeout(const Duration(seconds: 20));

    if (res.statusCode == 401) {
      _401();
      res = await _client
          .post(url, headers: await _headers(forceRefresh: true), body: body)
          .timeout(const Duration(seconds: 20));
    }

    if (res.statusCode == 200 || res.statusCode == 201) {
      final map = jsonDecode(res.body) as Map<String, dynamic>;
      final sid = (map['sid'] ?? map['id'])?.toString();
      if (sid == null || sid.isEmpty) {
        _err('startSession: missing sid. body=${res.body}');
        throw Exception('세션 시작 실패(응답 sid 없음)');
      }
      _ok('startSession sid=$sid');
      return sid;
    }

    _err('startSession ${res.statusCode} ${res.body}');
    throw Exception('세션 시작 실패 (${res.statusCode})');
  }

  Future<Map<String, dynamic>> fetchSessionDetail(String sid) async {
    final url = _uri('/training/sessions/$sid');

    var res = await _client
        .get(url, headers: await _headers())
        .timeout(const Duration(seconds: 20));

    if (res.statusCode == 401) {
      _401();
      res = await _client
          .get(url, headers: await _headers(forceRefresh: true))
          .timeout(const Duration(seconds: 20));
    }

    if (res.statusCode == 200) {
      _ok('fetchSessionDetail 200');
      return jsonDecode(res.body) as Map<String, dynamic>;
    }

    _err('fetchSessionDetail ${res.statusCode} ${res.body}');
    throw Exception('세션 상세 실패 (${res.statusCode})');
  }

  Future<Map<String, dynamic>> closeSession({
    required String sid,
    String? summary,
    double? finalScore,
  }) async {
    final url = _uri('/training/sessions/$sid');
    final body = jsonEncode({
      if (summary != null) 'summary': summary,
      if (finalScore != null) 'finalScore': finalScore,
    });

    var res = await _client
        .put(url, headers: await _headers(), body: body)
        .timeout(const Duration(seconds: 20));

    if (res.statusCode == 401) {
      _401();
      res = await _client
          .put(url, headers: await _headers(forceRefresh: true), body: body)
          .timeout(const Duration(seconds: 20));
    }

    if (res.statusCode == 200) {
      _ok('closeSession 200');
      return jsonDecode(res.body) as Map<String, dynamic>;
    }

    _err('closeSession ${res.statusCode} ${res.body}');
    throw Exception('세션 마감 실패 (${res.statusCode})');
  }

  /// 저장된 초기 표정 점수 조회
  Future<Map<String, dynamic>> fetchInitialScores() async {
    final url = _uri(AppConfig.firstfacePath());

    var res = await _client
        .get(url, headers: await _headers())
        .timeout(const Duration(seconds: 20));

    if (res.statusCode == 401) {
      _401();
      res = await _client
          .get(url, headers: await _headers(forceRefresh: true))
          .timeout(const Duration(seconds: 20));
    }

    if (res.statusCode == 200) {
      _ok('fetchInitialScores 200');
      return jsonDecode(res.body) as Map<String, dynamic>;
    }

    if (res.statusCode == 404) {
      _ok('fetchInitialScores 404: No initial scores found.');
      return {'expressionScores': {}};
    }

    _err('fetchInitialScores ${res.statusCode} ${res.body}');
    throw Exception('초기 점수 조회 실패 (${res.statusCode})');
  }

  /// 훈련 추천 조회
  Future<List<Map<String, dynamic>>> fetchTrainingRecommendations({
    String? expr,
    int? limit,
  }) async {
    final url = _uri(AppConfig.trainingRecommendationsPath(), {
      if (expr != null) 'expr': expr,
      if (limit != null) 'limit': limit,
    });

    var res = await _client
        .get(url, headers: await _headers())
        .timeout(const Duration(seconds: 20));

    if (res.statusCode == 401) {
      _401();
      res = await _client
          .get(url, headers: await _headers(forceRefresh: true))
          .timeout(const Duration(seconds: 20));
    }

    if (res.statusCode == 200) {
      _ok('fetchTrainingRecommendations 200');
      // 응답 본문 샘플 출력 (최대 1000자)
      try {
        final body = res.body;
        if (body.isNotEmpty) {
          final lim = body.length > 1000 ? 1000 : body.length;
          print('[REC_BODY] ' + body.substring(0, lim));
        } else {
          print('[REC_BODY] <empty>');
        }
      } catch (_) {}
      final decoded = jsonDecode(res.body);
      if (decoded is List) {
        return decoded.whereType<Map<String, dynamic>>().toList(
          growable: false,
        );
      }
      if (decoded is Map<String, dynamic>) {
        final list = (decoded['recommendations'] ?? decoded['items']);
        if (list is List) {
          return list.whereType<Map<String, dynamic>>().toList(growable: false);
        }
        // 단일 객체만 내려오는 경우
        return <Map<String, dynamic>>[decoded];
      }
      return const <Map<String, dynamic>>[];
    }

    _err('fetchTrainingRecommendations ${res.statusCode} ${res.body}');
    throw Exception('훈련 추천 조회 실패 (${res.statusCode})');
  }
}
