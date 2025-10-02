/// 표정 점수 변환 유틸리티
/// 0.0~1.0 범위의 정규화된 점수를 0~100 범위로 변환
class ScoreConverter {
  /// 기본 생성자 (사용하지 않음)
  ScoreConverter._();

  /// 정규화된 점수(0.0~1.0)를 표시용 점수(0~100)로 변환
  ///
  /// [normalizedScore] 0.0~1.0 범위의 정규화된 점수
  /// Returns: 0~100 범위의 표시용 점수
  static double toDisplayScore(double normalizedScore) {
    return (normalizedScore * 100.0).clamp(0.0, 100.0);
  }

  /// 표시용 점수(0~100)를 정규화된 점수(0.0~1.0)로 역변환
  ///
  /// [displayScore] 0~100 범위의 표시용 점수
  /// Returns: 0.0~1.0 범위의 정규화된 점수
  static double toNormalizedScore(double displayScore) {
    return (displayScore / 100.0).clamp(0.0, 1.0);
  }

  /// 점수 리스트의 평균을 계산하여 표시용 점수로 변환
  ///
  /// [scores] 정규화된 점수 리스트
  /// Returns: 0~100 범위의 평균 표시용 점수
  static double calculateAverageDisplayScore(List<double> scores) {
    if (scores.isEmpty) return 0.0;
    final average = scores.reduce((a, b) => a + b) / scores.length;
    return toDisplayScore(average);
  }

  /// 점수 해석 레벨 반환
  ///
  /// [displayScore] 0~100 범위의 표시용 점수
  /// Returns: 점수 레벨 설명
  static String getScoreLevel(double displayScore) {
    if (displayScore < 20.0) return '매우 약함';
    if (displayScore < 40.0) return '약함';
    if (displayScore < 60.0) return '보통';
    if (displayScore < 80.0) return '강함';
    return '매우 강함';
  }

  /// 점수에 따른 색상 반환
  ///
  /// [displayScore] 0~100 범위의 표시용 점수
  /// Returns: 점수에 맞는 색상 코드
  static int getScoreColor(double displayScore) {
    if (displayScore < 20.0) return 0xFF9E9E9E; // 회색
    if (displayScore < 40.0) return 0xFFE57373; // 연한 빨강
    if (displayScore < 60.0) return 0xFFFFB74D; // 주황
    if (displayScore < 80.0) return 0xFF81C784; // 연한 초록
    return 0xFF4CAF50; // 초록
  }
}
