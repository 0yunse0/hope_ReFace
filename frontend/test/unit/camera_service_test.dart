import 'package:flutter_test/flutter_test.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:face_newversion/services/camera_service.dart';
import 'package:face_newversion/utils/permission_helper.dart';

void main() {
  group('CameraService Tests', () {
    late CameraService cameraService;

    setUp(() {
      cameraService = CameraService();
    });

    tearDown(() async {
      await cameraService.dispose();
    });

    test('CameraService should be singleton', () {
      final instance1 = CameraService();
      final instance2 = CameraService();
      expect(identical(instance1, instance2), isTrue);
    });

    test('CameraService should have correct initial state', () {
      expect(cameraService.isInitialized, isFalse);
      expect(cameraService.isStreaming, isFalse);
      expect(cameraService.cameras, isEmpty);
      expect(cameraService.selectedCameraIndex, equals(0));
    });

    test('CameraService should return correct camera status', () {
      final status = cameraService.cameraStatus;

      expect(status['isInitialized'], isFalse);
      expect(status['isStreaming'], isFalse);
      expect(status['cameraCount'], equals(0));
      expect(status['selectedCameraIndex'], equals(0));
      expect(status['currentCameraName'], equals('Unknown Camera'));
      expect(status['currentLensDirection'], equals('front'));
    });

    test('CameraService should handle permission check', () async {
      final permissionResult = await cameraService.checkPermission();

      expect(permissionResult, isA<Map<String, dynamic>>());
      expect(permissionResult.containsKey('isGranted'), isTrue);
      expect(permissionResult.containsKey('message'), isTrue);
      expect(permissionResult.containsKey('actionMessage'), isTrue);
    });

    test('CameraService should handle permission request', () async {
      final permissionResult = await cameraService.requestPermission();

      expect(permissionResult, isA<Map<String, dynamic>>());
      expect(permissionResult.containsKey('isGranted'), isTrue);
      expect(permissionResult.containsKey('message'), isTrue);
      expect(permissionResult.containsKey('actionMessage'), isTrue);
    });

    test(
      'CameraService should handle dispose without initialization',
      () async {
        // 초기화하지 않은 상태에서 dispose 호출 시 오류가 발생하지 않아야 함
        expect(() async => await cameraService.dispose(), returnsNormally);
      },
    );

    test(
      'CameraService should handle camera switching without cameras',
      () async {
        // 카메라가 없는 상태에서 전환 시도
        final result = await cameraService.switchCamera();
        expect(result, isFalse);
      },
    );

    test(
      'CameraService should handle resolution change without initialization',
      () async {
        // 초기화하지 않은 상태에서 해상도 변경 시도
        final result = await cameraService.changeResolution(
          ResolutionPreset.low,
        );
        expect(result, isFalse);
      },
    );

    test(
      'CameraService should handle stream start without initialization',
      () async {
        // 초기화하지 않은 상태에서 스트림 시작 시도
        expect(
          () async => await cameraService.startImageStream(),
          throwsA(isA<Exception>()),
        );
      },
    );

    test('CameraService should handle stream stop without streaming', () async {
      // 스트리밍하지 않은 상태에서 스트림 중지 시도
      expect(
        () async => await cameraService.stopImageStream(),
        returnsNormally,
      );
    });
  });

  group('PermissionHelper Tests', () {
    test('PermissionHelper should handle permission check', () async {
      final status = await PermissionHelper.checkCameraPermission();
      expect(status, isA<PermissionStatus>());
    });

    test('PermissionHelper should handle permission request', () async {
      final status = await PermissionHelper.requestCameraPermission();
      expect(status, isA<PermissionStatus>());
    });

    test('PermissionHelper should check if permission is granted', () async {
      final isGranted = await PermissionHelper.isCameraPermissionGranted();
      expect(isGranted, isA<bool>());
    });

    test(
      'PermissionHelper should check if permission is permanently denied',
      () async {
        final isPermanentlyDenied =
            await PermissionHelper.isCameraPermissionPermanentlyDenied();
        expect(isPermanentlyDenied, isA<bool>());
      },
    );

    test(
      'PermissionHelper should check if permission should be requested',
      () async {
        final shouldRequest = await PermissionHelper.shouldRequestPermission();
        expect(shouldRequest, isA<bool>());
      },
    );

    test('PermissionHelper should handle permission result', () {
      final result = PermissionHelper.handlePermissionResult(
        PermissionStatus.denied,
      );

      expect(result, isA<Map<String, dynamic>>());
      expect(result.containsKey('isGranted'), isTrue);
      expect(result.containsKey('message'), isTrue);
      expect(result.containsKey('actionMessage'), isTrue);
      expect(result.containsKey('shouldShowSettings'), isTrue);
      expect(result.containsKey('status'), isTrue);
    });

    test('PermissionHelper should convert permission status to string', () {
      final statusString = PermissionHelper.permissionStatusToString(
        PermissionStatus.granted,
      );
      expect(statusString, equals('granted'));
    });

    test('PermissionHelper should convert string to permission status', () {
      final status = PermissionHelper.stringToPermissionStatus('granted');
      expect(status, equals(PermissionStatus.granted));
    });

    test('PermissionHelper should get permission message', () {
      final message = PermissionHelper.getPermissionMessage(
        PermissionStatus.granted,
      );
      expect(message, isA<String>());
      expect(message.isNotEmpty, isTrue);
    });

    test('PermissionHelper should get permission action message', () {
      final actionMessage = PermissionHelper.getPermissionActionMessage(
        PermissionStatus.granted,
      );
      expect(actionMessage, isA<String>());
      expect(actionMessage.isNotEmpty, isTrue);
    });
  });
}
