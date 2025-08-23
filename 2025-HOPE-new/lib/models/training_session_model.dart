import 'dart:convert';
import 'smile_score_model.dart';

/// 훈련 세션 데이터 모델
/// 얼굴 표정 훈련 세션의 정보를 저장하는 immutable 클래스
class TrainingSessionModel {
  /// 세션 ID
  final String sessionId;

  /// 세션 시작 시간
  final DateTime startTime;

  /// 세션 종료 시간 (null이면 진행 중)
  final DateTime? endTime;

  /// 훈련 주제
  final String trainingTopic;

  /// 웃음 점수 기록 리스트
  final List<SmileScoreModel> scoreHistory;

  /// 최고 점수
  final double maxScore;

  /// 평균 점수
  final double averageScore;

  /// 세션 상태
  final TrainingSessionStatus status;

  const TrainingSessionModel({
    required this.sessionId,
    required this.startTime,
    this.endTime,
    required this.trainingTopic,
    required this.scoreHistory,
    required this.maxScore,
    required this.averageScore,
    required this.status,
  });

  /// JSON에서 TrainingSessionModel 생성
  factory TrainingSessionModel.fromJson(Map<String, dynamic> json) {
    return TrainingSessionModel(
      sessionId: json['sessionId'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: json['endTime'] != null
          ? DateTime.parse(json['endTime'] as String)
          : null,
      trainingTopic: json['trainingTopic'] as String,
      scoreHistory: (json['scoreHistory'] as List)
          .map((e) => SmileScoreModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      maxScore: (json['maxScore'] as num).toDouble(),
      averageScore: (json['averageScore'] as num).toDouble(),
      status: TrainingSessionStatus.values.firstWhere(
        (e) => e.name == json['status'],
      ),
    );
  }

  /// TrainingSessionModel을 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'trainingTopic': trainingTopic,
      'scoreHistory': scoreHistory.map((e) => e.toJson()).toList(),
      'maxScore': maxScore,
      'averageScore': averageScore,
      'status': status.name,
    };
  }

  /// JSON 문자열에서 TrainingSessionModel 생성
  factory TrainingSessionModel.fromJsonString(String jsonString) {
    return TrainingSessionModel.fromJson(jsonDecode(jsonString));
  }

  /// TrainingSessionModel을 JSON 문자열로 변환
  String toJsonString() {
    return jsonEncode(toJson());
  }

  /// 세션 지속 시간 (초)
  int get durationInSeconds {
    final end = endTime ?? DateTime.now();
    return end.difference(startTime).inSeconds;
  }

  /// 세션 지속 시간 (분)
  double get durationInMinutes => durationInSeconds / 60;

  /// 세션이 진행 중인지 확인
  bool get isActive => status == TrainingSessionStatus.active;

  /// 세션이 완료되었는지 확인
  bool get isCompleted => status == TrainingSessionStatus.completed;

  /// 세션이 일시정지되었는지 확인
  bool get isPaused => status == TrainingSessionStatus.paused;

  /// 최고 점수를 퍼센트로 변환
  int get maxScorePercentage => (maxScore * 100).round();

  /// 평균 점수를 퍼센트로 변환
  int get averageScorePercentage => (averageScore * 100).round();

  /// 복사본 생성 (특정 필드만 변경)
  TrainingSessionModel copyWith({
    String? sessionId,
    DateTime? startTime,
    DateTime? endTime,
    String? trainingTopic,
    List<SmileScoreModel>? scoreHistory,
    double? maxScore,
    double? averageScore,
    TrainingSessionStatus? status,
  }) {
    return TrainingSessionModel(
      sessionId: sessionId ?? this.sessionId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      trainingTopic: trainingTopic ?? this.trainingTopic,
      scoreHistory: scoreHistory ?? this.scoreHistory,
      maxScore: maxScore ?? this.maxScore,
      averageScore: averageScore ?? this.averageScore,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TrainingSessionModel &&
        other.sessionId == sessionId &&
        other.startTime == startTime &&
        other.endTime == endTime &&
        other.trainingTopic == trainingTopic &&
        other.maxScore == maxScore &&
        other.averageScore == averageScore &&
        other.status == status;
  }

  @override
  int get hashCode {
    return Object.hash(
      sessionId,
      startTime,
      endTime,
      trainingTopic,
      maxScore,
      averageScore,
      status,
    );
  }

  @override
  String toString() {
    return 'TrainingSessionModel(sessionId: $sessionId, startTime: $startTime, endTime: $endTime, trainingTopic: $trainingTopic, maxScore: $maxScore, averageScore: $averageScore, status: $status)';
  }
}

/// 훈련 세션 상태 열거형
enum TrainingSessionStatus {
  /// 활성 상태 (진행 중)
  active,

  /// 일시정지 상태
  paused,

  /// 완료 상태
  completed,

  /// 취소 상태
  cancelled,
}
