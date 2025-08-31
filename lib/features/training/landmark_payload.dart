// lib/features/training/landmark_payload.dart
import 'landmark_parser.dart';

/// 백엔드에 보낼 캡처 페이로드
class CapturePayload {
  final String uid;         // 로그인된 사용자 ID (외부에서 주입)
  final String sessionId;   // 세션/트레이닝 식별자
  final DateTime capturedAt;
  final List<ParsedLandmark> landmarks;

  CapturePayload({
    required this.uid,
    required this.sessionId,
    required this.capturedAt,
    required this.landmarks,
  });

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'sessionId': sessionId,
        'capturedAt': capturedAt.toIso8601String(),
        'landmarks': landmarks.map((e) => e.toJson()).toList(),
      };
}
