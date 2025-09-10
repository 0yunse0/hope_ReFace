// lib/features/training/send_capture_from_log.dart
import 'landmark_parser.dart';
import 'landmark_payload.dart';
import 'training_api.dart';
import 'package:reface/core/network/api_client.dart';
/// 카운트다운이 끝난 "그 순간의 로그 텍스트"를 넘기면,
/// 파싱 → API 전송까지 한 번에 수행합니다.
///
/// [uid]            : 현재 로그인한 사용자 ID(외부에서 주입)
/// [sessionId]      : 세션 식별자 (ex: 오늘 훈련 세션 ID)
/// [logText]        : I/flutter ... 형식의 여러 줄 로그 원문
/// [baseUrl]        : API 베이스 URL
/// [authToken]      : 필요 시 Authorization Bearer 토큰
Future<void> sendCaptureFromLog({
  required String uid,
  required String sessionId,
  required String logText,
  required String baseUrl,
  String? authToken,
}) async {
  // 1) 파싱
  final landmarks = parseLandmarksFromLog(logText);

  // 좌표가 하나도 없으면 스킵/에러
  if (landmarks.isEmpty) {
    throw Exception('No landmarks found in the given log.');
  }

  // 2) 페이로드 만들기
  final payload = CapturePayload(
    uid: uid,
    sessionId: sessionId,
    capturedAt: DateTime.now(),
    landmarks: landmarks,
  );

  // 3) 전송
  final client = ApiClient(baseUrl: baseUrl, authToken: authToken);
  final api = TrainingApi(client);
  await api.sendCapture(payload.toJson());
}
