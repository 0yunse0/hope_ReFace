import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';

import '../utils/constants.dart';
import '../utils/score_converter.dart';
import '../controllers/camera_controller.dart' as camera_ctrl;
import '../models/expression_type.dart';
import 'camera_preview_widget.dart';
import 'initial_expression_result_screen.dart';
import '../config/app_config.dart';

/// 초기 표정 측정 화면
/// - 스낵바 안내 + 타이머 시퀀스(측정 15초 / 휴식 10초)
/// - 순서: 무표정 → 웃는 → 화난 → 슬픈
class InitialExpressionScreen extends StatefulWidget {
  const InitialExpressionScreen({super.key});

  @override
  State<InitialExpressionScreen> createState() =>
      _InitialExpressionScreenState();
}

enum _Phase { idle, measure, rest, done }

class _InitialExpressionScreenState extends State<InitialExpressionScreen> {
  late camera_ctrl.AppCameraController _cameraController;
  Face? _lastFaceSnapshot; // 마지막으로 감지된 얼굴 스냅샷
  Worker? _faceWatcher; // Rx 구독 해제용
  bool _canUpload = false; // 마지막(슬픔) 종료 후 업로드 버튼 표시 여부
  bool _isUploading = false; // 업로드 진행 여부
  final Map<String, dynamic> _uploadData = {
    'expressionScores': <String, int>{},
  };

  // 표정별 점수 수집을 위한 변수들
  final Map<ExpressionType, List<double>> _expressionScores = {
    ExpressionType.neutral: [],
    ExpressionType.smile: [],
    ExpressionType.angry: [],
    ExpressionType.sad: [],
  };
  Timer? _scoreCollectionTimer; // 점수 수집용 타이머

  // 타이머/시퀀스 상태
  Timer? _timer;
  int _remainingSeconds = 0;
  _Phase _phase = _Phase.idle;
  int _stepIndex = -1; // -1: 시작 전, 0..3: 진행 중, 4: 완료
  final List<ExpressionType> _sequence = const [
    ExpressionType.neutral,
    ExpressionType.smile,
    ExpressionType.angry,
    ExpressionType.sad,
  ];

  @override
  void initState() {
    super.initState();
    _cameraController = Get.put(camera_ctrl.AppCameraController());
    _initializeCamera();
    // 얼굴 리스트 변경을 구독하여 마지막 얼굴 스냅샷 갱신
    _faceWatcher = ever<List<Face>>(_cameraController.detectedFaces, (faces) {
      if (faces.isNotEmpty) {
        _lastFaceSnapshot = faces.first;
      }
    });
  }

  Future<void> _initializeCamera() async {
    // 전면 카메라 우선 선택 (main.dart의 로직과 동일 목적)
    final List<CameraDescription> cameras = await availableCameras();
    CameraDescription camera = cameras.first;
    for (final c in cameras) {
      if (c.lensDirection == CameraLensDirection.front) {
        camera = c;
        break;
      }
    }
    await _cameraController.initializeCamera(camera);
    await _cameraController.startStream();
    setState(() {});
  }

  @override
  void dispose() {
    _stopTimer();
    _stopScoreCollection();
    _cameraController.stopStream();
    _faceWatcher?.dispose();
    super.dispose();
  }

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

  void _startSequence() {
    if (_phase != _Phase.idle && _phase != _Phase.done) return;
    // 카메라/스트림 준비 확인: 준비되지 않았으면 시작 지연
    if (!_cameraController.isInitialized.value ||
        _cameraController.controller == null ||
        !_cameraController.isStreaming.value) {
      _showInfo('카메라 준비 중입니다. 잠시 후 다시 시도해주세요.');
      return;
    }

    // 점수 수집 초기화
    _resetScoreCollection();

    _stepIndex = 0;
    _phase = _Phase.measure;
    _remainingSeconds = 15;
    _announceStep();
    _startTimer();
    _startScoreCollection();
  }

  void _announceStep() {
    final ExpressionType current = _sequence[_stepIndex];
    switch (current) {
      case ExpressionType.neutral:
        _showInfo('무표정 측정 시작 (15초)', bg: AppColors.accent);
        break;
      case ExpressionType.smile:
        _showInfo('웃는 표정 측정 시작 (15초)', bg: AppColors.primary);
        break;
      case ExpressionType.angry:
        _showInfo('화난 표정 측정 시작 (15초)', bg: AppColors.error);
        break;
      case ExpressionType.sad:
        _showInfo('슬픈 표정 측정 시작 (15초)', bg: AppColors.secondary);
        break;
    }
  }

  void _startTimer() {
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    setState(() {});
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  /// 점수 수집 초기화
  void _resetScoreCollection() {
    for (final expression in ExpressionType.values) {
      _expressionScores[expression]?.clear();
    }
  }

  /// 점수 수집 시작 (0.5초마다 현재 점수 수집)
  void _startScoreCollection() {
    _scoreCollectionTimer?.cancel();
    _scoreCollectionTimer = Timer.periodic(const Duration(milliseconds: 500), (
      _,
    ) {
      if (_phase == _Phase.measure &&
          _stepIndex >= 0 &&
          _stepIndex < _sequence.length) {
        _collectCurrentScore();
      }
    });
  }

  /// 점수 수집 중지
  void _stopScoreCollection() {
    _scoreCollectionTimer?.cancel();
    _scoreCollectionTimer = null;
  }

  /// 현재 표정의 점수 수집
  void _collectCurrentScore() {
    if (_stepIndex < 0 || _stepIndex >= _sequence.length) return;

    final ExpressionType currentExpression = _sequence[_stepIndex];
    double currentScore = 0.0;

    // 현재 표정에 맞는 점수 가져오기
    switch (currentExpression) {
      case ExpressionType.neutral:
        currentScore = _cameraController.neutralScore.value;
        break;
      case ExpressionType.smile:
        currentScore = _cameraController.smileScore.value;
        break;
      case ExpressionType.angry:
        currentScore = _cameraController.angryScore.value;
        break;
      case ExpressionType.sad:
        currentScore = _cameraController.sadScore.value;
        break;
    }

    // 점수 수집 (0.0~1.0 범위)
    _expressionScores[currentExpression]?.add(currentScore);
  }

  void _tick() {
    if (_remainingSeconds > 0) {
      setState(() => _remainingSeconds -= 1);
      return;
    }

    if (_phase == _Phase.measure) {
      // 측정 종료 시점 - 현재 표정 결과 로그 출력 (비동기, 필요 시 짧게 재시도)
      _logSelectedLandmarks(current: _sequence[_stepIndex]);
      final bool isLastStep = _stepIndex >= (_sequence.length - 1);
      if (isLastStep) {
        // 마지막 표정: 휴식 없이 완료 처리 후 업로드 버튼 표시
        _phase = _Phase.done;
        _stopTimer();
        _canUpload = true;
        _showInfo('초기 표정 측정이 완료되었습니다 🎉', bg: AppColors.success);
        setState(() {});
        return;
      }
      // 마지막이 아니면 휴식으로 전환
      _phase = _Phase.rest;
      _remainingSeconds = 10;
      _showInfo('휴식 (10초)', bg: AppColors.warning);
      setState(() {});
      return;
    }

    if (_phase == _Phase.rest) {
      // 다음 표정으로 진행
      if (_stepIndex + 1 < _sequence.length) {
        _stepIndex += 1;
        _phase = _Phase.measure;
        _remainingSeconds = 15;
        _announceStep();
        setState(() {});
      } else {
        // 완료
        _phase = _Phase.done;
        _stopTimer();
        _showInfo('초기 표정 측정이 완료되었습니다 🎉', bg: AppColors.success);
        // 완료 후 결과 화면으로 이동 (점수 데이터 없이 기본값 사용)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final emptyScores = <ExpressionType, double>{
            for (final expression in ExpressionType.values) expression: 0.0,
          };
          Get.off(
            () => InitialExpressionResultScreen(expressionScores: emptyScores),
          );
        });
        setState(() {});
      }
    }
  }

  /// 현재 카메라 프리뷰 좌표계로 변환해 선택된 랜드마크들을 로그로 출력
  /// - 출력 형식: LM FaceLandmarkType.noseBase: raw=(x, y) screen=(sx, sy)
  /// - current: 어느 표정의 15초 측정 종료 로그인지 전달
  Future<void> _logSelectedLandmarks({required ExpressionType current}) async {
    try {
      final controller = _cameraController.controller;
      if (controller == null || !controller.value.isInitialized) return;
      final Size? preview = controller.value.previewSize;
      if (preview == null) return;
      // 현재 프레임에 얼굴이 없으면 마지막 스냅샷 또는 짧은 재시도로 대체 시도
      Face? face = _cameraController.detectedFaces.isNotEmpty
          ? _cameraController.detectedFaces.first
          : _lastFaceSnapshot;
      if (face == null) {
        // 초기 단계에서 감지가 늦을 수 있어 1.5초간 5회(300ms 간격) 재시도
        for (int i = 0; i < 5 && face == null; i++) {
          await Future.delayed(const Duration(milliseconds: 300));
          if (_cameraController.detectedFaces.isNotEmpty) {
            face = _cameraController.detectedFaces.first;
            break;
          }
          if (_lastFaceSnapshot != null) {
            face = _lastFaceSnapshot;
          }
        }
        if (face == null) return;
      }

      // 프리뷰를 화면에 그릴 때의 스케일과 오프셋 계산 로직은 FaceLandmarksPainter와 동일하게 맞춤
      final double imageWidth = preview.height;
      final double imageHeight = preview.width;
      final Size screenSize = MediaQuery.of(context).size;
      final double scale =
          (screenSize.width / imageWidth) > (screenSize.height / imageHeight)
          ? (screenSize.width / imageWidth)
          : (screenSize.height / imageHeight);
      final double scaledWidth = imageWidth * scale;
      final double scaledHeight = imageHeight * scale;
      final double dx = (screenSize.width - scaledWidth) / 2.0;
      final double dy = (screenSize.height - scaledHeight) / 2.0;
      final CameraLensDirection dir = controller.description.lensDirection;

      double toScreenX(double rawX) {
        if (dir == CameraLensDirection.front) {
          return dx + (scaledWidth - rawX * scale);
        }
        return dx + rawX * scale;
      }

      double toScreenY(double rawY) => dy + rawY * scale;

      final List<FaceLandmarkType> targets = const [
        FaceLandmarkType.bottomMouth,
        FaceLandmarkType.rightMouth,
        FaceLandmarkType.leftMouth,
        FaceLandmarkType.leftEye,
        FaceLandmarkType.rightEye,
        FaceLandmarkType.rightCheek,
        FaceLandmarkType.leftCheek,
        FaceLandmarkType.noseBase,
      ];

      Offset? resolveLandmark(Face face, FaceLandmarkType type) {
        // 1) 우선 공식 landmark 사용
        final landmark = face.landmarks[type];
        if (landmark != null) {
          return Offset(
            landmark.position.x.toDouble(),
            landmark.position.y.toDouble(),
          );
        }
        // 2) contour 기반 보정
        switch (type) {
          case FaceLandmarkType.bottomMouth:
            final pts = face.contours[FaceContourType.lowerLipBottom]?.points;
            final fallback = face.contours[FaceContourType.lowerLipTop]?.points;
            final list = (pts != null && pts.isNotEmpty) ? pts : fallback;
            if (list != null && list.isNotEmpty) {
              return Offset(
                list[list.length ~/ 2].x.toDouble(),
                list[list.length ~/ 2].y.toDouble(),
              );
            }
            break;
          case FaceLandmarkType.rightMouth:
            final pts = face.contours[FaceContourType.upperLipTop]?.points;
            if (pts != null && pts.isNotEmpty) {
              // right mouth: 우측 끝점
              final p = pts.last;
              return Offset(p.x.toDouble(), p.y.toDouble());
            }
            break;
          case FaceLandmarkType.leftMouth:
            final pts = face.contours[FaceContourType.upperLipTop]?.points;
            if (pts != null && pts.isNotEmpty) {
              // left mouth: 좌측 끝점
              final p = pts.first;
              return Offset(p.x.toDouble(), p.y.toDouble());
            }
            break;
          case FaceLandmarkType.leftEye:
            final pts = face.contours[FaceContourType.leftEye]?.points;
            if (pts != null && pts.isNotEmpty) {
              final p = pts[pts.length ~/ 2];
              return Offset(p.x.toDouble(), p.y.toDouble());
            }
            break;
          case FaceLandmarkType.rightEye:
            final pts = face.contours[FaceContourType.rightEye]?.points;
            if (pts != null && pts.isNotEmpty) {
              final p = pts[pts.length ~/ 2];
              return Offset(p.x.toDouble(), p.y.toDouble());
            }
            break;
          case FaceLandmarkType.leftCheek:
            // 볼 좌/우는 contour가 없어 bbox 기반 근사치 사용
            final b = face.boundingBox;
            return Offset(b.left + b.width * 0.2, b.top + b.height * 0.55);
          case FaceLandmarkType.rightCheek:
            final b = face.boundingBox;
            return Offset(b.left + b.width * 0.8, b.top + b.height * 0.55);
          case FaceLandmarkType.noseBase:
            final pts = face.contours[FaceContourType.noseBottom]?.points;
            final bridge = face.contours[FaceContourType.noseBridge]?.points;
            if (pts != null && pts.isNotEmpty) {
              final p = pts[pts.length ~/ 2];
              return Offset(p.x.toDouble(), p.y.toDouble());
            }
            if (bridge != null && bridge.isNotEmpty) {
              final p = bridge.last;
              return Offset(p.x.toDouble(), p.y.toDouble());
            }
            break;
          default:
            break;
        }
        return null;
      }

      final StringBuffer buffer = StringBuffer();
      String label;
      switch (current) {
        case ExpressionType.neutral:
          label = '무표정';
          break;
        case ExpressionType.smile:
          label = '웃는 표정';
          break;
        case ExpressionType.angry:
          label = '화난 표정';
          break;
        case ExpressionType.sad:
          label = '슬픈 표정';
          break;
      }
      buffer.writeln('^^^[$label] 15초 측정 결과^^^');

      // 업로드용 표정 키 매핑 (더 이상 사용하지 않음)
      // key 변수는 제거됨 - 점수 데이터만 저장하도록 변경
      final Map<String, dynamic> pointsMap = <String, dynamic>{};
      for (final type in targets) {
        final pos = resolveLandmark(face, type);
        if (pos == null) continue;
        final double sx = toScreenX(pos.dx);
        final double sy = toScreenY(pos.dy);
        String typeKey;
        switch (type) {
          case FaceLandmarkType.bottomMouth:
            typeKey = 'bottomMouth';
            break;
          case FaceLandmarkType.rightMouth:
            typeKey = 'rightMouth';
            break;
          case FaceLandmarkType.leftMouth:
            typeKey = 'leftMouth';
            break;
          case FaceLandmarkType.leftEye:
            typeKey = 'leftEye';
            break;
          case FaceLandmarkType.rightEye:
            typeKey = 'rightEye';
            break;
          case FaceLandmarkType.rightCheek:
            typeKey = 'rightCheek';
            break;
          case FaceLandmarkType.leftCheek:
            typeKey = 'leftCheek';
            break;
          case FaceLandmarkType.noseBase:
            typeKey = 'noseBase';
            break;
          default:
            continue;
        }
        // 백엔드 전송 포맷: screen 좌표 미사용, raw 좌표만 {x, y}로 전송
        pointsMap[typeKey] = {'x': pos.dx, 'y': pos.dy};
        buffer.writeln(
          '^^^LM ${type.toString()}: raw=(${pos.dx.toStringAsFixed(1)}, ${pos.dy.toStringAsFixed(1)}) '
          'screen=(${sx.toStringAsFixed(1)}, ${sy.toStringAsFixed(1)})',
        );
      }

      // 표정별 포인트 데이터는 더 이상 _uploadData에 저장하지 않음
      // (점수 데이터만 저장하도록 변경됨)

      final String out = buffer.toString().trim();
      if (out.isNotEmpty) {
        // ignore: avoid_print
        print(out);
      }
    } catch (_) {
      // 로그 목적이므로 실패는 무시
    }
  }

  Future<void> _uploadInitialExpressions() async {
    if (_isUploading) return;
    setState(() => _isUploading = true);

    try {
      // final Uri uri = Uri.parse(
      //   '${AppConfig.apiBaseUrl}${AppConfig.firstfacePath()}',
      // );
      // final String body = jsonEncode(_uploadData);
      // final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      // final http.Response res = await http.post(
      //   uri,
      //   headers: {
      //     'accept': 'application/json',
      //     'Content-Type': 'application/json',
      //     'Authorization': 'Bearer $idToken',
      //   },
      //   body: body,
      // );
      final bool ok = true;
      // res.statusCode >= 200 && res.statusCode < 300;
      // 전송 유무 로그 출력
      // ignore: avoid_print
      //print('UPLOAD_${ok ? 'OK' : 'FAIL'} code=${res.statusCode}');
      if (ok) {
        // _showInfo('성공적으로 업로드가 되었습니다');

        // 수집된 점수들을 0~100 범위로 변환하여 평균 계산
        final Map<ExpressionType, double> averageScores = {};
        final expressionScores =
            _uploadData['expressionScores'] as Map<String, int>;

        for (final expression in ExpressionType.values) {
          final scores = _expressionScores[expression] ?? [];
          final averageScore = ScoreConverter.calculateAverageDisplayScore(
            scores,
          );
          averageScores[expression] = averageScore;

          // _uploadData에 점수 데이터 저장 (정수로 변환)
          expressionScores[expression.toString().split('.').last] = averageScore
              .round();
        }

        // 다음 화면 이동 (점수 데이터 전달)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Get.off(
            () =>
                InitialExpressionResultScreen(expressionScores: averageScores),
          );
        });
      }
    } catch (e) {
      // ignore: avoid_print
      print('UPLOAD_FAIL error=$e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  String _formatTime(int seconds) {
    final int m = seconds ~/ 60;
    final int s = seconds % 60;
    final String mm = m.toString().padLeft(2, '0');
    final String ss = s.toString().padLeft(2, '0');
    return '$mm:$ss';
  }

  ExpressionType? _currentExpression() {
    if (_phase == _Phase.measure &&
        _stepIndex >= 0 &&
        _stepIndex < _sequence.length) {
      return _sequence[_stepIndex];
    }
    return null; // 휴식/대기 시엔 점수 색상만 유지
  }

  double _currentScore() {
    switch (_currentExpression()) {
      case ExpressionType.smile:
        return _cameraController.smileScore.value;
      case ExpressionType.sad:
        return _cameraController.sadScore.value;
      case ExpressionType.angry:
        return _cameraController.angryScore.value;
      case ExpressionType.neutral:
        return _cameraController.neutralScore.value;
      default:
        return 0.0;
    }
  }

  String? _sessionLabel() {
    switch (_phase) {
      case _Phase.measure:
        return '측정';
      case _Phase.rest:
        return '휴식';
      case _Phase.idle:
      case _Phase.done:
        return '대기';
    }
  }

  String? _leftTopLabel() {
    final ExpressionType? current = _currentExpression();
    if (current == null) return null;
    switch (current) {
      case ExpressionType.neutral:
        return '무표정';
      case ExpressionType.smile:
        return '웃는 표정';
      case ExpressionType.angry:
        return '화난 표정';
      case ExpressionType.sad:
        return '슬픈 표정';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('초기 표정 측정'), centerTitle: true),
      body: SafeArea(
        child: Column(
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
                    if (_cameraController.isInitialized.value &&
                        _cameraController.controller != null) {
                      final String? big =
                          (_remainingSeconds > 0 && _remainingSeconds <= 5)
                          ? _remainingSeconds.toString()
                          : null;
                      return CameraPreviewWidget(
                        controller: _cameraController.controller!,
                        isFaceDetected: _cameraController.isFaceDetected.value,
                        detectedFaces: _cameraController.detectedFaces,
                        score: _currentScore(),
                        neutralStateProvider: () =>
                            _cameraController.neutralState.value,
                        debugNeutral:
                            _cameraController.neutralDebugEnabled.value,
                        setsCount: null,
                        leftTopLabel: _leftTopLabel(),
                        colorLandmarksByScore: false,
                        timerText:
                            (_phase == _Phase.measure || _phase == _Phase.rest)
                            ? _formatTime(_remainingSeconds)
                            : null,
                        sessionLabel: _sessionLabel(),
                        bigCountdownText: big,
                      );
                    } else {
                      return const Center(child: CircularProgressIndicator());
                    }
                  }),
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.all(AppSizes.md),
                padding: const EdgeInsets.all(AppSizes.lg),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '스낵바 안내에 따라 표정을 유지해 주세요',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSizes.md),
                    if (_canUpload)
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                          ),
                          onPressed: _isUploading
                              ? null
                              : _uploadInitialExpressions,
                          child: Text(
                            _isUploading ? '업로드 중...' : '초기 표정 기록 보러가기',
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                          ),
                          onPressed:
                              (_phase == _Phase.idle || _phase == _Phase.done)
                              ? _startSequence
                              : null,
                          child: Text(
                            (_phase == _Phase.idle || _phase == _Phase.done)
                                ? '측정 시작'
                                : '진행 중...',
                          ),
                        ),
                      ),
                    const SizedBox(height: AppSizes.sm),
                    TextButton(
                      onPressed: () => Get.offAllNamed('/home'),
                      child: const Text('건너뛰고 홈으로 이동'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
