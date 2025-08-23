import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../utils/constants.dart';

class CameraPreviewWidget extends StatelessWidget {
  final CameraController controller;
  final bool isFaceDetected;
  final dynamic detectedFaces; // RxList<Face> 또는 List<Face>를 받을 수 있도록

  const CameraPreviewWidget({
    super.key,
    required this.controller,
    required this.isFaceDetected,
    this.detectedFaces,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // 카메라 프리뷰
        CameraPreview(controller),

        // 얼굴 특징점 오버레이 (단일 CustomPaint로 모든 얼굴 처리 + 카메라 프레임에 맞춰 repaint)
        if (isFaceDetected &&
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
              repaint: controller,
            ),
            child: const SizedBox.expand(),
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

        // 얼굴 감지 표시
        if (isFaceDetected)
          Positioned(
            top: AppSizes.md,
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

class FaceLandmarksPainter extends CustomPainter {
  final List<Face> Function() facesProvider;
  final Size imageSize;
  final CameraLensDirection cameraLensDirection;

  FaceLandmarksPainter({
    required this.facesProvider,
    required this.imageSize,
    required this.cameraLensDirection,
    Listenable? repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final faces = facesProvider();
    if (faces.isEmpty || imageSize.width == 0 || imageSize.height == 0) return;

    // CameraPreview는 기본적으로 BoxFit.cover로 표시됨.
    // portrait 환경에 맞춰 previewSize의 축을 스왑하고, cover 스케일과 크롭 오프셋(dx, dy)을 계산한다.
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
      ..color = Colors.lightGreenAccent
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    for (final face in faces) {
      // 바운딩 박스 변환 및 그리기 (cover 스케일과 크롭 오프셋 적용)
      final Rect raw = face.boundingBox;
      double left = dx + raw.left * scale;
      double top = dy + raw.top * scale;
      double width = raw.width * scale;
      double height = raw.height * scale;
      if (cameraLensDirection == CameraLensDirection.front) {
        // 이미지 표시 영역(dx..dx+scaledWidth) 기준으로 좌우 반전
        left = dx + (scaledWidth - (raw.left + raw.width) * scale);
      }
      final Rect screenRect = Rect.fromLTWH(left, top, width, height);
      canvas.drawRect(screenRect, borderPaint);
      // ignore: avoid_print
      print(
        'FaceBox screen: l=${screenRect.left.toStringAsFixed(1)}, t=${screenRect.top.toStringAsFixed(1)}, w=${screenRect.width.toStringAsFixed(1)}, h=${screenRect.height.toStringAsFixed(1)}',
      );

      // 랜드마크 그리기 + 디버그 로그 출력 (부위별 x, y)
      for (final entry in face.landmarks.entries) {
        final landmark = entry.value;
        if (landmark == null) continue;
        double sx = dx + landmark.position.x * scale;
        double sy = dy + landmark.position.y * scale;
        if (cameraLensDirection == CameraLensDirection.front) {
          // 이미지 표시 영역 기준 좌우 반전
          sx = dx + (scaledWidth - landmark.position.x * scale);
        }
        if (sx < 0 || sy < 0 || sx > size.width || sy > size.height) continue;
        canvas.drawCircle(Offset(sx, sy), 4.0, landmarkPaint);

        // 디버그 좌표 출력 (원본 좌표)
        final String name = entry.key.toString();
        // 주의: paint는 매 프레임 호출되므로 출력량이 많을 수 있음
        // 요구사항에 따라 부위별 원본 좌표를 출력
        // ignore: avoid_print
        print(
          'LM ${name}: raw=(${landmark.position.x.toStringAsFixed(1)}, ${landmark.position.y.toStringAsFixed(1)}) screen=(${sx.toStringAsFixed(1)}, ${sy.toStringAsFixed(1)})',
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant FaceLandmarksPainter oldDelegate) {
    // repaint Listenable(controller)로 프레임마다 자동 갱신되므로 여기서는 false
    return false;
  }
}
