import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

import '../utils/constants.dart';
import 'login_screen.dart';
import 'home_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<CameraDescription> _resolveSelectedCamera() async {
    await Permission.camera.request();
    final cameras = await availableCameras();
    for (final camera in cameras) {
      if (camera.lensDirection == CameraLensDirection.front) {
        return camera;
      }
    }
    return cameras.first;
  }

  @override
  Widget build(BuildContext context) {
    return GetX<AuthStateController>(
      init: AuthStateController(),
      builder: (ctrl) {
        if (ctrl.status.value == AuthStatus.checking) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (ctrl.status.value == AuthStatus.signedIn) {
          return FutureBuilder<CameraDescription>(
            future: _resolveSelectedCamera(),
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Scaffold(
                  backgroundColor: AppColors.background,
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (!snapshot.hasData) {
                return const Scaffold(
                  backgroundColor: AppColors.background,
                  body: Center(child: Text('카메라를 초기화할 수 없습니다.')),
                );
              }
              return HomeScreen(camera: snapshot.data!);
            },
          );
        }
        return const LoginScreen();
      },
    );
  }
}

enum AuthStatus { checking, signedIn, signedOut }

class AuthStateController extends GetxController {
  final Rx<AuthStatus> status = AuthStatus.checking.obs;

  @override
  void onInit() {
    super.onInit();
    _check();
  }

  Future<void> _check() async {
    try {
      // FirebaseAuth.instance.currentUser는 앱 재시작/새로고침 후에도 유지됩니다.
      // 지연을 짧게 두어 초기화 타이밍을 보장합니다.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      final user = FirebaseAuth.instance.currentUser;
      status.value = (user != null)
          ? AuthStatus.signedIn
          : AuthStatus.signedOut;
    } catch (_) {
      status.value = AuthStatus.signedOut;
    }
  }
}

// 작은 어댑터로 FirebaseAuth 의존을 늦게 주입
// Adapter 제거: 직접 FirebaseAuth 사용
