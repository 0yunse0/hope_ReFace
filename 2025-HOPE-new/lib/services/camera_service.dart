import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

import '../utils/constants.dart';
import '../utils/permission_helper.dart';

/// 카메라 서비스 클래스
/// 카메라 초기화, 프레임 스트림 처리, 권한 관리를 담당하는 싱글톤 서비스
class CameraService {
  static final CameraService _instance = CameraService._internal();
  factory CameraService() => _instance;
  CameraService._internal();

  // 카메라 관련 변수들
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  int _selectedCameraIndex = 0;
  bool _isInitialized = false;
  bool _isStreaming = false;

  // 스트림 관련 변수들
  StreamSubscription<CameraImage>? _imageStreamSubscription;
  final StreamController<CameraImage> _imageStreamController =
      StreamController<CameraImage>.broadcast();

  // Getters
  CameraController? get cameraController => _cameraController;
  List<CameraDescription> get cameras => _cameras;
  int get selectedCameraIndex => _selectedCameraIndex;
  bool get isInitialized => _isInitialized;
  bool get isStreaming => _isStreaming;
  Stream<CameraImage> get imageStream => _imageStreamController.stream;

  /// 카메라 서비스 초기화
  ///
  /// Returns: 초기화 성공 여부
  Future<bool> initialize() async {
    try {
      // 권한 확인
      final hasPermission = await PermissionHelper.isCameraPermissionGranted();
      if (!hasPermission) {
        final permissionResult =
            await PermissionHelper.requestAndHandlePermission();
        if (!permissionResult['isGranted']) {
          throw Exception('카메라 권한이 필요합니다.');
        }
      }

      // 사용 가능한 카메라 목록 가져오기
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        throw Exception('사용 가능한 카메라가 없습니다.');
      }

      // 전면 카메라 우선 선택
      _selectedCameraIndex = _cameras.indexWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
      );
      if (_selectedCameraIndex == -1) {
        _selectedCameraIndex = 0; // 전면 카메라가 없으면 첫 번째 카메라 사용
      }

      // 카메라 컨트롤러 초기화
      await _initializeCameraController();

      _isInitialized = true;
      return true;
    } catch (e) {
      _isInitialized = false;
      throw Exception('카메라 초기화 실패: $e');
    }
  }

  /// 카메라 컨트롤러 초기화
  Future<void> _initializeCameraController() async {
    // 기존 컨트롤러 해제
    await _disposeCameraController();

    // 새 컨트롤러 생성
    _cameraController = CameraController(
      _cameras[_selectedCameraIndex],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid
          ? ImageFormatGroup.yuv420
          : ImageFormatGroup.bgra8888,
    );

    // 카메라 초기화
    await _cameraController!.initialize();
  }

  /// 카메라 스트림 시작
  ///
  /// Returns: 스트림 시작 성공 여부
  Future<bool> startImageStream() async {
    if (!_isInitialized || _cameraController == null) {
      throw Exception('카메라가 초기화되지 않았습니다.');
    }

    if (_isStreaming) {
      return true; // 이미 스트리밍 중이면 true 반환
    }

    try {
      await _cameraController!.startImageStream(_onImageStream);
      _isStreaming = true;
      return true;
    } catch (e) {
      _isStreaming = false;
      throw Exception('카메라 스트림 시작 실패: $e');
    }
  }

  /// 카메라 스트림 중지
  Future<void> stopImageStream() async {
    if (!_isStreaming || _cameraController == null) {
      return;
    }

    try {
      await _cameraController!.stopImageStream();
      _isStreaming = false;
    } catch (e) {
      throw Exception('카메라 스트림 중지 실패: $e');
    }
  }

  /// 이미지 스트림 콜백
  void _onImageStream(CameraImage image) {
    if (_imageStreamController.isClosed) return;
    _imageStreamController.add(image);
  }

  /// 카메라 전환 (전면/후면)
  ///
  /// Returns: 전환 성공 여부
  Future<bool> switchCamera() async {
    if (_cameras.length < 2) {
      return false; // 카메라가 1개뿐이면 전환 불가
    }

    try {
      // 다음 카메라 인덱스 계산
      _selectedCameraIndex = (_selectedCameraIndex + 1) % _cameras.length;

      // 스트리밍 중이면 중지
      final wasStreaming = _isStreaming;
      if (wasStreaming) {
        await stopImageStream();
      }

      // 새 카메라로 컨트롤러 재초기화
      await _initializeCameraController();

      // 스트리밍 중이었으면 다시 시작
      if (wasStreaming) {
        await startImageStream();
      }

      return true;
    } catch (e) {
      throw Exception('카메라 전환 실패: $e');
    }
  }

  /// 카메라 설정 변경
  ///
  /// [resolution] 해상도 설정
  /// Returns: 설정 변경 성공 여부
  Future<bool> changeResolution(ResolutionPreset resolution) async {
    if (!_isInitialized || _cameraController == null) {
      return false;
    }

    try {
      // 스트리밍 중이면 중지
      final wasStreaming = _isStreaming;
      if (wasStreaming) {
        await stopImageStream();
      }

      // 새 해상도로 컨트롤러 재초기화
      _cameraController = CameraController(
        _cameras[_selectedCameraIndex],
        resolution,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.yuv420
            : ImageFormatGroup.bgra8888,
      );

      await _cameraController!.initialize();

      // 스트리밍 중이었으면 다시 시작
      if (wasStreaming) {
        await startImageStream();
      }

      return true;
    } catch (e) {
      throw Exception('해상도 변경 실패: $e');
    }
  }

  /// 카메라 권한 재요청
  ///
  /// Returns: 권한 요청 결과
  Future<Map<String, dynamic>> requestPermission() async {
    return await PermissionHelper.requestAndHandlePermission();
  }

  /// 카메라 권한 상태 확인
  ///
  /// Returns: 권한 상태 확인 결과
  Future<Map<String, dynamic>> checkPermission() async {
    return await PermissionHelper.checkAndHandlePermission();
  }

  /// 카메라 컨트롤러 해제
  Future<void> _disposeCameraController() async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
      _cameraController = null;
    }
  }

  /// 스트림 구독 해제
  void _disposeStreamSubscription() {
    _imageStreamSubscription?.cancel();
    _imageStreamSubscription = null;
  }

  /// 카메라 서비스 해제
  Future<void> dispose() async {
    try {
      // 스트림 중지
      await stopImageStream();

      // 스트림 구독 해제
      _disposeStreamSubscription();

      // 스트림 컨트롤러 해제
      await _imageStreamController.close();

      // 카메라 컨트롤러 해제
      await _disposeCameraController();

      // 상태 초기화
      _isInitialized = false;
      _isStreaming = false;
      _cameras.clear();
      _selectedCameraIndex = 0;
    } catch (e) {
      throw Exception('카메라 서비스 해제 실패: $e');
    }
  }

  /// 현재 카메라 정보 반환
  CameraDescription? get currentCamera {
    if (_cameras.isEmpty || _selectedCameraIndex >= _cameras.length) {
      return null;
    }
    return _cameras[_selectedCameraIndex];
  }

  /// 카메라 방향 반환
  CameraLensDirection get currentLensDirection {
    return currentCamera?.lensDirection ?? CameraLensDirection.front;
  }

  /// 카메라 이름 반환
  String get currentCameraName {
    return currentCamera?.name ?? 'Unknown Camera';
  }

  /// 카메라 상태 정보 반환
  Map<String, dynamic> get cameraStatus {
    return {
      'isInitialized': _isInitialized,
      'isStreaming': _isStreaming,
      'cameraCount': _cameras.length,
      'selectedCameraIndex': _selectedCameraIndex,
      'currentCameraName': currentCameraName,
      'currentLensDirection': currentLensDirection.name,
      'hasPermission': PermissionHelper.isCameraPermissionGranted(),
    };
  }
}
