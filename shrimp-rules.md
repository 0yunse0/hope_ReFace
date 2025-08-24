# 얼굴 표정 훈련 앱 개발 가이드라인

## 프로젝트 개요

### 기술 스택
- **프론트엔드**: Flutter 3.x
- **상태 관리**: GetX (Provider 사용 금지)
- **얼굴 감지**: Google MLKit Face Detection
- **카메라**: camera 패키지
- **권한 관리**: permission_handler
- **애니메이션**: flutter_animate (선택사항)

### 핵심 기능
- 실시간 얼굴 인식 및 웃음 점수화 (0-100%)
- 시각적 피드백 및 음성/텍스트 가이드
- 점수 기반 애니메이션 효과
- 학습 주제 안내 시스템

## 프로젝트 아키텍처

### 디렉토리 구조
```
lib/
├── controllers/          # GetX 컨트롤러
├── views/               # UI 화면
├── services/            # MLKit 및 카메라 서비스
├── models/              # 데이터 모델
├── utils/               # 유틸리티 함수
└── main.dart           # 앱 진입점
```

### 필수 패키지 의존성
```yaml
dependencies:
  flutter:
    sdk: flutter
  get: ^4.6.5
  google_mlkit_face_detection: ^0.9.0
  camera: ^0.10.5+5
  permission_handler: ^11.0.1
  flutter_animate: ^4.2.0+1
```

## 코드 표준

### 네이밍 컨벤션
- **파일명**: snake_case 사용
  - 컨트롤러: `*_controller.dart`
  - 서비스: `*_service.dart`
  - 모델: `*_model.dart`
  - 화면: `*_screen.dart`
- **클래스명**: PascalCase 사용
- **변수/함수명**: camelCase 사용
- **상수**: UPPER_SNAKE_CASE 사용

### 코드 포맷팅
- **들여쓰기**: 2칸 공백
- **최대 줄 길이**: 80자
- **주석**: 한국어 사용
- **import 순서**: Flutter → Dart → Third-party → Local

## 기능 구현 표준

### 상태 관리 (GetX)
```dart
// 컨트롤러 구조
class FaceTrainingController extends GetxController {
  final RxDouble smileScore = 0.0.obs;
  final RxBool isDetecting = false.obs;
  final RxString feedbackMessage = ''.obs;
  
  // 메서드 구현
  void updateSmileScore(double score) {
    smileScore.value = score;
    updateFeedbackMessage(score);
  }
}
```

### MLKit 통합 규칙
- **FaceDetectionService 클래스로 캡슐화**
- **실시간 스트림 처리 필수**
- **점수 계산 로직 분리**
- **메모리 누수 방지**

```dart
class FaceDetectionService {
  final FaceDetector _faceDetector;
  
  Stream<double> detectSmileScore(CameraImage image) {
    // 웃음 점수 계산 로직
  }
}
```

### 카메라 권한 처리
- **앱 시작 시 권한 요청**
- **권한 거부 시 안내 화면 표시**
- **권한 재요청 기능 제공**

```dart
Future<bool> requestCameraPermission() async {
  final status = await Permission.camera.request();
  return status.isGranted;
}
```

## UI/UX 구현 가이드라인

### 디자인 시스템
- **Material Design 3 준수**
- **반응형 레이아웃 (SafeArea 사용)**
- **다크모드 지원**
- **접근성 고려**

### 애니메이션 규칙
- **점수 상승 시 애니메이션 효과**
- **부드러운 전환 효과**
- **성능 최적화 고려**

```dart
// 점수 애니메이션 예시
AnimatedBuilder(
  animation: scoreAnimation,
  builder: (context, child) {
    return Text('${(scoreAnimation.value * 100).toInt()}%');
  },
)
```

## 성능 최적화

### 카메라 처리
- **프레임 처리 최적화**
- **해상도 조정 가능**
- **배터리 효율성 고려**

### 메모리 관리
- **컨트롤러 dispose 처리**
- **스트림 구독 해제**
- **이미지 캐시 관리**

## 에러 처리

### 필수 에러 케이스
- **카메라 접근 실패**
- **MLKit 초기화 실패**
- **권한 거부 처리**
- **네트워크 오류**

### 에러 처리 패턴
```dart
try {
  await initializeCamera();
} catch (e) {
  Get.snackbar('오류', '카메라를 초기화할 수 없습니다.');
}
```

## 테스트 규칙

### 테스트 구조
```
test/
├── unit/               # 단위 테스트
├── widget/             # 위젯 테스트
└── integration/        # 통합 테스트
```

### 테스트 요구사항
- **컨트롤러 단위 테스트 필수**
- **서비스 클래스 테스트 필수**
- **위젯 테스트 권장**
- **통합 테스트 고려**

## 파일 간 상호작용 표준

### 동시 수정 파일
- **pubspec.yaml 수정 시**: android/app/build.gradle.kts 확인
- **권한 설정 시**: android/app/src/main/AndroidManifest.xml 수정
- **iOS 설정 시**: ios/Runner/Info.plist 수정

### 의존성 관리
- **컨트롤러 간 의존성**: GetX 의존성 주입 사용
- **서비스 간 의존성**: 싱글톤 패턴 권장
- **모델 간 의존성**: 명확한 인터페이스 정의

## AI 의사결정 기준

### 우선순위 판단
1. **사용자 경험 최우선**
2. **성능 최적화**
3. **코드 가독성**
4. **유지보수성**

### 모호한 상황 처리
- **기능 추가 시**: 기존 아키텍처와 일관성 유지
- **성능 vs 가독성**: 성능 우선, 주석으로 설명
- **에러 처리**: 사용자 친화적 메시지 제공

## 금지 사항

### 절대 금지
- **Provider 패키지 사용**
- **하드코딩된 값 사용**
- **예외 처리 생략**
- **메모리 누수 방지 코드 생략**

### 권장하지 않음
- **복잡한 위젯 트리 구성**
- **동기 블로킹 작업**
- **과도한 애니메이션 효과**

## 개발 워크플로우

### 기능 개발 순서
1. **모델 정의**
2. **서비스 구현**
3. **컨트롤러 구현**
4. **UI 구현**
5. **테스트 작성**

### 코드 리뷰 체크리스트
- [ ] 네이밍 컨벤션 준수
- [ ] 에러 처리 구현
- [ ] 성능 최적화 적용
- [ ] 테스트 코드 작성
- [ ] 문서화 완료

## 배포 준비

### 빌드 설정
- **Android**: minSdkVersion 21 이상
- **iOS**: deploymentTarget 12.0 이상
- **권한 설정 완료**
- **프로비저닝 프로파일 설정**

### 테스트 체크리스트
- [ ] 카메라 권한 테스트
- [ ] 얼굴 인식 정확도 테스트
- [ ] 애니메이션 성능 테스트
- [ ] 메모리 누수 테스트
- [ ] 다양한 기기 호환성 테스트 