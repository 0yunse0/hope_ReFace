import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../config/neutral_config.dart';
import '../models/neutral_state.dart';
import 'face_features.dart';

typedef NeutralSuccessCallback = void Function(NeutralState state);

class NeutralDetector {
  NeutralState _state = NeutralState.initial();

  // EWMA 상태
  double _smileEwma = 0.0;
  double _cornerEwma = 0.0;
  double _openEwma = 0.0;

  // 캘리브레이션 누적
  double _sumCorner = 0.0;
  double _sumOpen = 0.0;
  int _calibCount = 0;

  // 시간 추적
  DateTime? _lastFeedAt;

  NeutralSuccessCallback? onNeutralSuccess;

  NeutralState get state => _state;
  NeutralMetrics get metrics => _state.metrics;

  void resetCalibration() {
    _smileEwma = 0.0;
    _cornerEwma = 0.0;
    _openEwma = 0.0;
    _sumCorner = 0.0;
    _sumOpen = 0.0;
    _calibCount = 0;
    _lastFeedAt = null;
    _state = NeutralState(
      phase: NeutralPhase.calibrating,
      baseline: null,
      metrics: NeutralMetrics.initial(),
    );
  }

  /// 프레임 입력 처리
  void feed(Face face) {
    final DateTime now = DateTime.now();
    final double dt = _computeDeltaSeconds(now);

    // idle이면 자동으로 캘리브레이션 시작
    if (_state.phase == NeutralPhase.idle) {
      resetCalibration();
    }

    final double normRef = FaceFeatures.computeNormalizationRef(face);
    final double corner = FaceFeatures.computeMouthCornerDistance(
      face,
      normRef,
    );
    final double open = FaceFeatures.computeMouthOpenness(face, normRef);

    final double smileProb = face.smilingProbability ?? 0.0;
    _smileEwma = FaceFeatures.ewma(
      _smileEwma,
      smileProb,
      NeutralConfig.emaAlpha,
    );
    _cornerEwma = FaceFeatures.ewma(
      _cornerEwma,
      corner,
      NeutralConfig.emaAlpha,
    );
    _openEwma = FaceFeatures.ewma(_openEwma, open, NeutralConfig.emaAlpha);

    if (_state.phase == NeutralPhase.calibrating) {
      _sumCorner += corner;
      _sumOpen += open;
      _calibCount += 1;

      final updatedMetrics = _state.metrics.copyWith(
        smileProbEwma: _smileEwma,
        calibratedFrames: _calibCount,
      );
      _state = _state.copyWith(metrics: updatedMetrics);

      if (_calibCount >= NeutralConfig.calibrationFrames) {
        final baseline = NeutralBaseline(
          corner: _sumCorner / _calibCount,
          open: _sumOpen / _calibCount,
        );
        _state = _state.copyWith(
          phase: NeutralPhase.tracking,
          baseline: baseline,
          metrics: updatedMetrics.copyWith(holdSeconds: 0.0),
        );
      }
      return;
    }

    if (_state.phase == NeutralPhase.tracking) {
      final baseline = _state.baseline!;
      final double dCorner = FaceFeatures.deltaNormalized(
        _cornerEwma,
        baseline.corner,
      );
      final double dOpen = FaceFeatures.deltaNormalized(
        _openEwma,
        baseline.open,
      );

      final bool withinNeutral =
          _smileEwma < NeutralConfig.neutralSmileMax &&
          dCorner < NeutralConfig.maxMouthCornerDelta &&
          dOpen < NeutralConfig.maxMouthOpenDelta;

      final bool exitNeutral =
          _smileEwma > NeutralConfig.neutralSmileMaxExit ||
          dCorner > NeutralConfig.maxMouthCornerDelta ||
          dOpen > NeutralConfig.maxMouthOpenDelta;

      final double nextHold = withinNeutral
          ? (_state.metrics.holdSeconds + dt)
          : 0.0;

      final updated = _state.metrics.copyWith(
        smileProbEwma: _smileEwma,
        deltaCorner: dCorner,
        deltaOpen: dOpen,
        holdSeconds: nextHold,
      );
      _state = _state.copyWith(metrics: updated);

      if (nextHold >= NeutralConfig.neutralHoldSeconds) {
        _state = _state.copyWith(phase: NeutralPhase.success);
        if (onNeutralSuccess != null) {
          onNeutralSuccess!(_state);
        }
        return;
      }

      if (exitNeutral) {
        // 이탈 시 idle로 복귀 (요구사항)
        _state = _state.copyWith(
          phase: NeutralPhase.idle,
          metrics: updated.copyWith(holdSeconds: 0.0),
        );
        return;
      }
    }
  }

  double _computeDeltaSeconds(DateTime now) {
    if (_lastFeedAt == null) {
      _lastFeedAt = now;
      return 0.0;
    }
    final dt = now.difference(_lastFeedAt!).inMilliseconds / 1000.0;
    _lastFeedAt = now;
    // 프레임 드랍 등으로 비정상 큰 값 방지
    if (dt.isNaN || dt.isInfinite || dt < 0) return 0.0;
    return dt.clamp(0.0, 0.33); // 3~60fps 범위 가정
  }
}
