import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF6366F1);
  static const Color secondary = Color(0xFF8B5CF6);
  static const Color accent = Color(0xFFF59E0B);
  static const Color success = Color(0xFF10B981);
  static const Color error = Color(0xFFEF4444);
  static const Color warning = Color(0xFFF97316);
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1F2937);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textTertiary = Color(0xFF9CA3AF);
  static const Color border = Color(0xFFE5E7EB);
}

class AppSizes {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;
  static const double xxxl = 64.0;
}

class AppRadius {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double full = 999.0;
}

class AppConstants {
  // 점수 임계값
  static const double highScoreThreshold = 0.8;
  static const double mediumScoreThreshold = 0.6;
  static const double lowScoreThreshold = 0.4;

  // 애니메이션 지속시간
  static const Duration scoreAnimationDuration = Duration(milliseconds: 500);

  // 에러 메시지
  static const Map<String, String> errorMessages = {
    'cameraNotInitialized': '카메라가 초기화되지 않았습니다.',
    'cameraInitFailed': '카메라 초기화에 실패했습니다.',
    'trainingStartFailed': '훈련 시작에 실패했습니다.',
    'trainingStopFailed': '훈련 중지에 실패했습니다.',
    'cannotChangeTopicDuringTraining': '훈련 중에는 주제를 변경할 수 없습니다.',
    'faceDetectionFailed': '얼굴 감지에 실패했습니다.',
    'cannotSwitchCameraDuringTraining': '훈련 중에는 카메라를 전환할 수 없습니다.',
    'cameraSwitchFailed': '카메라 전환에 실패했습니다.',
    'cameraPermission': '카메라 권한이 필요합니다.',
    'unknown': '알 수 없는 오류가 발생했습니다.',
  };

  // 피드백 메시지
  static const Map<String, String> feedbackMessages = {
    'trainingStarted': '훈련이 시작되었습니다.',
    'trainingPaused': '훈련이 일시정지되었습니다.',
    'trainingResumed': '훈련이 재개되었습니다.',
    'trainingCompleted': '훈련이 완료되었습니다.',
    'faceNotDetected': '얼굴이 감지되지 않았습니다.',
    'cameraSwitched': '카메라가 전환되었습니다.',
    'high': '훌륭한 미소입니다!',
    'medium': '좋은 미소입니다. 더 밝게 웃어보세요!',
    'low': '미소를 더 밝게 표현해보세요.',
    'error': '점수를 계산할 수 없습니다.',
  };
}

class AppStrings {
  static const String appTitle = '스마트 표정 훈련기';
  static const String startTraining = '훈련 시작';
  static const String stopTraining = '훈련 중지';
  static const String smileScore = '미소 점수';
  static const String noFaceDetected = '얼굴이 감지되지 않았어요';
  static const String faceDetected = '얼굴 감지됨';
}

class AppAnimations {
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
}

class TrainingTopics {
  static const String smileTraining = '웃는 표정 학습';
  static const String expressionTraining = '표정 표현 학습';
  static const String confidenceTraining = '자신감 표현 학습';
  static const String communicationTraining = '소통 표정 학습';

  static const List<String> allTopics = [
    smileTraining,
    expressionTraining,
    confidenceTraining,
    communicationTraining,
  ];
}
