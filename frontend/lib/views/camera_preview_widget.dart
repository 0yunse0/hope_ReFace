import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../utils/constants.dart';
import '../models/neutral_state.dart';
import '../painters/face_overlay.dart';

class CameraPreviewWidget extends StatelessWidget {
  final CameraController controller;
  final bool isFaceDetected;
  final dynamic detectedFaces;
  final NeutralState Function()? neutralStateProvider;
  final bool debugNeutral;

  // ## 병합: 점수 파라미터 (버전 1) ##
  final double score;

  // ## 병합: 타이머 및 세션 정보 파라미터 (버전 2) ##
  final int? setsCount;
  final String? timerText;
  final String? sessionLabel; // '훈련', '휴식', '중지'
  final String? bigCountdownText; // 마지막 5초 카운트 표시용
  final String? leftTopLabel; // 좌상단 커스텀 라벨 (예: 표정명)
  final bool colorLandmarksByScore; // 점 색상을 점수 기반으로 칠할지 여부
  final bool showLandmarks; // 랜드마크 표시 토글
  final int? remainingSeconds; // 남은 초 (프로그레스 바용)
  final int? totalSeconds; // 전체 초 (프로그레스 바용)
  final int? totalSets; // 전체 세트 수 (세트 라벨에 함께 표시)

  const CameraPreviewWidget({
    super.key,
    required this.controller,
    required this.isFaceDetected,
    this.detectedFaces,
    this.neutralStateProvider,
    this.debugNeutral = false,
    this.score = 0.0,
    this.setsCount,
    this.timerText,
    this.sessionLabel,
    this.bigCountdownText,
    this.leftTopLabel,
    this.colorLandmarksByScore = true,
    this.showLandmarks = true,
    this.remainingSeconds,
    this.totalSeconds,
    this.totalSets,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // ## 수정: FittedBox를 사용하여 화면을 꽉 채우도록 변경 ##
        if (controller.value.isInitialized)
          SizedBox.expand(
            // Stack의 모든 공간을 차지하도록 함
            child: ClipRect(
              // FittedBox가 확대시킨 위젯의 바깥 부분을 잘라냄
              child: FittedBox(
                fit: BoxFit.cover, // 자식의 비율을 유지하면서 부모에 꽉 채움 (가장 중요!)
                child: SizedBox(
                  // 카메라 영상의 원본 비율대로 크기를 지정
                  width: controller.value.previewSize!.height,
                  height: controller.value.previewSize!.width,
                  child: CameraPreview(controller),
                ),
              ),
            ),
          ),

        // 얼굴 특징점 오버레이
        if (showLandmarks &&
            isFaceDetected &&
            detectedFaces != null &&
            detectedFaces!.isNotEmpty)
          CustomPaint(
            painter: FaceLandmarksPainter(
              facesProvider: () {
                try {
                  if (detectedFaces is List<Face>) {
                    return detectedFaces as List<Face>;
                  }
                  if (detectedFaces is Iterable) {
                    return List<Face>.from(detectedFaces as Iterable);
                  }
                } catch (_) {}
                return const <Face>[];
              },
              imageSize: controller.value.previewSize ?? const Size(0, 0),
              cameraLensDirection: controller.description.lensDirection,
              score: score, // ## 병합: 점수 전달 (버전 1) ##
              logLandmarks: debugNeutral,
              colorByScore: colorLandmarksByScore,
              repaint: controller,
            ),
            child: const SizedBox.expand(),
          ),

        // 무표정 가이드/디버그 오버레이
        if (isFaceDetected &&
            detectedFaces != null &&
            detectedFaces!.isNotEmpty)
          CustomPaint(
            painter: FaceOverlayPainter(
              facesProvider: () {
                try {
                  if (detectedFaces is List<Face>) {
                    return detectedFaces as List<Face>;
                  }
                  if (detectedFaces is Iterable) {
                    return List<Face>.from(detectedFaces as Iterable);
                  }
                } catch (_) {}
                return const <Face>[];
              },
              imageSize: controller.value.previewSize ?? const Size(0, 0),
              cameraLensDirection: controller.description.lensDirection,
              neutralStateProvider: neutralStateProvider,
              debugEnabled: debugNeutral,
              repaint: controller,
            ),
            child: const SizedBox.expand(),
          ),

        // ## 병합: 좌상단 라벨 (세트 수 또는 표정명) ##
        if (leftTopLabel != null || setsCount != null)
          Positioned(
            top: timerText != null ? (AppSizes.md + 40) : AppSizes.md,
            left: AppSizes.md,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.sm,
                vertical: AppSizes.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.95),
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(
                leftTopLabel ??
                    '세트 $setsCount${totalSets != null ? '/$totalSets' : ''}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),

        // ## 병합: 우상단 타이머 표시 (버전 2) ##
        if (timerText != null)
          Positioned(
            top: AppSizes.md,
            left: AppSizes.md,
            right: AppSizes.md,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.sm,
                vertical: AppSizes.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface.withOpacity(0.95),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Text(
                    timerText!,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: AppSizes.md),
                  Expanded(
                    child: _TimerBar(
                      remaining: remainingSeconds,
                      total: totalSeconds,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ## 병합: 상단 중앙 세션 상태 라벨 (버전 2) ##
        if (sessionLabel != null)
          Positioned(
            top: timerText != null ? (AppSizes.md + 42) : AppSizes.md,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.sm,
                  vertical: AppSizes.xs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surface.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  sessionLabel!,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),

        // ## 병합: 중앙 큰 카운트다운 (버전 2) ##
        if (bigCountdownText != null && bigCountdownText!.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                alignment: Alignment.center,
                color: Colors.black.withOpacity(0.15),
                child: Text(
                  bigCountdownText!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 96,
                    fontWeight: FontWeight.w800,
                    shadows: [
                      Shadow(
                        blurRadius: 8,
                        color: Colors.black54,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // 얼굴 감지 오버레이
        if (!isFaceDetected)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.face_retouching_off,
                    size: 64,
                    color: AppColors.error,
                  ),
                  SizedBox(height: AppSizes.md),
                  Text(
                    '얼굴이 감지되지 않았어요',
                    style: TextStyle(
                      color: AppColors.surface,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

        // 얼굴 감지 표시 (타이머가 있을 때 위치 조정)
        if (isFaceDetected)
          Positioned(
            top: timerText != null ? (AppSizes.md + 40) : AppSizes.md,
            right: AppSizes.md,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSizes.sm,
                vertical: AppSizes.xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.9),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.face, color: AppColors.surface, size: 16),
                  SizedBox(width: AppSizes.xs),
                  Text(
                    AppStrings.faceDetected,
                    style: TextStyle(
                      color: AppColors.surface,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _TimerBar extends StatelessWidget {
  final int? remaining;
  final int? total;
  const _TimerBar({this.remaining, this.total});

  @override
  Widget build(BuildContext context) {
    final int t = (total ?? 0) <= 0 ? (remaining ?? 0) : (total ?? 0);
    final int r = (remaining ?? 0).clamp(0, t);
    final double ratio = t > 0 ? (r / t) : 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final double full = constraints.maxWidth;
        final double targetWidth = full * (1 - ratio).clamp(0.0, 1.0);
        return Stack(
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                width: targetWidth,
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class FaceLandmarksPainter extends CustomPainter {
  final List<Face> Function() facesProvider;
  final Size imageSize;
  final CameraLensDirection cameraLensDirection;
  final double score;
  final bool logLandmarks;
  final bool colorByScore;

  FaceLandmarksPainter({
    required this.facesProvider,
    required this.imageSize,
    required this.cameraLensDirection,
    required this.score,
    this.logLandmarks = false,
    this.colorByScore = true,
    Listenable? repaint,
  }) : super(repaint: repaint);

  Color _getLandmarkColor(double score) {
    if (score >= AppConstants.highScoreThreshold) {
      return Colors.greenAccent;
    } else if (score >= AppConstants.mediumScoreThreshold) {
      return Colors.yellowAccent;
    } else {
      return Colors.redAccent;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final faces = facesProvider();
    if (faces.isEmpty || imageSize.width == 0 || imageSize.height == 0) return;

    final double imageWidth = imageSize.height;
    final double imageHeight = imageSize.width;
    final double scale = (size.width / imageWidth) > (size.height / imageHeight)
        ? (size.width / imageWidth)
        : (size.height / imageHeight);
    final double scaledWidth = imageWidth * scale;
    final double scaledHeight = imageHeight * scale;
    final double dx = (size.width - scaledWidth) / 2.0;
    final double dy = (size.height - scaledHeight) / 2.0;

    final landmarkPaint = Paint()
      ..color = colorByScore ? _getLandmarkColor(score) : Colors.cyanAccent
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final contourPaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..style = PaintingStyle.fill;

    // 간헐적 로그 출력을 위한 페인트 카운터
    // 너무 많은 로그를 방지하기 위해 10프레임마다 출력
    // (상태 공유를 피하기 위해 static 변수 사용)
    // ignore: prefer_const_declarations
    final int logEveryNFrames = 10;
    // Using a static to persist across instances/frames
    // ignore: prefer_final_fields
    // Dart에서는 static 지역 변수를 지원하지 않아 클래스 수준의 정적 필드 없이
    // 간단히 카운트 증가 후 모듈 전역에 저장하는 대신, 이번 프레임에서만 조건 체크하도록 간소화
    bool shouldLogThisFrame = false;

    // 프레임당 한 번만 로그하도록 간단한 난수 기반 샘플링 대체
    // 미세한 차이는 있으나 평균적으로 10프레임에 한 번 수준으로 제한됨
    if (logLandmarks) {
      final int millis = DateTime.now().millisecond; // 0..999
      shouldLogThisFrame = (millis % (logEveryNFrames)) == 0;
    }

    for (final face in faces) {
      final Rect raw = face.boundingBox;
      double left = dx + raw.left * scale;
      double top = dy + raw.top * scale;
      double width = raw.width * scale;
      double height = raw.height * scale;
      if (cameraLensDirection == CameraLensDirection.front) {
        left = dx + (scaledWidth - (raw.left + raw.width) * scale);
      }
      final Rect screenRect = Rect.fromLTWH(left, top, width, height);
      canvas.drawRect(screenRect, borderPaint);

      for (final contour in face.contours.values) {
        if (contour == null) continue;
        for (final point in contour.points) {
          double sx = dx + point.x * scale;
          double sy = dy + point.y * scale;
          if (cameraLensDirection == CameraLensDirection.front) {
            sx = dx + (scaledWidth - point.x * scale);
          }
          if (sx < 0 || sy < 0 || sx > size.width || sy > size.height) continue;
          canvas.drawCircle(Offset(sx, sy), 2.0, contourPaint);
        }
      }

      final StringBuffer? debugBuffer = shouldLogThisFrame
          ? StringBuffer()
          : null;

      for (final entry in face.landmarks.entries) {
        final landmark = entry.value;
        if (landmark == null) continue;
        double sx = dx + landmark.position.x * scale;
        double sy = dy + landmark.position.y * scale;
        if (cameraLensDirection == CameraLensDirection.front) {
          sx = dx + (scaledWidth - landmark.position.x * scale);
        }
        if (sx < 0 || sy < 0 || sx > size.width || sy > size.height) continue;
        canvas.drawCircle(Offset(sx, sy), 4.0, landmarkPaint);

        // 디버그 로그 수집: 선택된 랜드마크만 출력
        if (debugBuffer != null) {
          final type = entry.key;
          switch (type) {
            case FaceLandmarkType.bottomMouth:
            case FaceLandmarkType.rightMouth:
            case FaceLandmarkType.leftMouth:
            case FaceLandmarkType.rightEye:
            case FaceLandmarkType.leftEye:
            case FaceLandmarkType.rightEar:
            case FaceLandmarkType.leftEar:
            case FaceLandmarkType.rightCheek:
            case FaceLandmarkType.leftCheek:
            case FaceLandmarkType.noseBase:
              debugBuffer.writeln(
                'LM ${type.toString()}: raw=(${landmark.position.x.toStringAsFixed(1)}, ${landmark.position.y.toStringAsFixed(1)}) '
                'screen=(${sx.toStringAsFixed(1)}, ${sy.toStringAsFixed(1)})',
              );
              break;
          }
        }
      }

      if (debugBuffer != null) {
        // 한 프레임 처리 후 모아서 출력
        final String lines = debugBuffer.toString().trim();
        if (lines.isNotEmpty) {
          // 무조건 여러 줄로 출력되도록 개행 유지
          // ignore: avoid_print
          print(lines);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant FaceLandmarksPainter oldDelegate) {
    return false;
  }
}
