import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
// import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
// import 'package:flutter_animate/flutter_animate.dart';

import 'utils/constants.dart';
import 'views/expression_select_screen.dart';

void main() async {
  // Flutter 바인딩 초기화
  WidgetsFlutterBinding.ensureInitialized();

  // 일부 환경에서 runApp 이전의 availableCameras 호출 시 MissingPluginException이 발생할 수 있어
  // 카메라 선택은 runApp 이후 위젯 트리에서 처리합니다.
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: '스마트 표정 훈련기',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Pretendard',
      ),
      home: FutureBuilder<CameraDescription>(
        future: _resolveSelectedCamera(),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: Text('카메라를 초기화할 수 없습니다.')),
            );
          }
          return ExpressionSelectScreen(camera: snapshot.data!);
        },
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}

Future<CameraDescription> _resolveSelectedCamera() async {
  // 권한 요청
  await Permission.camera.request();
  // 사용 가능한 카메라 목록
  final cameras = await availableCameras();
  // 전면 우선 선택
  for (final camera in cameras) {
    if (camera.lensDirection == CameraLensDirection.front) {
      return camera;
    }
  }
  return cameras.first;
}
