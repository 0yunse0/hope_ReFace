import 'dart:async';
import 'dart:ui';
import 'dart:io';
import 'dart:math';

import 'package:get/get.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:permission_handler/permission_handler.dart';

class AppCameraController extends GetxController {
  CameraController? _controller;
  CameraDescription? _camera;

  // ## 1. 성능 개선: fast 모드로 변경 ##
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.fast,
      enableLandmarks: true,
      enableContours: true,
      enableClassification: true,
      enableTracking: true,
      minFaceSize: 0.15,
    ),
  );

  bool _isBusy = false; // 이미지 처리 중복 방지 플래그

  final RxBool isInitialized = false.obs;
  final RxBool isStreaming = false.obs;
  final RxBool hasPermission = false.obs;
  final RxBool isFaceDetected = false.obs;
  final RxDouble smileScore = 0.0.obs;
  final RxDouble sadScore = 0.0.obs;
  final RxDouble angryScore = 0.0.obs;
  final RxString activeExpression = 'smile'.obs;
  final RxString errorMessage = ''.obs;
  final RxList<Face> detectedFaces = <Face>[].obs;

  CameraController? get controller => _controller;
  FaceDetector get faceDetector => _faceDetector;

  @override
  void onInit() {
    super.onInit();
    _checkPermission();
  }

  @override
  void onClose() {
    _disposeController();
    _faceDetector.close();
    super.onClose();
  }

  Future<void> _checkPermission() async {
    final status = await Permission.camera.status;
    hasPermission.value = status.isGranted;

    if (!hasPermission.value) {
      final result = await Permission.camera.request();
      hasPermission.value = result.isGranted;
    }
  }

  Future<void> initializeCamera(CameraDescription camera) async {
    try {
      await _checkPermission();

      if (!hasPermission.value) {
        errorMessage.value = '카메라 권한이 필요합니다';
        return;
      }

      _camera = camera;
      _controller = CameraController(
        camera,
        // ## 1. 성능 개선: low 해상도로 변경 ##
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await _controller!.initialize();
      isInitialized.value = true;
      errorMessage.value = '';
    } catch (e) {
      errorMessage.value = '카메라 초기화에 실패했습니다: $e';
      isInitialized.value = false;
    }
  }

  Future<void> startStream() async {
    if (!isInitialized.value || _controller == null) {
      errorMessage.value = '카메라가 초기화되지 않았습니다';
      return;
    }

    try {
      await _controller!.startImageStream(_processImage);
      isStreaming.value = true;
      errorMessage.value = '';
    } catch (e) {
      errorMessage.value = '스트림 시작에 실패했습니다: $e';
      isStreaming.value = false;
    }
  }

  Future<void> stopStream() async {
    if (_controller != null && isStreaming.value) {
      try {
        await _controller!.stopImageStream();
        isStreaming.value = false;
        isFaceDetected.value = false;
        detectedFaces.clear();
        smileScore.value = 0.0;
        sadScore.value = 0.0;
        angryScore.value = 0.0;
      } catch (e) {
        errorMessage.value = '스트림 중지에 실패했습니다: $e';
      }
    }
  }

  Future<void> _processImage(CameraImage image) async {
    // ## 1. 성능 개선: 스로틀링 ##
    if (_isBusy) return;
    _isBusy = true;

    try {
      final InputImage? inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) {
        _isBusy = false;
        return;
      }

      final faces = await _faceDetector.processImage(inputImage);

      if (faces.isNotEmpty) {
        isFaceDetected.value = true;
        detectedFaces.value = faces;
        _updateExpressionScores(faces.first);
      } else {
        isFaceDetected.value = false;
        detectedFaces.clear();
        smileScore.value = 0.0;
        sadScore.value = 0.0;
        angryScore.value = 0.0;
      }
    } catch (e) {
      errorMessage.value = '이미지 처리 중 오류가 발생했습니다: $e';
    } finally {
      _isBusy = false;
    }
  }

  InputImage? _inputImageFromCameraImage(CameraImage image) {
    if (_camera == null) return null;
    final camera = _camera!;
    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;

    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else if (Platform.isAndroid) {
      var rotationCompensation = 0;
      if (camera.lensDirection == CameraLensDirection.front) {
        rotationCompensation = (sensorOrientation + rotationCompensation) % 360;
      } else {
        rotationCompensation =
            (sensorOrientation - rotationCompensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(rotationCompensation);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  void _calculateSmileScore(Face face) {
    final targetScore = face.smilingProbability?.clamp(0.0, 1.0) ?? 0.0;
    // 점수 스무딩
    smileScore.value = lerpDouble(smileScore.value, targetScore, 0.2)!;
  }

  void _calculateSadScore(Face face) {
    final leftMouth = face.landmarks[FaceLandmarkType.leftMouth]?.position;
    final rightMouth = face.landmarks[FaceLandmarkType.rightMouth]?.position;
    final noseBase = face.landmarks[FaceLandmarkType.noseBase]?.position;

    if (leftMouth == null || rightMouth == null || noseBase == null) {
      sadScore.value = lerpDouble(sadScore.value, 0.0, 0.2)!;
      return;
    }

    double mouthCornerY = (leftMouth.y + rightMouth.y) / 2.0;
    double noseY = noseBase.y.toDouble();
    double faceHeight = face.boundingBox.height;

    if (faceHeight < 1.0) {
      sadScore.value = lerpDouble(sadScore.value, 0.0, 0.2)!;
      return;
    }

    double sadValue = (mouthCornerY - noseY) / (faceHeight * 0.2);
    final targetScore = sadValue.clamp(0.0, 1.0);
    // 점수 스무딩
    sadScore.value = lerpDouble(sadScore.value, targetScore, 0.2)!;
  }

  void _calculateAngryScore(Face face) {
    final double? leftEyeOpen = face.leftEyeOpenProbability;
    final double? rightEyeOpen = face.rightEyeOpenProbability;
    final double? smilingProb = face.smilingProbability;

    if (leftEyeOpen == null || rightEyeOpen == null || smilingProb == null) {
      angryScore.value = lerpDouble(angryScore.value, 0.0, 0.2)!;
      return;
    }

    final avgEyeOpenProb = (leftEyeOpen + rightEyeOpen) / 2.0;
    final eyeScore = 1.0 - avgEyeOpenProb;
    final mouthScore = 1.0 - smilingProb;

    final finalScore = (eyeScore * 0.8 + mouthScore * 0.2);

    double targetScore = finalScore;

    // ## 3. 데드존 설정: 점수가 0.15 이하면 0으로 처리 ##
    if (targetScore < 0.15) {
      targetScore = 0.0;
    }

    // 증폭 및 범위 제한
    targetScore = (targetScore * 2.0).clamp(0.0, 1.0);

    // ## 2. 점수 스무딩: 현재 점수에서 목표 점수까지 20%씩 이동 ##
    angryScore.value = lerpDouble(angryScore.value, targetScore, 0.2)!;
  }

  void _updateExpressionScores(Face face) {
    _calculateSmileScore(face);
    _calculateSadScore(face);
    _calculateAngryScore(face);
  }

  void setActiveExpression(String expression) {
    activeExpression.value = expression;
  }

  void _disposeController() {
    _controller?.dispose();
    _controller = null;
    isInitialized.value = false;
    isStreaming.value = false;
  }

  void clearError() {
    errorMessage.value = '';
  }
}