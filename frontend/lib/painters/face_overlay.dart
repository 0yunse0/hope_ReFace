import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

import '../models/neutral_state.dart';

class FaceOverlayPainter extends CustomPainter {
  final List<Face> Function() facesProvider;
  final Size imageSize;
  final CameraLensDirection cameraLensDirection;
  final NeutralState Function()? neutralStateProvider;
  final bool debugEnabled;

  FaceOverlayPainter({
    required this.facesProvider,
    required this.imageSize,
    required this.cameraLensDirection,
    this.neutralStateProvider,
    this.debugEnabled = false,
    Listenable? repaint,
  }) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final faces = facesProvider();
    if (faces.isEmpty || imageSize.width == 0 || imageSize.height == 0) return;
    // 힌트/디버그 표시 제거됨
  }

  @override
  bool shouldRepaint(covariant FaceOverlayPainter oldDelegate) {
    return oldDelegate.debugEnabled != debugEnabled ||
        oldDelegate.imageSize != imageSize ||
        oldDelegate.cameraLensDirection != cameraLensDirection;
  }
}
