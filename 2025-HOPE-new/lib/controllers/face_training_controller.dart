import 'dart:async';

import 'package:get/get.dart';
import 'package:camera/camera.dart';

import '../models/smile_score_model.dart';
import '../models/training_session_model.dart';
import '../services/camera_service.dart';
import '../services/face_detection_service.dart';
import '../utils/constants.dart';
import '../utils/score_calculator.dart';

/// 얼굴 훈련 메인 컨트롤러
/// GetX를 사용한 반응형 상태 관리 및 훈련 세션 제어
class FaceTrainingController extends GetxController {
  // 서비스 의존성
  final CameraService _cameraService = CameraService();
  final FaceDetectionService _faceDetectionService = FaceDetectionService();

  // 반응형 상태 변수들
  final RxDouble _currentScore = 0.0.obs;
  final RxBool _isTrainingActive = false.obs;
  final RxBool _isFaceDetected = false.obs;
  final RxString _feedbackMessage = ''.obs;
  final RxString _trainingTopic = '웃는 표정 학습'.obs;
  final RxBool _isCameraInitialized = false.obs;
  final RxBool _isProcessing = false.obs;

  // 훈련 세션 관련
  TrainingSessionModel? _currentSession;
  final RxList<SmileScoreModel> _scoreHistory = <SmileScoreModel>[].obs;
  final RxInt _sessionDuration = 0.obs;
  final RxDouble _maxScore = 0.0.obs;
  final RxDouble _averageScore = 0.0.obs;

  // 스트림 구독
  StreamSubscription<SmileScoreModel>? _scoreStreamSubscription;
  Timer? _sessionTimer;

  // Getter 메서드들
  double get currentScore => _currentScore.value;
  bool get isTrainingActive => _isTrainingActive.value;
  bool get isFaceDetected => _isFaceDetected.value;
  String get feedbackMessage => _feedbackMessage.value;
  String get trainingTopic => _trainingTopic.value;
  bool get isCameraInitialized => _isCameraInitialized.value;
  bool get isProcessing => _isProcessing.value;
  List<SmileScoreModel> get scoreHistory => _scoreHistory;
  int get sessionDuration => _sessionDuration.value;
  double get maxScore => _maxScore.value;
  double get averageScore => _averageScore.value;

  // Observable getter들
  RxDouble get currentScoreRx => _currentScore;
  RxBool get isTrainingActiveRx => _isTrainingActive;
  RxBool get isFaceDetectedRx => _isFaceDetected;
  RxString get feedbackMessageRx => _feedbackMessage;
  RxString get trainingTopicRx => _trainingTopic;
  RxBool get isCameraInitializedRx => _isCameraInitialized;
  RxBool get isProcessingRx => _isProcessing;
  RxList<SmileScoreModel> get scoreHistoryRx => _scoreHistory;
  RxInt get sessionDurationRx => _sessionDuration;
  RxDouble get maxScoreRx => _maxScore;
  RxDouble get averageScoreRx => _averageScore;

  @override
  void onInit() {
    super.onInit();
    _initializeServices();
  }

  @override
  void onClose() {
    _disposeResources();
    super.onClose();
  }

  /// 서비스 초기화
  Future<void> _initializeServices() async {
    try {
      // 카메라 서비스 초기화
      final cameraInitialized = await _cameraService.initialize();
      _isCameraInitialized.value = cameraInitialized;

      if (cameraInitialized) {
        // 얼굴 감지 서비스 초기화
        await _faceDetectionService.initialize();
      }
    } catch (e) {
      _feedbackMessage.value = '카메라 초기화에 실패했습니다.';
    }
  }

  /// 훈련 시작
  Future<void> startTraining() async {
    if (!_isCameraInitialized.value) {
      _feedbackMessage.value = '카메라가 초기화되지 않았습니다.';
      return;
    }

    try {
      _isProcessing.value = true;

      // 새 훈련 세션 생성
      _currentSession = TrainingSessionModel(
        sessionId: DateTime.now().millisecondsSinceEpoch.toString(),
        startTime: DateTime.now(),
        endTime: null,
        trainingTopic: _trainingTopic.value,
        scoreHistory: [],
        maxScore: 0.0,
        averageScore: 0.0,
        status: TrainingSessionStatus.active,
      );

      // 카메라 스트림 시작
      await _cameraService.startImageStream();

      // 얼굴 감지 스트림 시작
      await _startFaceDetectionStream();

      // 세션 타이머 시작
      _startSessionTimer();

      _isTrainingActive.value = true;
      _feedbackMessage.value = '훈련이 시작되었습니다.';
      _isProcessing.value = false;
    } catch (e) {
      _isProcessing.value = false;
      _feedbackMessage.value = '훈련 시작에 실패했습니다.';
    }
  }

  /// 훈련 일시정지
  void pauseTraining() {
    if (!_isTrainingActive.value) return;

    _isTrainingActive.value = false;
    _sessionTimer?.cancel();
    _scoreStreamSubscription?.pause();
    _feedbackMessage.value = '훈련이 일시정지되었습니다.';

    if (_currentSession != null) {
      _currentSession = _currentSession!.copyWith(
        status: TrainingSessionStatus.paused,
      );
    }
  }

  /// 훈련 재개
  void resumeTraining() {
    if (_isTrainingActive.value) return;

    _isTrainingActive.value = true;
    _startSessionTimer();
    _scoreStreamSubscription?.resume();
    _feedbackMessage.value = '훈련이 재개되었습니다.';

    if (_currentSession != null) {
      _currentSession = _currentSession!.copyWith(
        status: TrainingSessionStatus.active,
      );
    }
  }

  /// 훈련 종료
  Future<void> stopTraining() async {
    if (!_isTrainingActive.value && _currentSession == null) return;

    try {
      _isProcessing.value = true;

      // 스트림 및 타이머 정리
      await _stopFaceDetectionStream();
      _sessionTimer?.cancel();
      _cameraService.stopImageStream();

      // 세션 완료 처리
      if (_currentSession != null) {
        _currentSession = _currentSession!.copyWith(
          endTime: DateTime.now(),
          status: TrainingSessionStatus.completed,
          maxScore: _maxScore.value,
          averageScore: _averageScore.value,
          scoreHistory: List.from(_scoreHistory),
        );
      }

      _isTrainingActive.value = false;
      _feedbackMessage.value =
          AppConstants.feedbackMessages['trainingCompleted']!;
      _isProcessing.value = false;
    } catch (e) {
      _isProcessing.value = false;
      _feedbackMessage.value =
          AppConstants.errorMessages['trainingStopFailed']!;
    }
  }

  /// 훈련 주제 변경
  void changeTrainingTopic(String topic) {
    if (_isTrainingActive.value) {
      _feedbackMessage.value =
          AppConstants.errorMessages['cannotChangeTopicDuringTraining']!;
      return;
    }

    if (TrainingTopics.allTopics.contains(topic)) {
      _trainingTopic.value = topic;
      _feedbackMessage.value = '훈련 주제가 "$topic"로 변경되었습니다.';
    }
  }

  /// 얼굴 감지 스트림 시작
  Future<void> _startFaceDetectionStream() async {
    // 시뮬레이션을 위해 빈 스트림 생성
    final emptyStream = Stream<CameraImage>.empty();
    _scoreStreamSubscription = _faceDetectionService
        .startRealTimeDetection(emptyStream)
        .listen(
          (smileScore) {
            _updateScore(smileScore);
          },
          onError: (error) {
            _feedbackMessage.value =
                AppConstants.errorMessages['faceDetectionFailed']!;
          },
        );
  }

  /// 얼굴 감지 스트림 중지
  Future<void> _stopFaceDetectionStream() async {
    await _scoreStreamSubscription?.cancel();
    _faceDetectionService.stopRealTimeDetection();
  }

  /// 점수 업데이트
  void _updateScore(SmileScoreModel smileScore) {
    if (!_isTrainingActive.value) return;

    _currentScore.value = smileScore.score;
    _isFaceDetected.value = smileScore.isFaceDetected;

    // 점수 히스토리에 추가
    _scoreHistory.add(smileScore);

    // 통계 업데이트
    _updateStatistics();

    // 피드백 메시지 생성
    _generateFeedbackMessage(smileScore);
  }

  /// 통계 업데이트
  void _updateStatistics() {
    if (_scoreHistory.isEmpty) return;

    final scores = _scoreHistory.map((score) => score.score).toList();
    _maxScore.value = scores.reduce((a, b) => a > b ? a : b);
    _averageScore.value = scores.reduce((a, b) => a + b) / scores.length;
  }

  /// 피드백 메시지 생성
  void _generateFeedbackMessage(SmileScoreModel smileScore) {
    if (!smileScore.isFaceDetected) {
      _feedbackMessage.value =
          AppConstants.feedbackMessages['faceNotDetected']!;
      return;
    }

    final scoreLevel = ScoreCalculator.getScoreLevel(smileScore.score);
    final feedback = ScoreCalculator.getFeedbackMessage(smileScore.score);

    _feedbackMessage.value = feedback;
  }

  /// 세션 타이머 시작
  void _startSessionTimer() {
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_isTrainingActive.value) {
        _sessionDuration.value++;
      } else {
        timer.cancel();
      }
    });
  }

  /// 리소스 정리
  void _disposeResources() {
    _scoreStreamSubscription?.cancel();
    _sessionTimer?.cancel();
    _cameraService.dispose();
    _faceDetectionService.dispose();
  }

  /// 현재 세션 정보 반환
  TrainingSessionModel? getCurrentSession() => _currentSession;

  /// 세션 리셋
  void resetSession() {
    _currentScore.value = 0.0;
    _isFaceDetected.value = false;
    _feedbackMessage.value = '';
    _scoreHistory.clear();
    _sessionDuration.value = 0;
    _maxScore.value = 0.0;
    _averageScore.value = 0.0;
    _currentSession = null;
  }

  /// 카메라 전환
  Future<void> switchCamera() async {
    if (_isTrainingActive.value) {
      _feedbackMessage.value =
          AppConstants.errorMessages['cannotSwitchCameraDuringTraining']!;
      return;
    }

    try {
      await _cameraService.switchCamera();
      _feedbackMessage.value = AppConstants.feedbackMessages['cameraSwitched']!;
    } catch (e) {
      _feedbackMessage.value =
          AppConstants.errorMessages['cameraSwitchFailed']!;
    }
  }
}
