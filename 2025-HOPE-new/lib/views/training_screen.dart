import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:camera/camera.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../controllers/camera_controller.dart' as camera_ctrl;
import '../utils/constants.dart';
import '../models/expression_type.dart';
import 'camera_preview_widget.dart';
import 'score_display_widget.dart';
import 'feedback_widget.dart';

class TrainingScreen extends StatefulWidget {
  final CameraDescription camera;
  final ExpressionType expressionType;

  const TrainingScreen({
    super.key,
    required this.camera,
    this.expressionType = ExpressionType.smile,
  });

  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  late camera_ctrl.AppCameraController _cameraController;
  bool _isTraining = false;

  @override
  void initState() {
    super.initState();
    _cameraController = Get.put(camera_ctrl.AppCameraController());
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      print('카메라 초기화 시작: ${widget.camera.name}');
      await _cameraController.initializeCamera(widget.camera);

      // 초기화 후 스트림 시작
      if (_cameraController.isInitialized.value) {
        await _cameraController.startStream();
        print('카메라 스트림 시작됨');
      }
    } catch (e) {
      print('카메라 초기화 오류: $e');
    }
  }

  void _toggleTraining() {
    if (_isTraining) {
      _stopTraining();
    } else {
      _startTraining();
    }
  }

  Future<void> _startTraining() async {
    if (!_cameraController.isStreaming.value) {
      await _cameraController.startStream();
    }
    if (!mounted) return;
    setState(() {
      _isTraining = true;
    });
  }

  Future<void> _stopTraining() async {
    if (_cameraController.isStreaming.value) {
      await _cameraController.stopStream();
    }
    if (!mounted) return;
    setState(() {
      _isTraining = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isSad = widget.expressionType == ExpressionType.sad;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          isSad ? '슬픈 표정 진척도' : '스마트 표정 훈련기',
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 카메라 프리뷰 영역
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.all(AppSizes.md),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.textTertiary.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Obx(() {
                  if (_cameraController.isInitialized.value) {
                    return CameraPreviewWidget(
                      controller: _cameraController.controller!,
                      isFaceDetected: _cameraController.isFaceDetected.value,
                      detectedFaces: _cameraController.detectedFaces,
                    );
                  } else {
                    return Container(
                      color: AppColors.surface,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(
                              color: AppColors.primary,
                            ),
                            const SizedBox(height: AppSizes.md),
                            Text(
                              _cameraController.errorMessage.value.isNotEmpty
                                  ? _cameraController.errorMessage.value
                                  : '카메라를 초기화하는 중...',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            if (_cameraController.errorMessage.value.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: AppSizes.md,
                                ),
                                child: ElevatedButton(
                                  onPressed: () => _initializeCamera(),
                                  child: const Text('다시 시도'),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  }
                }),
              ),
            ),
          ),

          // 점수 및 피드백 영역
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: AppSizes.md),
              child: Column(
                children: [
                  // 점수 표시
                  Obx(() {
                    final score = isSad
                        ? _cameraController.sadScore.value
                        : _cameraController.smileScore.value;
                    return ScoreDisplayWidget(
                      score: score,
                      isTraining: _isTraining,
                    );
                  }),

                  const SizedBox(height: AppSizes.md),

                  // 피드백 메시지
                  Obx(
                    () => FeedbackWidget(
                      isFaceDetected: _cameraController.isFaceDetected.value,
                      smileScore: _cameraController.smileScore.value,
                      isTraining: _isTraining,
                    ),
                  ),

                  const SizedBox(height: AppSizes.lg),

                  // 훈련 시작/중지 버튼
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _cameraController.isInitialized.value
                          ? _toggleTraining
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isTraining
                            ? AppColors.error
                            : AppColors.primary,
                        foregroundColor: AppColors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        elevation: 2,
                      ),
                      child: Text(
                        _isTraining ? '훈련 중지' : '훈련 시작',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ).animate().fadeIn(duration: AppAnimations.normal),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // dispose 단계에서는 상태 변경을 하지 않고 스트림만 안전하게 중지
    if (_cameraController.isStreaming.value) {
      _cameraController.stopStream();
    }
    super.dispose();
  }
}
