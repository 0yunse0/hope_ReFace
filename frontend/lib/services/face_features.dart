import 'dart:math';
import 'dart:ui' show Rect; // for Face.boundingBox
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// 얼굴 특징(입꼬리/입벌림 등) 공통 계산 유틸
/// - 모든 거리값은 얼굴 크기 기반 정규화
/// - 스마일/무표정에서 공통 사용
class FaceFeatures {
  FaceFeatures._();

  /// 정규화 기준 길이 계산
  /// bbox 대각선 길이를 사용하여 스케일 불변을 보장한다.
  static double computeNormalizationRef(Face face) {
    final Rect b = face.boundingBox;
    final double w = b.width.abs();
    final double h = b.height.abs();
    final double diag = sqrt(w * w + h * h);
    return max(1.0, diag);
  }

  /// 입꼬리 좌/우 간 거리(정규화)
  static double computeMouthCornerDistance(Face face, double normRef) {
    final left = face.landmarks[FaceLandmarkType.leftMouth]?.position;
    final right = face.landmarks[FaceLandmarkType.rightMouth]?.position;

    if (left != null && right != null) {
      final dx = (left.x - right.x).toDouble();
      final dy = (left.y - right.y).toDouble();
      final dist = sqrt(dx * dx + dy * dy);
      return (dist / normRef).clamp(0.0, 1.0);
    }

    // 컨투어 보정
    final lipTop = face.contours[FaceContourType.upperLipTop]?.points;
    if (lipTop != null && lipTop.isNotEmpty) {
      final first = lipTop.first;
      final last = lipTop.last;
      final dx = (first.x - last.x).toDouble();
      final dy = (first.y - last.y).toDouble();
      final dist = sqrt(dx * dx + dy * dy);
      return (dist / normRef).clamp(0.0, 1.0);
    }

    return 0.0; // 정보 부족
  }

  /// 입벌림(상/하 입술 간) 거리(정규화)
  /// 컨투어 기반 측정: upperLipBottom vs lowerLipTop의 중앙점 거리
  static double computeMouthOpenness(Face face, double normRef) {
    final topContour = face.contours[FaceContourType.upperLipBottom]?.points;
    final bottomContour = face.contours[FaceContourType.lowerLipTop]?.points;

    if (topContour != null &&
        bottomContour != null &&
        topContour.isNotEmpty &&
        bottomContour.isNotEmpty) {
      final t = topContour[topContour.length ~/ 2];
      final b = bottomContour[bottomContour.length ~/ 2];
      final dy = (b.y - t.y).toDouble();
      return (dy.abs() / normRef).clamp(0.0, 1.0);
    }

    return 0.0;
  }

  /// |current-baseline| / max(epsilon, max(|baseline|, |current|))
  static double deltaNormalized(
    double current,
    double baseline, {
    double epsilon = 1e-4,
  }) {
    final double denom = max(epsilon, max(baseline.abs(), current.abs()));
    return ((current - baseline).abs() / denom).clamp(0.0, 1.0);
  }

  /// EWMA
  static double ewma(double prev, double x, double alpha) {
    return alpha * x + (1.0 - alpha) * prev;
  }
}
