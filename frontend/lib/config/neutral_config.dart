// 무표정(Neutral) 감지 파라미터 설정
// 필요 시 실험으로 튜닝 가능하게 상수로 분리

class NeutralConfig {
  static const double neutralSmileMax = 0.25; // 진입/유지 상한(EWMA)
  static const double neutralSmileMaxExit = 0.35; // 이탈 히스테리시스 상한(EWMA)

  static const double maxMouthCornerDelta = 0.07; // 입꼬리 거리 변화 허용치(정규화)
  static const double maxMouthOpenDelta = 0.09; // 입벌림 변화 허용치(정규화)

  static const double neutralHoldSeconds = 3.0; // 조건 유지 시간

  static const int calibrationFrames = 20; // 기준값 캘리브레이션 프레임 수(완화)

  static const double emaAlpha = 0.5; // EWMA 알파(반응성↑)

  // 디버그 패널 토글(필요 시 UI에서 제어)
  static const bool debugPanelEnabled = false;
}
