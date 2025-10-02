import 'dart:async';
import 'dart:math';

import 'package:get/get.dart';

import '../utils/constants.dart';
import '../utils/score_calculator.dart';

/// 점수 애니메이션 관리 컨트롤러
/// 웃음 점수의 애니메이션 효과, 점수 레벨, 시각적 피드백 등을 관리
class ScoreController extends GetxController {
  // 반응형 상태 변수들
  final RxDouble _currentScore = 0.0.obs;
  final RxDouble _displayScore = 0.0.obs;
  final RxString _scoreLevel = 'low'.obs;
  final RxBool _isAnimating = false.obs;
  final RxBool _showScoreEffect = false.obs;
  final RxString _scoreColor = '#FF9800'.obs; // 기본 주황색
  final RxDouble _scoreScale = 1.0.obs;
  final RxDouble _scoreOpacity = 1.0.obs;

  // 애니메이션 관련
  Timer? _animationTimer;
  Timer? _effectTimer;
  final RxBool _isScoreIncreasing = false.obs;
  final RxBool _isScoreDecreasing = false.obs;

  // 점수 히스토리
  final RxList<double> _scoreHistory = <double>[].obs;
  final RxDouble _averageScore = 0.0.obs;
  final RxDouble _maxScore = 0.0.obs;
  final RxDouble _minScore = 1.0.obs;

  // Getter 메서드들
  double get currentScore => _currentScore.value;
  double get displayScore => _displayScore.value;
  String get scoreLevel => _scoreLevel.value;
  bool get isAnimating => _isAnimating.value;
  bool get showScoreEffect => _showScoreEffect.value;
  String get scoreColor => _scoreColor.value;
  double get scoreScale => _scoreScale.value;
  double get scoreOpacity => _scoreOpacity.value;
  bool get isScoreIncreasing => _isScoreIncreasing.value;
  bool get isScoreDecreasing => _isScoreDecreasing.value;
  List<double> get scoreHistory => _scoreHistory;
  double get averageScore => _averageScore.value;
  double get maxScore => _maxScore.value;
  double get minScore => _minScore.value;

  // Observable getter들
  RxDouble get currentScoreRx => _currentScore;
  RxDouble get displayScoreRx => _displayScore;
  RxString get scoreLevelRx => _scoreLevel;
  RxBool get isAnimatingRx => _isAnimating;
  RxBool get showScoreEffectRx => _showScoreEffect;
  RxString get scoreColorRx => _scoreColor;
  RxDouble get scoreScaleRx => _scoreScale;
  RxDouble get scoreOpacityRx => _scoreOpacity;
  RxBool get isScoreIncreasingRx => _isScoreIncreasing;
  RxBool get isScoreDecreasingRx => _isScoreDecreasing;
  RxList<double> get scoreHistoryRx => _scoreHistory;
  RxDouble get averageScoreRx => _averageScore;
  RxDouble get maxScoreRx => _maxScore;
  RxDouble get minScoreRx => _minScore;

  @override
  void onClose() {
    _animationTimer?.cancel();
    _effectTimer?.cancel();
    super.onClose();
  }

  /// 점수 업데이트 (애니메이션 포함)
  void updateScore(double newScore) {
    if (newScore < 0.0 || newScore > 1.0) return;

    final oldScore = _currentScore.value;
    _currentScore.value = newScore;

    // 점수 히스토리에 추가
    _scoreHistory.add(newScore);
    _updateStatistics();

    // 점수 레벨 업데이트
    _updateScoreLevel(newScore);

    // 점수 색상 업데이트
    _updateScoreColor(newScore);

    // 애니메이션 효과 시작
    _startScoreAnimation(oldScore, newScore);

    // 점수 변화 방향 설정
    _isScoreIncreasing.value = newScore > oldScore;
    _isScoreDecreasing.value = newScore < oldScore;
  }

  /// 점수 레벨 업데이트
  void _updateScoreLevel(double score) {
    final level = ScoreCalculator.getScoreLevel(score);
    _scoreLevel.value = level;
  }

  /// 점수 색상 업데이트
  void _updateScoreColor(double score) {
    if (score >= AppConstants.highScoreThreshold) {
      _scoreColor.value = '#4CAF50'; // 녹색 (높은 점수)
    } else if (score >= AppConstants.mediumScoreThreshold) {
      _scoreColor.value = '#FF9800'; // 주황색 (중간 점수)
    } else if (score >= AppConstants.lowScoreThreshold) {
      _scoreColor.value = '#FFC107'; // 노란색 (낮은 점수)
    } else {
      _scoreColor.value = '#F44336'; // 빨간색 (매우 낮은 점수)
    }
  }

  /// 점수 애니메이션 시작
  void _startScoreAnimation(double oldScore, double newScore) {
    _animationTimer?.cancel();
    _isAnimating.value = true;

    final duration = AppConstants.scoreAnimationDuration;
    final steps = 30; // 애니메이션 단계
    final stepDuration = duration.inMilliseconds ~/ steps;
    final scoreDifference = newScore - oldScore;
    final scoreStep = scoreDifference / steps;

    int currentStep = 0;

    _animationTimer = Timer.periodic(Duration(milliseconds: stepDuration), (
      timer,
    ) {
      currentStep++;
      final progress = currentStep / steps;

      // 부드러운 애니메이션을 위한 easeInOut 효과
      final easedProgress = _easeInOut(progress);
      final currentDisplayScore = oldScore + (scoreDifference * easedProgress);

      _displayScore.value = currentDisplayScore;

      // 스케일 애니메이션
      if (currentStep <= steps / 2) {
        _scoreScale.value = 1.0 + (0.2 * (currentStep / (steps / 2)));
      } else {
        _scoreScale.value =
            1.2 - (0.2 * ((currentStep - steps / 2) / (steps / 2)));
      }

      if (currentStep >= steps) {
        _displayScore.value = newScore;
        _scoreScale.value = 1.0;
        _isAnimating.value = false;
        timer.cancel();

        // 점수 효과 표시
        _showScoreEffect.value = true;
        _effectTimer = Timer(const Duration(milliseconds: 500), () {
          _showScoreEffect.value = false;
        });
      }
    });
  }

  /// easeInOut 애니메이션 곡선
  double _easeInOut(double t) {
    return t < 0.5 ? 2 * t * t : -1 + (4 - 2 * t) * t;
  }

  /// 통계 업데이트
  void _updateStatistics() {
    if (_scoreHistory.isEmpty) return;

    final scores = _scoreHistory;
    _maxScore.value = scores.reduce((a, b) => a > b ? a : b);
    _minScore.value = scores.reduce((a, b) => a < b ? a : b);
    _averageScore.value = scores.reduce((a, b) => a + b) / scores.length;
  }

  /// 점수 리셋
  void resetScore() {
    _currentScore.value = 0.0;
    _displayScore.value = 0.0;
    _scoreLevel.value = 'low';
    _scoreColor.value = '#FF9800';
    _scoreScale.value = 1.0;
    _scoreOpacity.value = 1.0;
    _isAnimating.value = false;
    _showScoreEffect.value = false;
    _isScoreIncreasing.value = false;
    _isScoreDecreasing.value = false;
    _scoreHistory.clear();
    _averageScore.value = 0.0;
    _maxScore.value = 0.0;
    _minScore.value = 1.0;
  }

  /// 점수 히스토리 초기화
  void clearScoreHistory() {
    _scoreHistory.clear();
    _updateStatistics();
  }

  /// 점수 효과 강제 표시
  void triggerScoreEffect() {
    _showScoreEffect.value = true;
    _effectTimer?.cancel();
    _effectTimer = Timer(const Duration(milliseconds: 500), () {
      _showScoreEffect.value = false;
    });
  }

  /// 점수 애니메이션 강제 중지
  void stopAnimation() {
    _animationTimer?.cancel();
    _effectTimer?.cancel();
    _isAnimating.value = false;
    _showScoreEffect.value = false;
    _scoreScale.value = 1.0;
  }

  /// 점수 레벨별 색상 가져오기
  String getScoreLevelColor(String level) {
    switch (level) {
      case 'high':
        return '#4CAF50'; // 녹색
      case 'medium':
        return '#FF9800'; // 주황색
      case 'low':
        return '#FFC107'; // 노란색
      default:
        return '#F44336'; // 빨간색
    }
  }

  /// 점수 레벨별 메시지 가져오기
  String getScoreLevelMessage(String level) {
    switch (level) {
      case 'high':
        return AppConstants.feedbackMessages['high']!;
      case 'medium':
        return AppConstants.feedbackMessages['medium']!;
      case 'low':
        return AppConstants.feedbackMessages['low']!;
      default:
        return AppConstants.feedbackMessages['low']!;
    }
  }

  /// 점수 진행률 (0.0 ~ 1.0)
  double get scoreProgress => _currentScore.value;

  /// 점수 퍼센트 (0 ~ 100)
  int get scorePercentage => (_currentScore.value * 100).round();

  /// 점수 개선 여부 (이전 점수 대비)
  bool get isScoreImproving {
    if (_scoreHistory.length < 2) return false;
    final recentScores = _scoreHistory
        .take(_scoreHistory.length > 5 ? 5 : _scoreHistory.length)
        .toList();
    if (recentScores.length < 2) return false;

    // 최근 5개 점수의 평균이 이전보다 높은지 확인
    final recentAverage =
        recentScores.reduce((a, b) => a + b) / recentScores.length;
    final previousScores = _scoreHistory
        .take(_scoreHistory.length - 5)
        .toList();

    if (previousScores.isEmpty) return false;
    final previousAverage =
        previousScores.reduce((a, b) => a + b) / previousScores.length;

    return recentAverage > previousAverage;
  }

  /// 점수 안정성 (표준편차 기반)
  double get scoreStability {
    if (_scoreHistory.length < 2) return 1.0;

    final scores = _scoreHistory;
    final mean = scores.reduce((a, b) => a + b) / scores.length;
    final variance =
        scores
            .map((score) => (score - mean) * (score - mean))
            .reduce((a, b) => a + b) /
        scores.length;
    final standardDeviation = sqrt(variance);

    // 표준편차가 작을수록 안정적 (1.0에 가까울수록 안정적)
    return (1.0 - standardDeviation).clamp(0.0, 1.0);
  }
}
