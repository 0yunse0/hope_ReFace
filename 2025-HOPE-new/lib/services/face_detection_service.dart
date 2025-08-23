import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

import '../models/smile_score_model.dart';
import '../utils/score_calculator.dart';
import '../utils/constants.dart';

/// 얼굴 감지 서비스 클래스 (시뮬레이션)
/// 실제 MLKit 대신 시뮬레이션을 통해 얼굴 감지 및 웃음 점수 계산
class FaceDetectionService {
  static final FaceDetectionService _instance =
      FaceDetectionService._internal();
  factory FaceDetectionService() => _instance;
  FaceDetectionService._internal();

  // 상태 변수들
  bool _isInitialized = false;
  bool _isProcessing = false;

  // 스트림 관련 변수들
  StreamSubscription<SmileScoreModel>? _scoreStreamSubscription;
  final StreamController<SmileScoreModel> _scoreStreamController =
      StreamController<SmileScoreModel>.broadcast();

  // 성능 최적화를 위한 변수들
  DateTime _lastProcessingTime = DateTime.now();
  static const Duration _minProcessingInterval = Duration(
    milliseconds: 100,
  ); // 최소 처리 간격

  // 시뮬레이션을 위한 변수들
  final Random _random = Random();
  double _lastScore = 0.0;

  // Getters
  bool get isInitialized => _isInitialized;
  bool get isProcessing => _isProcessing;
  Stream<SmileScoreModel> get scoreStream => _scoreStreamController.stream;

  /// 얼굴 감지 서비스 초기화
  ///
  /// Returns: 초기화 성공 여부
  Future<bool> initialize() async {
    try {
      // 시뮬레이션 초기화 (실제로는 MLKit 초기화)
      await Future.delayed(Duration(milliseconds: 100)); // 초기화 시간 시뮬레이션

      _isInitialized = true;
      return true;
    } catch (e) {
      _isInitialized = false;
      throw Exception('얼굴 감지 초기화 실패: $e');
    }
  }

  /// 카메라 이미지에서 얼굴 감지 및 웃음 점수 계산 (시뮬레이션)
  ///
  /// [image] 카메라 이미지
  /// Returns: 웃음 점수 모델
  Future<SmileScoreModel> detectFaceAndCalculateScore(CameraImage image) async {
    if (!_isInitialized) {
      throw Exception('얼굴 감지 서비스가 초기화되지 않았습니다.');
    }

    // 성능 최적화: 처리 간격 제한
    final now = DateTime.now();
    if (now.difference(_lastProcessingTime) < _minProcessingInterval) {
      // 이전 결과 반환
      return SmileScoreModel(
        score: _lastScore,
        timestamp: now,
        isFaceDetected: true,
        confidence: 0.8,
      );
    }
    _lastProcessingTime = now;

    _isProcessing = true;

    try {
      // 시뮬레이션: 80% 확률로 얼굴 감지
      final isFaceDetected = _random.nextDouble() > 0.2;

      if (!isFaceDetected) {
        // 얼굴이 감지되지 않은 경우
        return SmileScoreModel(
          score: 0.0,
          timestamp: now,
          isFaceDetected: false,
          confidence: 0.0,
        );
      }

      // 시뮬레이션: 웃음 점수 계산 (점진적 변화)
      final scoreChange = (_random.nextDouble() - 0.5) * 0.1; // -0.05 ~ 0.05
      _lastScore = (_lastScore + scoreChange).clamp(0.0, 1.0);

      // 결과 생성
      final result = SmileScoreModel(
        score: _lastScore,
        timestamp: now,
        isFaceDetected: true,
        confidence: 0.8 + _random.nextDouble() * 0.2, // 0.8 ~ 1.0
      );

      // 스트림으로 결과 전송
      if (!_scoreStreamController.isClosed) {
        _scoreStreamController.add(result);
      }

      return result;
    } catch (e) {
      // 오류 발생 시 기본값 반환
      return SmileScoreModel(
        score: 0.0,
        timestamp: now,
        isFaceDetected: false,
        confidence: 0.0,
      );
    } finally {
      _isProcessing = false;
    }
  }

  /// 시뮬레이션: 얼굴 특징점 추출
  List<Map<String, double>> _extractMouthCorners() {
    return [
      {'x': 100.0, 'y': 200.0},
      {'x': 150.0, 'y': 200.0},
    ];
  }

  /// 시뮬레이션: 눈꼬리 좌표 추출
  List<Map<String, double>> _extractEyeCorners() {
    return [
      {'x': 80.0, 'y': 120.0},
      {'x': 120.0, 'y': 120.0},
      {'x': 180.0, 'y': 120.0},
      {'x': 220.0, 'y': 120.0},
    ];
  }

  /// 시뮬레이션: 코 끝 좌표 추출
  Map<String, double> _extractNoseTip() {
    return {'x': 150.0, 'y': 150.0};
  }

  /// 실시간 스트림 처리 시작
  ///
  /// [imageStream] 카메라 이미지 스트림
  /// Returns: 웃음 점수 스트림
  Stream<SmileScoreModel> startRealTimeDetection(
    Stream<CameraImage> imageStream,
  ) {
    if (!_isInitialized) {
      throw Exception('얼굴 감지 서비스가 초기화되지 않았습니다.');
    }

    // 기존 구독 해제
    _scoreStreamSubscription?.cancel();

    // 새로운 스트림 구독
    _scoreStreamSubscription = imageStream
        .asyncMap((image) => detectFaceAndCalculateScore(image))
        .listen(
          (score) {
            if (!_scoreStreamController.isClosed) {
              _scoreStreamController.add(score);
            }
          },
          onError: (error) {
            if (!_scoreStreamController.isClosed) {
              _scoreStreamController.addError(error);
            }
          },
        );

    return _scoreStreamController.stream;
  }

  /// 실시간 스트림 처리 중지
  void stopRealTimeDetection() {
    _scoreStreamSubscription?.cancel();
    _scoreStreamSubscription = null;
  }

  /// 얼굴 감지 서비스 해제
  Future<void> dispose() async {
    try {
      // 스트림 처리 중지
      stopRealTimeDetection();

      // 스트림 컨트롤러 해제
      await _scoreStreamController.close();

      // 상태 초기화
      _isInitialized = false;
      _isProcessing = false;
    } catch (e) {
      throw Exception('얼굴 감지 서비스 해제 실패: $e');
    }
  }

  /// 서비스 상태 정보 반환
  Map<String, dynamic> get serviceStatus {
    return {
      'isInitialized': _isInitialized,
      'isProcessing': _isProcessing,
      'lastProcessingTime': _lastProcessingTime.toIso8601String(),
      'streamSubscriptionActive': _scoreStreamSubscription != null,
      'streamControllerClosed': _scoreStreamController.isClosed,
    };
  }

  /// 성능 통계 반환
  Map<String, dynamic> get performanceStats {
    return {
      'minProcessingInterval': _minProcessingInterval.inMilliseconds,
      'isProcessing': _isProcessing,
      'lastProcessingTime': _lastProcessingTime.toIso8601String(),
    };
  }
}
