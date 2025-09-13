// lib/features/training/training_api.dart
import 'dart:convert';
import 'dart:math';
import 'package:reface/core/network/api_client.dart';

class TrainingApi {
  final ApiClient _api;
  TrainingApi(this._api);

  // === 새 세션 시작 ===
  Future<String> startSession(String expr) async {
    final res = await _api.post('/training/sessions', {'expr': expr});
    if (res.statusCode != 200) {
      throw Exception('startSession failed: ${res.statusCode} ${res.body}');
    }
    final j = jsonDecode(res.body);
    final sid = j['sid'] as String?;
    if (sid == null || sid.isEmpty) {
      throw Exception('startSession failed: invalid response: ${res.body}');
    }
    return sid;
  }

  // === 추천 훈련 조회 ===
  Future<Map<String, dynamic>> getRecommendations({int limit = 3}) async {
    final res = await _api.get('/training/recommendations?limit=$limit');

    // 혹시 /recommendations 별칭만 열려있는 경우 대비 폴백
    if (res.statusCode == 404) {
      final alt = await _api.get('/recommendations?limit=$limit');
      if (alt.statusCode != 200) {
        throw Exception('recommendations failed: ${alt.statusCode} ${alt.body}');
      }
      return jsonDecode(alt.body) as Map<String, dynamic>;
    }

    if (res.statusCode != 200) {
      throw Exception('recommendations failed: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // === 세트 저장 (15프레임 + 마지막 이미지) ===
  Future<Map<String, dynamic>> saveSet({
    required String sid,
    required Map<String, dynamic> baseline,
    required Map<String, dynamic> reference,
    required List<Map<String, dynamic>> frames,
    Map<String, dynamic>? weights,
  }) async {
    final body = {
      'baseline': baseline,
      'reference': reference,
      'frames': frames,
      'weights': weights,
    };
    final res = await _api.post('/training/sessions/$sid/sets', body);
    if (res.statusCode != 200) {
      throw Exception('saveSet failed: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // === 세션 마감 ===
  Future<Map<String, dynamic>> finalizeSession(String sid, {String? summary}) async {
    final res = await _api.put('/training/sessions/$sid', {
      if (summary != null) 'summary': summary,
    });
    if (res.statusCode != 200) {
      throw Exception('finalizeSession failed: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // === 단순 목록 ===
  Future<List<dynamic>> listSessions() async {
    final res = await _api.get('/training/sessions');
    if (res.statusCode != 200) {
      throw Exception('listSessions failed: ${res.statusCode} ${res.body}');
    }
    final j = jsonDecode(res.body);
    return j['sessions'] as List<dynamic>;
  }

  // === 필터/페이지네이션 목록 ===
  Future<Map<String, dynamic>> listSessionsFiltered({
    String? expr,
    String? status,
    DateTime? from,
    DateTime? to,
    int pageSize = 20,
    String? pageToken,
  }) async {
    final params = <String, String>{};
    if (expr != null) params['expr'] = expr;
    if (status != null) params['status'] = status;
    if (from != null) params['from'] = from.toUtc().toIso8601String();
    if (to != null) params['to'] = to.toUtc().toIso8601String();
    if (pageSize != 20) params['pageSize'] = '$pageSize';
    if (pageToken != null) params['pageToken'] = pageToken;

    final query = params.isEmpty
        ? ''
        : '?' +
            params.entries
                .map((e) =>
                    '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent(e.value)}')
                .join('&');

    final res = await _api.get('/training/sessions$query');
    if (res.statusCode != 200) {
      throw Exception('listSessionsFiltered failed: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // === 세션 상세 ===
  Future<Map<String, dynamic>> getSession(String sid) async {
    final res = await _api.get('/training/sessions/$sid');
    if (res.statusCode != 200) {
      throw Exception('getSession failed: ${res.statusCode} ${res.body}');
    }
    final j = jsonDecode(res.body);
    return j['session'] as Map<String, dynamic>;
  }

  // === 테스트/로그용 단순 캡처 ===
  Future<void> sendCapture(Map<String, dynamic> payload) async {
    final res = await _api.post('/training/captures', payload);
    if (res.statusCode != 200) {
      throw Exception('sendCapture failed: ${res.statusCode} ${res.body}');
    }
  }

  // -------- 테스트용 랜덤 프레임 생성기 --------
  List<Map<String, dynamic>> makeRandomFrames({
    required List<String> landmarkKeys,
    int frames = 15,
    int seed = 0,
    bool withImageOnLast = true,
  }) {
    final rnd = Random(seed);
    final out = <Map<String, dynamic>>[];
    for (int t = 0; t < frames; t++) {
      final curr = <String, dynamic>{};
      for (final k in landmarkKeys) {
        curr[k] = {
          'x': 100 + rnd.nextInt(80) + (t % 5),
          'y': 400 + rnd.nextInt(80) - (t % 4),
        };
      }
      final f = {'ts': t, 'current': curr};
      if (withImageOnLast && t == frames - 1) {
        f['imageBase64'] = 'data:image/png;base64,iVBORw0KGgo='; // 더미
      }
      out.add(f);
    }
    return out;
  }
}
