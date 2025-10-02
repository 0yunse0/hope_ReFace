import 'dart:convert';

/// 웃음 점수 데이터 모델
/// 얼굴 감지를 통해 계산된 웃음 점수를 저장하는 immutable 클래스
class SmileScoreModel {
  /// 웃음 점수 (0.0 ~ 1.0)
  final double score;

  /// 점수 계산 시간
  final DateTime timestamp;

  /// 얼굴이 감지되었는지 여부
  final bool isFaceDetected;

  /// 신뢰도 (0.0 ~ 1.0)
  final double confidence;

  const SmileScoreModel({
    required this.score,
    required this.timestamp,
    required this.isFaceDetected,
    required this.confidence,
  });

  /// JSON에서 SmileScoreModel 생성
  factory SmileScoreModel.fromJson(Map<String, dynamic> json) {
    return SmileScoreModel(
      score: (json['score'] as num).toDouble(),
      timestamp: DateTime.parse(json['timestamp'] as String),
      isFaceDetected: json['isFaceDetected'] as bool,
      confidence: (json['confidence'] as num).toDouble(),
    );
  }

  /// SmileScoreModel을 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'score': score,
      'timestamp': timestamp.toIso8601String(),
      'isFaceDetected': isFaceDetected,
      'confidence': confidence,
    };
  }

  /// JSON 문자열에서 SmileScoreModel 생성
  factory SmileScoreModel.fromJsonString(String jsonString) {
    return SmileScoreModel.fromJson(jsonDecode(jsonString));
  }

  /// SmileScoreModel을 JSON 문자열로 변환
  String toJsonString() {
    return jsonEncode(toJson());
  }

  /// 점수를 퍼센트로 변환 (0-100)
  int get scorePercentage => (score * 100).round();

  /// 높은 점수인지 확인 (80% 이상)
  bool get isHighScore => score >= 0.8;

  /// 중간 점수인지 확인 (60-79%)
  bool get isMediumScore => score >= 0.6 && score < 0.8;

  /// 낮은 점수인지 확인 (60% 미만)
  bool get isLowScore => score < 0.6;

  /// 복사본 생성 (특정 필드만 변경)
  SmileScoreModel copyWith({
    double? score,
    DateTime? timestamp,
    bool? isFaceDetected,
    double? confidence,
  }) {
    return SmileScoreModel(
      score: score ?? this.score,
      timestamp: timestamp ?? this.timestamp,
      isFaceDetected: isFaceDetected ?? this.isFaceDetected,
      confidence: confidence ?? this.confidence,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SmileScoreModel &&
        other.score == score &&
        other.timestamp == timestamp &&
        other.isFaceDetected == isFaceDetected &&
        other.confidence == confidence;
  }

  @override
  int get hashCode {
    return Object.hash(score, timestamp, isFaceDetected, confidence);
  }

  @override
  String toString() {
    return 'SmileScoreModel(score: $score, timestamp: $timestamp, isFaceDetected: $isFaceDetected, confidence: $confidence)';
  }
}
