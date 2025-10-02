import 'package:face_newversion/models/expression_type.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
// import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
// import 'package:flutter_animate/flutter_animate.dart';

import 'utils/constants.dart';
import 'views/home_screen.dart';
import 'views/login_screen.dart';
import 'views/auth_gate.dart';
import 'views/signup_screen.dart';
import 'views/initial_expression_screen.dart';
import 'views/initial_expression_result_screen.dart';
import 'firebase_options.dart';

void main() async {
  // Flutter 바인딩 초기화
  WidgetsFlutterBinding.ensureInitialized();

  // 한국어 로케일 초기화 (주간 달력의 DateFormat 사용을 위해 필요)
  Intl.defaultLocale = 'ko_KR';
  await initializeDateFormatting('ko_KR');

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
      initialRoute: '/auth',
      getPages: [
        GetPage(name: '/auth', page: () => const AuthGate()),
        GetPage(name: '/login', page: () => const LoginScreen()),
        GetPage(
          name: '/initial-expression',
          page: () => const InitialExpressionScreen(),
        ),
        GetPage(
          name: '/initial-expression/result',
          page: () => InitialExpressionResultScreen(
            expressionScores: <ExpressionType, double>{
              for (final expression in ExpressionType.values) expression: 0.0,
            },
          ),
        ),
        GetPage(
          name: '/home',
          page: () => FutureBuilder<CameraDescription>(
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
              return HomeScreen(camera: snapshot.data!);
            },
          ),
        ),
        GetPage(name: '/signup', page: () => const SignupScreen()),
      ],
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
