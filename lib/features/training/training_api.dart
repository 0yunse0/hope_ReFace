import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:reface/core/network/api_client.dart';

class TrainingApi {
  final ApiClient _api;
  TrainingApi(this._api);

  Future<String> startSession(String expr) async {
    final res = await _api.post('/training/sessions', {'expr': expr});
    if (res.statusCode != 200) {
      throw Exception('startSession failed: ${res.statusCode} ${res.body}');
    }
    final j = jsonDecode(res.body);
    return j['sid'] as String;
  }

  /// frames: 15개
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

  Future<Map<String, dynamic>> finalizeSession(String sid, {String? summary}) async {
    final res = await _api.put('/training/sessions/$sid', {
      if (summary != null) 'summary': summary,
    });
    if (res.statusCode != 200) {
      throw Exception('finalizeSession failed: ${res.statusCode} ${res.body}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  Future<List<dynamic>> listSessions() async {
    final res = await _api.get('/training/sessions');
    if (res.statusCode != 200) {
      throw Exception('listSessions failed: ${res.statusCode} ${res.body}');
    }
    final j = jsonDecode(res.body);
    return j['sessions'] as List<dynamic>;
  }

  Future<Map<String, dynamic>> getSession(String sid) async {
    final res = await _api.get('/training/sessions/$sid');
    if (res.statusCode != 200) {
      throw Exception('getSession failed: ${res.statusCode} ${res.body}');
    }
    final j = jsonDecode(res.body);
    return j['session'] as Map<String, dynamic>;
  }

  /// 테스트/로그용 단순 캡처 전송
  Future<void> sendCapture(Map<String, dynamic> payload) async {
    final res = await _api.post('/training/captures', payload);
    if (res.statusCode != 200) {
      throw Exception('sendCapture failed: ${res.statusCode} ${res.body}');
    }
  }

  // -------- 테스트용 랜덤 프레임 생성기 --------
  /// 랜덤 15프레임(48/54와 기타 키 포함)을 만든다.
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
          'x': 100 + rnd.nextInt(80) + (t % 5), // 살짝 변화
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
