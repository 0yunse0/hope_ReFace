import 'dart:convert';
import 'package:http/http.dart' as http;
import 'landmark_payload.dart';
import '../../env.dart';

/// API 베이스 URL만 바꿔 쓰세요.
/// 예) https://your-cloud-functions-url.com  또는  http://10.0.2.2:5001/project/region
class TrainingApi {
  TrainingApi({required this.baseUrl, this.authToken});

  final String baseUrl;     // ex) "https://example.com"
  final String? authToken;  // 필요 시 Bearer 토큰

  /// POST /training/captures 로 전송 (엔드포인트는 원하는 대로 수정)
  Future<void> sendCapture(CapturePayload payload) async {
    final uri = Uri.parse('$baseUrl/training/captures');

    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (authToken != null && authToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }

    final resp = await http.post(
      uri,
      headers: headers,
      body: jsonEncode(payload.toJson()),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception(
          'sendCapture failed [${resp.statusCode}]: ${resp.body}');
    }
  }
}
