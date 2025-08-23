import 'dart:async';
import 'dart:ui';
import 'dart:io';
import 'package:get/get.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:permission_handler/permission_handler.dart';

class AppCameraController extends GetxController {
  CameraController? _controller;
  CameraDescription? _camera;
  final FaceDetector _faceDetector = FaceDetector(
    options: FaceDetectorOptions(
      performanceMode: FaceDetectorMode.accurate,
      enableLandmarks: true,
      enableContours: true,
      enableClassification: true,
      enableTracking: true,
      minFaceSize: 0.15,
    ),
  );

  final RxBool isInitialized = false.obs;
  final RxBool isStreaming = false.obs;
  final RxBool hasPermission = false.obs;
  final RxBool isFaceDetected = false.obs;
  final RxDouble smileScore = 0.0.obs;
  final RxDouble sadScore = 0.0.obs;
  final RxString activeExpression = 'smile'.obs; // 'smile' | 'sad'
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
      // 권한 재확인
      await _checkPermission();

      if (!hasPermission.value) {
        errorMessage.value = '카메라 권한이 필요합니다';
        return;
      }

      _camera = camera;
      _controller = CameraController(
        camera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );

      await _controller!.initialize();
      isInitialized.value = true;
      errorMessage.value = '';
      print('카메라 초기화 성공: ${camera.name}');
    } catch (e) {
      errorMessage.value = '카메라 초기화에 실패했습니다: $e';
      isInitialized.value = false;
      print('카메라 초기화 실패: $e');
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
      } catch (e) {
        errorMessage.value = '스트림 중지에 실패했습니다: $e';
      }
    }
  }

  Future<void> _processImage(CameraImage image) async {
    try {
      final InputImage? inputImage = _inputImageFromCameraImage(image);
      if (inputImage == null) {
        print('이미지 변환 실패');
        return;
      }

      final faces = await _faceDetector.processImage(inputImage);
      print('감지된 얼굴 수: ${faces.length}');

      if (faces.isNotEmpty) {
        isFaceDetected.value = true;
        detectedFaces.value = faces;
        _updateExpressionScores(faces.first);
        print('얼굴 감지됨 - 미소 점수: ${smileScore.value}, 슬픔 점수: ${sadScore.value}');
      } else {
        isFaceDetected.value = false;
        detectedFaces.clear();
        smileScore.value = 0.0;
        sadScore.value = 0.0;
        print('얼굴 미감지');
      }
    } catch (e) {
      print('이미지 처리 오류: $e');
      errorMessage.value = '이미지 처리 중 오류가 발생했습니다: $e';
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
      var rotationCompensation = 0; // 기본값
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
    if (face.smilingProbability != null) {
      smileScore.value = face.smilingProbability!;
    } else {
      // 얼굴 랜드마크를 기반으로 미소 점수 계산
      final landmarks = face.landmarks;
      if (landmarks.isNotEmpty) {
        // 간단한 미소 점수 계산 (실제로는 더 복잡한 알고리즘 필요)
        smileScore.value = 0.5; // 기본값
      } else {
        smileScore.value = 0.0;
      }
    }
  }

  void _calculateSadScore(Face face) {
    // 입 좌표 기반 슬픈 표정 점수 계산: 입꼬리(y)가 기준점 대비 얼마나 내려갔는지
    double? leftY;
    double? rightY;
    double? bottomY;
    double? noseY;

    final leftLm = face.landmarks[FaceLandmarkType.leftMouth]?.position;
    final rightLm = face.landmarks[FaceLandmarkType.rightMouth]?.position;
    final bottomLm = face.landmarks[FaceLandmarkType.bottomMouth]?.position;
    final noseLm = face.landmarks[FaceLandmarkType.noseBase]?.position;

    if (leftLm != null) leftY = (leftLm.y as num).toDouble();
    if (rightLm != null) rightY = (rightLm.y as num).toDouble();
    if (bottomLm != null) bottomY = (bottomLm.y as num).toDouble();
    if (noseLm != null) noseY = (noseLm.y as num).toDouble();

    // 랜드마크가 부족하면 컨투어에서 대체
    if (leftY == null || rightY == null) {
      final upperLipTop = face.contours[FaceContourType.upperLipTop]?.points;
      final lowerLipTop = face.contours[FaceContourType.lowerLipTop]?.points;
      final lip = (upperLipTop != null && upperLipTop.isNotEmpty)
          ? upperLipTop
          : ((lowerLipTop != null && lowerLipTop.isNotEmpty)
                ? lowerLipTop
                : null);
      if (lip != null && lip.isNotEmpty) {
        leftY ??= (lip.first.y as num).toDouble();
        rightY ??= (lip.last.y as num).toDouble();
      }
    }

    if (leftY == null || rightY == null) {
      sadScore.value = 0.0;
      return;
    }

    // 기준점 선택
    final avgCornerY = (leftY + rightY) / 2.0;

    double baselineY;
    double normDenominator;

    if (noseY != null && bottomY != null) {
      baselineY = noseY;
      normDenominator = (bottomY - noseY).abs();
    } else if (noseY != null) {
      baselineY = noseY;
      normDenominator = (face.boundingBox.height * 0.25).abs();
    } else if (bottomY != null) {
      baselineY = bottomY - (face.boundingBox.height * 0.10);
      normDenominator = (face.boundingBox.height * 0.25).abs();
    } else {
      baselineY = face.boundingBox.top + face.boundingBox.height * 0.55;
      normDenominator = (face.boundingBox.height * 0.25).abs();
    }

    if (normDenominator < 1.0) {
      normDenominator = 1.0;
    }

    // y는 아래로 갈수록 커짐. 코너가 기준선보다 아래로 내려가면 양수 → 슬픈 표정
    final rawDelta = (avgCornerY - baselineY);
    final normalized = (rawDelta / normDenominator).clamp(0.0, 1.0);
    sadScore.value = normalized;
    // 디버그 출력
    // ignore: avoid_print
    print(
      'sadScore rawDelta=${rawDelta.toStringAsFixed(2)} norm=${normDenominator.toStringAsFixed(2)} score=${sadScore.value.toStringAsFixed(2)}',
    );
  }

  void _updateExpressionScores(Face face) {
    _calculateSmileScore(face);
    _calculateSadScore(face);
  }

  void setActiveExpression(String expression) {
    activeExpression.value = expression; // 'smile' or 'sad'
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
