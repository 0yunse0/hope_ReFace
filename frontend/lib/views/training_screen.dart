import 'package:flutter/material.dart';
import 'dart:async';
import 'package:get/get.dart';
import 'package:camera/camera.dart';

import '../controllers/camera_controller.dart' as camera_ctrl;
import '../utils/constants.dart';
import '../models/expression_type.dart';
import 'camera_preview_widget.dart';
import 'score_display_widget.dart';
import 'feedback_widget.dart';
import 'training_result_screen.dart';

// API
import '../services/training_api_service.dart';

enum _SessionPhase { idle, training, rest, done }

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
  Timer? _timer;
  int _remainingSeconds = 0;
  int _currentSet = 1;
  final int _totalSets = 3;
  _SessionPhase _phase = _SessionPhase.idle;
  bool _navigatedToResult = false;
  bool _showLandmarks = true;

  // --- API 연동 ---
  final _api = TrainingApiService();
  String? _sid;

  final List<double> _setScores = [];

  void _showInfo(String text, {Color bg = const Color(0xFF323232)}) {
    Get.snackbar(
      text,
      '',
      snackPosition: SnackPosition.TOP,
      backgroundColor: bg.withOpacity(0.95),
      colorText: Colors.white,
      margin: const EdgeInsets.all(12),
      borderRadius: 12,
      duration: const Duration(seconds: 2),
      isDismissible: true,
      forwardAnimationCurve: Curves.easeOutCubic,
      reverseAnimationCurve: Curves.easeInCubic,
    );
  }

  @override
  void initState() {
    super.initState();
    _cameraController = Get.put(camera_ctrl.AppCameraController());
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    await _cameraController.initializeCamera(widget.camera);
    if (_cameraController.isInitialized.value) {
      await _cameraController.startStream();
    }
  }

  // 현재 점수
  double _currentScore() {
    switch (widget.expressionType) {
      case ExpressionType.smile:
        return _cameraController.smileScore.value;
      case ExpressionType.sad:
        return _cameraController.sadScore.value;
      case ExpressionType.angry:
        return _cameraController.angryScore.value;
      case ExpressionType.neutral:
        return _cameraController.neutralScore.value;
    }
  }

  Future<void> _ensureServerSession() async {
    if (_sid != null) return;
    try {
      _sid = await _api.startSession(widget.expressionType.name);
    } catch (e) {
      _showInfo('세션 시작 실패: $e', bg: AppColors.error);
    }
  }

  void _toggleTraining() async {
    setState(() {
      _isTraining = !_isTraining;
    });
    if (_isTraining) {
      await _ensureServerSession();

      _cameraController.setSessionActive(true);
      _cameraController.setSessionRest(false);
      if (_phase == _SessionPhase.idle || _phase == _SessionPhase.done) {
        _currentSet = 1;
        _phase = _SessionPhase.training;
        _remainingSeconds = 15;
        _setScores.clear();
      }
      _navigatedToResult = false;
      _showInfo(
        '훈련 시작 - $_currentSet세트/$_totalSets세트 (15초)',
        bg: AppColors.accent,
      );
      _startTimer();
    } else {
      _cameraController.setSessionActive(false);
      _cameraController.setSessionRest(false);
      _stopTimer();
      _showInfo('훈련 중지', bg: AppColors.error);
      if (_sid != null) {
        try {
          await _api.closeSession(sid: _sid!, summary: 'stopped');
        } catch (_) {}
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      setState(() {
        if (_remainingSeconds > 0) _remainingSeconds -= 1;
        if (_remainingSeconds <= 0) _advancePhase();
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _advancePhase() async {
    if (_phase == _SessionPhase.training) {
      _setScores.add(_currentScore());

      if (_currentSet < _totalSets) {
        _phase = _SessionPhase.rest;
        _remainingSeconds = 10;
        _cameraController.setSessionRest(true);
        _showInfo('휴식 (10초)', bg: AppColors.warning);
      } else {
        _phase = _SessionPhase.done;
        _isTraining = false;
        _stopTimer();
        _cameraController.setSessionActive(false);
        _cameraController.setSessionRest(false);

        // ✅ 변경: 3세트 점수의 평균을 계산합니다.
        final double finalScore = _setScores.isEmpty
            ? 0.0
            : _setScores.reduce((a, b) => a + b) / _setScores.length;

        // ✅ 변경: 세션 마감 시 '평균 점수'를 서버로 전송합니다.
        if (_sid != null) {
          try {
            await _api.closeSession(
              sid: _sid!,
              summary: 'completed',
              finalScore: finalScore, // 최종 평균 점수 전송
            );
          } catch (e) {
            _showInfo('세션 마감 실패: $e', bg: AppColors.error);
          }
        }

        _showInfo('훈련 완료! 수고하셨어요 👍', bg: AppColors.success);
        if (mounted && !_navigatedToResult) {
          _navigatedToResult = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Get.off(
              () => TrainingResultScreen(
                expressionType: widget.expressionType,
                finalScore: finalScore, // 결과 화면에도 평균 점수 전달
              ),
            );
          });
        }
      }
    } else if (_phase == _SessionPhase.rest) {
      _currentSet += 1;
      _phase = _SessionPhase.training;
      _remainingSeconds = 15;
      _cameraController.setSessionRest(false);
      // ⛔️ 제거: _framePoints.clear();
      _showInfo(
        '훈련 재개 - $_currentSet세트/$_totalSets세트 (15초)',
        bg: AppColors.accent,
      );
    }
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _getTitle() {
    switch (widget.expressionType) {
      case ExpressionType.smile:
        return '웃는 표정 훈련';
      case ExpressionType.sad:
        return '슬픈 표정 훈련';
      case ExpressionType.angry:
        return '화난 표정 훈련';
      case ExpressionType.neutral:
        return '무표정 유지 훈련';
    }
  }

  @override
  Widget build(BuildContext context) {
    // 이 부분의 UI 코드는 변경할 필요가 없습니다.
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          _getTitle(),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Container(
              margin: const EdgeInsets.only(
                left: AppSizes.md,
                right: AppSizes.md,
                top: AppSizes.md,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Obx(() {
                  if (_cameraController.isInitialized.value) {
                    final score = _currentScore();

                    String? label;
                    switch (_phase) {
                      case _SessionPhase.training:
                        label = '훈련';
                        break;
                      case _SessionPhase.rest:
                        label = '휴식';
                        break;
                      case _SessionPhase.idle:
                      case _SessionPhase.done:
                        label = '중지';
                        break;
                    }
                    String? big =
                        (_remainingSeconds > 0 && _remainingSeconds <= 5)
                        ? _remainingSeconds.toString()
                        : null;

                    return Stack(
                      children: [
                        CameraPreviewWidget(
                          controller: _cameraController.controller!,
                          isFaceDetected:
                              _cameraController.isFaceDetected.value,
                          detectedFaces: _cameraController.detectedFaces,
                          showLandmarks: _showLandmarks,
                          remainingSeconds: _remainingSeconds,
                          totalSeconds: _phase == _SessionPhase.training
                              ? 15
                              : (_phase == _SessionPhase.rest ? 10 : null),
                          totalSets: _totalSets,
                          score: score,
                          neutralStateProvider:
                              widget.expressionType == ExpressionType.neutral
                              ? (() => _cameraController.neutralState.value)
                              : null,
                          debugNeutral:
                              widget.expressionType == ExpressionType.neutral
                              ? _cameraController.neutralDebugEnabled.value
                              : false,
                          setsCount: _currentSet,
                          timerText: _formatTime(_remainingSeconds),
                          sessionLabel: label,
                          bigCountdownText: big,
                        ),
                        Positioned(
                          right: AppSizes.md,
                          bottom: AppSizes.md,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSizes.sm,
                              vertical: AppSizes.xs,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text(
                                  '랜드마크',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color.fromARGB(255, 219, 231, 255),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Switch(
                                  value: _showLandmarks,
                                  onChanged: (v) =>
                                      setState(() => _showLandmarks = v),
                                  materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }
                  return const Center(child: CircularProgressIndicator());
                }),
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              margin: const EdgeInsets.all(AppSizes.md),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Obx(() {
                      final score = _currentScore();
                      return ScoreDisplayWidget(
                        score: score,
                        isTraining: _isTraining,
                        expressionType: widget.expressionType,
                      );
                    }),
                    const SizedBox(height: AppSizes.sm),
                    Obx(() {
                      final score = _currentScore();
                      return FeedbackWidget(
                        isFaceDetected: _cameraController.isFaceDetected.value,
                        score: score,
                        isTraining: _isTraining,
                        expressionType: widget.expressionType,
                      );
                    }),
                    const SizedBox(height: AppSizes.md),
                    const SizedBox(height: AppSizes.sm),
                    ElevatedButton(
                      onPressed: _toggleTraining,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 15,
                        ),
                        textStyle: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      child: Text(_isTraining ? '훈련 중지' : '훈련 시작'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _stopTimer();
    _cameraController.stopStream();
    super.dispose();
  }
}
