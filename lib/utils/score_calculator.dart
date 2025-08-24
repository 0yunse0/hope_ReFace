import 'dart:math';
import '../models/smile_score_model.dart';
import 'constants.dart';

/// 웃음 점수 계산 유틸리티 클래스
/// MLKit 얼굴 감지 결과를 바탕으로 웃음 점수를 계산하는 순수 함수들
class ScoreCalculator {
  /// 기본 생성자 (사용하지 않음)
  ScoreCalculator._();

  /// 얼굴 특징점을 기반으로 웃음 점수 계산
  ///
  /// [mouthCorners] 입꼬리 좌표 리스트
  /// [eyeCorners] 눈꼬리 좌표 리스트
  /// [noseTip] 코 끝 좌표
  /// [confidence] 얼굴 감지 신뢰도
  ///
  /// Returns: 0.0 ~ 1.0 범위의 웃음 점수
  static double calculateSmileScore({
    required List<Map<String, double>> mouthCorners,
    required List<Map<String, double>> eyeCorners,
    required Map<String, double> noseTip,
    required double confidence,
  }) {
    if (confidence < 0.5) {
      return 0.0; // 신뢰도가 낮으면 0점
    }

    // 입꼬리 변화량 계산
    final mouthScore = _calculateMouthScore(mouthCorners);

    // 눈꼬리 변화량 계산
    final eyeScore = _calculateEyeScore(eyeCorners);

    // 코 위치 변화량 계산
    final noseScore = _calculateNoseScore(noseTip);

    // 가중 평균으로 최종 점수 계산
    final weightedScore =
        (mouthScore * 0.6) + (eyeScore * 0.3) + (noseScore * 0.1);

    // 0.0 ~ 1.0 범위로 정규화
    return _normalizeScore(weightedScore);
  }

  /// 입꼬리 변화량을 기반으로 점수 계산
  static double _calculateMouthScore(List<Map<String, double>> mouthCorners) {
    if (mouthCorners.length < 2) return 0.0;

    // 입꼬리 간의 거리 계산
    final leftCorner = mouthCorners[0];
    final rightCorner = mouthCorners[1];

    final distance = _calculateDistance(leftCorner, rightCorner);

    // 기준 거리 (일반적인 입 크기)
    const baseDistance = 50.0;

    // 거리가 클수록 웃음이 크다고 판단
    final score = (distance / baseDistance).clamp(0.0, 2.0) / 2.0;

    return score;
  }

  /// 눈꼬리 변화량을 기반으로 점수 계산
  static double _calculateEyeScore(List<Map<String, double>> eyeCorners) {
    if (eyeCorners.length < 4) return 0.0;

    // 양쪽 눈의 변화량 계산
    final leftEyeScore = _calculateSingleEyeScore(eyeCorners.take(2).toList());
    final rightEyeScore = _calculateSingleEyeScore(
      eyeCorners.skip(2).take(2).toList(),
    );

    return (leftEyeScore + rightEyeScore) / 2.0;
  }

  /// 단일 눈의 변화량 계산
  static double _calculateSingleEyeScore(List<Map<String, double>> eyeCorners) {
    if (eyeCorners.length < 2) return 0.0;

    final innerCorner = eyeCorners[0];
    final outerCorner = eyeCorners[1];

    final distance = _calculateDistance(innerCorner, outerCorner);

    // 기준 거리 (일반적인 눈 크기)
    const baseDistance = 30.0;

    // 거리가 작을수록 웃음이 크다고 판단 (눈이 찡그려짐)
    final score = (1.0 - (distance / baseDistance)).clamp(0.0, 1.0);

    return score;
  }

  /// 코 위치 변화량을 기반으로 점수 계산
  static double _calculateNoseScore(Map<String, double> noseTip) {
    // 코 위치는 웃음에 큰 영향을 주지 않으므로 기본값 반환
    return 0.5;
  }

  /// 두 점 간의 거리 계산
  static double _calculateDistance(
    Map<String, double> point1,
    Map<String, double> point2,
  ) {
    final dx = point1['x']! - point2['x']!;
    final dy = point1['y']! - point2['y']!;

    return sqrt(dx * dx + dy * dy);
  }

  /// 점수를 0.0 ~ 1.0 범위로 정규화
  static double _normalizeScore(double score) {
    return score.clamp(0.0, 1.0);
  }

  /// 점수 레벨 판단
  ///
  /// [score] 웃음 점수 (0.0 ~ 1.0)
  /// Returns: 점수 레벨 문자열
  static String getScoreLevel(double score) {
    if (score >= AppConstants.highScoreThreshold) {
      return 'high';
    } else if (score >= AppConstants.mediumScoreThreshold) {
      return 'medium';
    } else if (score >= AppConstants.lowScoreThreshold) {
      return 'low';
    } else {
      return 'very_low';
    }
  }

  /// 점수에 따른 피드백 메시지 반환
  ///
  /// [score] 웃음 점수 (0.0 ~ 1.0)
  /// Returns: 피드백 메시지
  static String getFeedbackMessage(double score) {
    final level = getScoreLevel(score);

    switch (level) {
      case 'high':
        return AppConstants.feedbackMessages['high']!;
      case 'medium':
        return AppConstants.feedbackMessages['medium']!;
      case 'low':
      case 'very_low':
        return AppConstants.feedbackMessages['low']!;
      default:
        return AppConstants.feedbackMessages['error']!;
    }
  }

  /// 점수 변화량 계산
  ///
  /// [currentScore] 현재 점수
  /// [previousScore] 이전 점수
  /// Returns: 점수 변화량 (-1.0 ~ 1.0)
  static double calculateScoreChange(
    double currentScore,
    double previousScore,
  ) {
    return _normalizeScore(currentScore - previousScore);
  }

  /// 점수 개선 여부 판단
  ///
  /// [currentScore] 현재 점수
  /// [previousScore] 이전 점수
  /// [threshold] 개선 임계값 (기본값: 0.1)
  /// Returns: 개선 여부
  static bool isScoreImproved(
    double currentScore,
    double previousScore, {
    double threshold = 0.1,
  }) {
    return (currentScore - previousScore) >= threshold;
  }

  /// 평균 점수 계산
  ///
  /// [scores] 점수 리스트
  /// Returns: 평균 점수
  static double calculateAverageScore(List<double> scores) {
    if (scores.isEmpty) return 0.0;

    final sum = scores.reduce((a, b) => a + b);
    return sum / scores.length;
  }

  /// 최고 점수 찾기
  ///
  /// [scores] 점수 리스트
  /// Returns: 최고 점수
  static double findMaxScore(List<double> scores) {
    if (scores.isEmpty) return 0.0;

    return scores.reduce((a, b) => a > b ? a : b);
  }

  /// 점수 통계 계산
  ///
  /// [scores] 점수 리스트
  /// Returns: 점수 통계 맵
  static Map<String, double> calculateScoreStatistics(List<double> scores) {
    if (scores.isEmpty) {
      return {'average': 0.0, 'max': 0.0, 'min': 0.0, 'standardDeviation': 0.0};
    }

    final average = calculateAverageScore(scores);
    final max = findMaxScore(scores);
    final min = scores.reduce((a, b) => a < b ? a : b);
    final standardDeviation = _calculateStandardDeviation(scores, average);

    return {
      'average': average,
      'max': max,
      'min': min,
      'standardDeviation': standardDeviation,
    };
  }

  /// 표준편차 계산
  static double _calculateStandardDeviation(List<double> scores, double mean) {
    if (scores.length < 2) return 0.0;

    final variance =
        scores
            .map((score) => (score - mean) * (score - mean))
            .reduce((a, b) => a + b) /
        scores.length;
    return sqrt(variance);
  }
}
