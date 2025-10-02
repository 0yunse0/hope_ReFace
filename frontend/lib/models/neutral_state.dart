// 무표정(Neutral) 상태 및 메트릭 모델

enum NeutralPhase { idle, calibrating, tracking, success }

class NeutralBaseline {
  final double corner; // baselineCorner: 입꼬리 간 거리(정규화)
  final double open; // baselineOpen: 상/하 입술 간 거리(정규화)
  const NeutralBaseline({required this.corner, required this.open});

  NeutralBaseline copyWith({double? corner, double? open}) =>
      NeutralBaseline(corner: corner ?? this.corner, open: open ?? this.open);
}

class NeutralMetrics {
  final double smileProbEwma;
  final double deltaCorner; // abs((corner-current) / baselineCorner)
  final double deltaOpen; // abs((open-current) / baselineOpen)
  final double holdSeconds; // 현재 조건 유지 시간
  final int calibratedFrames; // 캘리브레이션 진행 프레임 수

  const NeutralMetrics({
    required this.smileProbEwma,
    required this.deltaCorner,
    required this.deltaOpen,
    required this.holdSeconds,
    required this.calibratedFrames,
  });

  NeutralMetrics copyWith({
    double? smileProbEwma,
    double? deltaCorner,
    double? deltaOpen,
    double? holdSeconds,
    int? calibratedFrames,
  }) {
    return NeutralMetrics(
      smileProbEwma: smileProbEwma ?? this.smileProbEwma,
      deltaCorner: deltaCorner ?? this.deltaCorner,
      deltaOpen: deltaOpen ?? this.deltaOpen,
      holdSeconds: holdSeconds ?? this.holdSeconds,
      calibratedFrames: calibratedFrames ?? this.calibratedFrames,
    );
  }

  static NeutralMetrics initial() => const NeutralMetrics(
    smileProbEwma: 0.0,
    deltaCorner: 1.0,
    deltaOpen: 1.0,
    holdSeconds: 0.0,
    calibratedFrames: 0,
  );
}

class NeutralState {
  final NeutralPhase phase;
  final NeutralBaseline? baseline;
  final NeutralMetrics metrics;

  const NeutralState({
    required this.phase,
    required this.baseline,
    required this.metrics,
  });

  NeutralState copyWith({
    NeutralPhase? phase,
    NeutralBaseline? baseline,
    NeutralMetrics? metrics,
  }) {
    return NeutralState(
      phase: phase ?? this.phase,
      baseline: baseline ?? this.baseline,
      metrics: metrics ?? this.metrics,
    );
  }

  static NeutralState initial() => NeutralState(
    phase: NeutralPhase.idle,
    baseline: null,
    metrics: NeutralMetrics.initial(),
  );
}

