import 'package:permission_handler/permission_handler.dart';
import 'constants.dart';

/// 권한 관련 헬퍼 함수 클래스
/// 카메라 권한 요청 및 확인을 위한 유틸리티 함수들
class PermissionHelper {
  /// 기본 생성자 (사용하지 않음)
  PermissionHelper._();

  /// 카메라 권한 요청
  ///
  /// Returns: 권한 상태
  static Future<PermissionStatus> requestCameraPermission() async {
    try {
      final status = await Permission.camera.request();
      return status;
    } catch (e) {
      // 권한 요청 중 오류 발생 시 denied로 처리
      return PermissionStatus.denied;
    }
  }

  /// 카메라 권한 상태 확인
  ///
  /// Returns: 권한 상태
  static Future<PermissionStatus> checkCameraPermission() async {
    try {
      final status = await Permission.camera.status;
      return status;
    } catch (e) {
      // 권한 확인 중 오류 발생 시 denied로 처리
      return PermissionStatus.denied;
    }
  }

  /// 카메라 권한이 허용되었는지 확인
  ///
  /// Returns: 권한 허용 여부
  static Future<bool> isCameraPermissionGranted() async {
    final status = await checkCameraPermission();
    return status.isGranted;
  }

  /// 카메라 권한이 영구적으로 거부되었는지 확인
  ///
  /// Returns: 영구 거부 여부
  static Future<bool> isCameraPermissionPermanentlyDenied() async {
    final status = await checkCameraPermission();
    return status.isPermanentlyDenied;
  }

  /// 권한 상태에 따른 메시지 반환
  ///
  /// [status] 권한 상태
  /// Returns: 사용자에게 표시할 메시지
  static String getPermissionMessage(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return '카메라 권한이 허용되었습니다.';
      case PermissionStatus.denied:
        return AppConstants.errorMessages['cameraPermission']!;
      case PermissionStatus.permanentlyDenied:
        return '카메라 권한이 영구적으로 거부되었습니다. 설정에서 권한을 허용해주세요.';
      case PermissionStatus.restricted:
        return '카메라 권한이 제한되었습니다.';
      case PermissionStatus.limited:
        return '카메라 권한이 제한적으로 허용되었습니다.';
      case PermissionStatus.provisional:
        return '카메라 권한이 임시로 허용되었습니다.';
      default:
        return AppConstants.errorMessages['unknown']!;
    }
  }

  /// 권한 상태에 따른 액션 메시지 반환
  ///
  /// [status] 권한 상태
  /// Returns: 사용자가 수행할 액션 메시지
  static String getPermissionActionMessage(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return '카메라를 사용할 수 있습니다.';
      case PermissionStatus.denied:
        return '권한 요청을 다시 시도해주세요.';
      case PermissionStatus.permanentlyDenied:
        return '설정 > 앱 > 스마트 표정 훈련기 > 권한에서 카메라를 허용해주세요.';
      case PermissionStatus.restricted:
        return '부모님의 도움을 받아 권한을 설정해주세요.';
      case PermissionStatus.limited:
        return '제한된 카메라 권한으로 일부 기능이 제한될 수 있습니다.';
      case PermissionStatus.provisional:
        return '임시 권한으로 일부 기능이 제한될 수 있습니다.';
      default:
        return '앱을 다시 시작해주세요.';
    }
  }

  /// 권한 요청이 필요한지 확인
  ///
  /// Returns: 권한 요청 필요 여부
  static Future<bool> shouldRequestPermission() async {
    final status = await checkCameraPermission();
    return status == PermissionStatus.denied;
  }

  /// 앱 설정으로 이동
  ///
  /// Returns: 설정 열기 성공 여부
  static Future<bool> openAppSettings() async {
    try {
      final opened = await openAppSettings();
      return opened;
    } catch (e) {
      return false;
    }
  }

  /// 권한 상태를 문자열로 변환
  ///
  /// [status] 권한 상태
  /// Returns: 상태 문자열
  static String permissionStatusToString(PermissionStatus status) {
    switch (status) {
      case PermissionStatus.granted:
        return 'granted';
      case PermissionStatus.denied:
        return 'denied';
      case PermissionStatus.permanentlyDenied:
        return 'permanently_denied';
      case PermissionStatus.restricted:
        return 'restricted';
      case PermissionStatus.limited:
        return 'limited';
      case PermissionStatus.provisional:
        return 'provisional';
      default:
        return 'unknown';
    }
  }

  /// 문자열을 권한 상태로 변환
  ///
  /// [statusString] 상태 문자열
  /// Returns: 권한 상태
  static PermissionStatus stringToPermissionStatus(String statusString) {
    switch (statusString) {
      case 'granted':
        return PermissionStatus.granted;
      case 'denied':
        return PermissionStatus.denied;
      case 'permanently_denied':
        return PermissionStatus.permanentlyDenied;
      case 'restricted':
        return PermissionStatus.restricted;
      case 'limited':
        return PermissionStatus.limited;
      case 'provisional':
        return PermissionStatus.provisional;
      default:
        return PermissionStatus.denied;
    }
  }

  /// 권한 요청 결과 처리
  ///
  /// [status] 권한 상태
  /// Returns: 처리 결과 맵
  static Map<String, dynamic> handlePermissionResult(PermissionStatus status) {
    final isGranted = status.isGranted;
    final message = getPermissionMessage(status);
    final actionMessage = getPermissionActionMessage(status);
    final shouldShowSettings = status.isPermanentlyDenied;

    return {
      'isGranted': isGranted,
      'message': message,
      'actionMessage': actionMessage,
      'shouldShowSettings': shouldShowSettings,
      'status': permissionStatusToString(status),
    };
  }

  /// 권한 요청 및 결과 처리
  ///
  /// Returns: 처리 결과 맵
  static Future<Map<String, dynamic>> requestAndHandlePermission() async {
    final status = await requestCameraPermission();
    return handlePermissionResult(status);
  }

  /// 권한 상태 확인 및 결과 처리
  ///
  /// Returns: 처리 결과 맵
  static Future<Map<String, dynamic>> checkAndHandlePermission() async {
    final status = await checkCameraPermission();
    return handlePermissionResult(status);
  }
}
